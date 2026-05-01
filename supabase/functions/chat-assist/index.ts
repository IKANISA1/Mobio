import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";
import { createUserClient } from "../_shared/supabase.ts";

const defaultModel = Deno.env.get("GEMINI_CHAT_MODEL")?.trim() ||
  "gemini-2.5-flash";
const geminiApiKey = Deno.env.get("GEMINI_API_KEY")?.trim() ||
  Deno.env.get("GOOGLE_API_KEY")?.trim();

const systemInstruction = `
You are MOBI Chat Input Assist for ride-sharing conversations inside MOBI.

Priorities:
- Only help with the chat composer.
- Help users coordinate pickup, dropoff, timing, luggage, seats, and price.
- Protect privacy. Never suggest moving to WhatsApp, phone calls, or sharing personal contact details.
- If task is "reply_suggestions", return up to 3 short, natural, ready-to-send messages.
- If task is "autocomplete", return one completed draft in the same language and tone as draft_text.
- For autocomplete, preserve the user's intent, continue from their draft, and do not change the topic.
- If facts are missing, keep the suggestion general instead of inventing details.

Return valid JSON only with this shape:
{
  "suggestions": ["string", "string", "string"],
  "completion": "string"
}

For "reply_suggestions", set "completion" to an empty string.
For "autocomplete", set "suggestions" to an empty array unless a short alternative is clearly useful.
`.trim();

type AssistInput = {
  task: string;
  conversation: Record<string, unknown>;
  trip?: Record<string, unknown> | null;
  peer?: Record<string, unknown> | null;
  messages: Array<Record<string, unknown>>;
  draft_text?: string | null;
  locale?: string | null;
};

type UserClient = ReturnType<typeof createUserClient>;

type ConversationRow = {
  id: string;
  trip_id: string | null;
  participant_low_id: string;
  participant_high_id: string;
  context_type: string | null;
  status: string | null;
};

type MessageRow = {
  sender_id: string | null;
  message_type: string | null;
  body: string | null;
  created_at: string | null;
};

class HttpError extends Error {
  constructor(message: string, public readonly status = 400) {
    super(message);
    this.name = "HttpError";
  }
}

function stringValue(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : null;
}

function boundedString(value: unknown, maxLength: number): string | null {
  const normalized = stringValue(value);
  return normalized == null ? null : normalized.slice(0, maxLength);
}

function objectValue(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function requireUuid(value: unknown, fieldName: string): string {
  const candidate = stringValue(value);
  if (
    !candidate ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(candidate)
  ) {
    throw new HttpError(`${fieldName} is required`, 400);
  }
  return candidate;
}

function normalizeMessages(
  rows: MessageRow[],
  currentUserId: string,
): Array<Record<string, unknown>> {
  return rows
    .map((item) => ({
      role: item.message_type === "system"
        ? "system"
        : item.sender_id === currentUserId
        ? "me"
        : "peer",
      text: boundedString(item.body, 500) || "",
      created_at: boundedString(item.created_at, 40),
    }))
    .filter((item) => (item.text as string).length > 0)
    .slice(-12);
}

function buildFallbackAssist(input: AssistInput) {
  const tripOrigin = stringValue(input.trip?.origin);
  const tripDestination = stringValue(input.trip?.destination);
  const departureTime = stringValue(input.trip?.departure_time) ||
    stringValue(input.trip?.time);
  const peerName = stringValue(input.peer?.display_name) ||
    stringValue(input.peer?.name) ||
    "the other user";

  const suggestions = [
    tripOrigin != null
      ? `Hi ${peerName}, are you still available from ${tripOrigin}?`
      : `Hi ${peerName}, are you still available?`,
    departureTime != null
      ? `Can we confirm the pickup time around ${departureTime}?`
      : "Can we confirm the pickup time in MOBI?",
    tripDestination != null
      ? `What price works for this trip to ${tripDestination}?`
      : "What price works for this trip?",
  ];

  if (input.task === "autocomplete") {
    return {
      source: "fallback",
      model: "local-fallback",
      suggestions: [],
      completion: buildFallbackCompletion({
        draftText: input.draft_text,
        tripOrigin,
        tripDestination,
        departureTime,
      }),
    };
  }

  return {
    source: "fallback",
    model: "local-fallback",
    suggestions,
    completion: "",
  };
}

function sanitizeArray(value: unknown, limit = 3): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => stringValue(item))
    .filter((item): item is string => item !== null)
    .slice(0, limit);
}

function buildFallbackCompletion(
  { draftText, tripOrigin, tripDestination, departureTime }: {
    draftText?: string | null;
    tripOrigin?: string | null;
    tripDestination?: string | null;
    departureTime?: string | null;
  },
): string {
  const normalizedDraft = stringValue(draftText)?.replace(/\s+/g, " ") || "";
  if (!normalizedDraft) {
    return "";
  }

  const capitalized = normalizedDraft.charAt(0).toUpperCase() +
    normalizedDraft.slice(1);
  if (/[.!?]$/.test(capitalized)) {
    return capitalized;
  }

  const lowerDraft = capitalized.toLowerCase();
  if (lowerDraft.includes("price") && tripDestination) {
    return `${capitalized} for the trip to ${tripDestination}?`;
  }
  if (lowerDraft.includes("pickup") && tripOrigin) {
    return `${capitalized} at ${tripOrigin}?`;
  }
  if (lowerDraft.includes("time") && departureTime) {
    return `${capitalized} around ${departureTime}?`;
  }
  if (looksLikeQuestion(lowerDraft)) {
    return `${capitalized}?`;
  }

  return `${capitalized}.`;
}

function looksLikeQuestion(value: string): boolean {
  const questionStarters = [
    "can ",
    "could ",
    "would ",
    "will ",
    "what ",
    "when ",
    "where ",
    "why ",
    "how ",
    "is ",
    "are ",
    "do ",
    "does ",
    "did ",
  ];

  return questionStarters.some((starter) => value.startsWith(starter)) ||
    value.includes(" price") ||
    value.includes("pickup") ||
    value.includes("dropoff") ||
    value.includes("time");
}

function stripMarkdownFence(value: string) {
  return value
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/\s*```$/, "")
    .trim();
}

function extractResponseText(payload: Record<string, unknown>): string {
  const candidates = Array.isArray(payload.candidates)
    ? payload.candidates
    : [];
  const firstCandidate = candidates[0];
  if (!firstCandidate || typeof firstCandidate !== "object") {
    return "";
  }

  const content = (firstCandidate as Record<string, unknown>).content;
  if (!content || typeof content !== "object") {
    return "";
  }

  const parts = Array.isArray((content as Record<string, unknown>).parts)
    ? (content as Record<string, unknown>).parts as Array<unknown>
    : [];

  return parts
    .map((part) => {
      if (!part || typeof part !== "object") {
        return "";
      }
      return stringValue((part as Record<string, unknown>).text) || "";
    })
    .join("")
    .trim();
}

async function loadVerifiedAssistContext(
  userClient: UserClient,
  body: Record<string, unknown>,
  userId: string,
): Promise<Pick<AssistInput, "conversation" | "trip" | "peer" | "messages">> {
  const conversationBody = objectValue(body.conversation);
  const conversationId = requireUuid(conversationBody.id, "conversation.id");

  const { data: conversation, error: conversationError } = await userClient
    .from("chat_conversations")
    .select(
      "id,trip_id,participant_low_id,participant_high_id,context_type,status",
    )
    .eq("id", conversationId)
    .maybeSingle<ConversationRow>();

  if (conversationError) {
    throw conversationError;
  }
  if (
    !conversation ||
    (conversation.participant_low_id !== userId &&
      conversation.participant_high_id !== userId)
  ) {
    throw new HttpError("Conversation not found", 404);
  }

  const peerId = conversation.participant_low_id === userId
    ? conversation.participant_high_id
    : conversation.participant_low_id;

  const { data: messageRows, error: messagesError } = await userClient
    .from("chat_messages")
    .select("sender_id,message_type,body,created_at")
    .eq("conversation_id", conversation.id)
    .order("created_at", { ascending: false })
    .limit(12)
    .returns<MessageRow[]>();

  if (messagesError) {
    throw messagesError;
  }

  const messages = normalizeMessages(
    [...((messageRows as MessageRow[] | null) ?? [])].reverse(),
    userId,
  );

  let trip: Record<string, unknown> | null = null;
  if (conversation.trip_id) {
    const { data: tripRow, error: tripError } = await userClient
      .from("trips")
      .select("id,origin,destination,departure_date,departure_time,time,role")
      .eq("id", conversation.trip_id)
      .maybeSingle<Record<string, unknown>>();

    if (!tripError && tripRow) {
      trip = {
        id: boundedString(tripRow.id, 80),
        origin: boundedString(tripRow.origin, 160),
        destination: boundedString(tripRow.destination, 160),
        departure_date: boundedString(tripRow.departure_date, 40),
        departure_time: boundedString(tripRow.departure_time, 40),
        time: boundedString(tripRow.time, 40),
        role: boundedString(tripRow.role, 40),
      };
    }
  }

  let peer: Record<string, unknown> | null = null;
  const { data: peerRows, error: peerError } = await userClient.rpc(
    "rpc_get_public_profile",
    { p_profile_id: peerId },
  );
  if (!peerError && Array.isArray(peerRows) && peerRows.length > 0) {
    const row = objectValue(peerRows[0]);
    peer = {
      id: boundedString(row.id, 80),
      name: boundedString(row.name, 80),
      display_name: boundedString(row.display_name, 80),
      member_id: boundedString(row.member_id, 40),
    };
  }

  return {
    conversation: {
      id: conversation.id,
      trip_id: conversation.trip_id,
      participant_low_id: conversation.participant_low_id,
      participant_high_id: conversation.participant_high_id,
      context_type: conversation.context_type,
      status: conversation.status,
    },
    trip,
    peer,
    messages,
  };
}

async function callGeminiAssist(input: AssistInput) {
  if (!geminiApiKey) {
    return buildFallbackAssist(input);
  }

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${defaultModel}:generateContent`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": geminiApiKey,
      },
      body: JSON.stringify({
        systemInstruction: {
          parts: [{ text: systemInstruction }],
        },
        contents: [{
          role: "user",
          parts: [{
            text: JSON.stringify(input),
          }],
        }],
        generationConfig: {
          temperature: 0.5,
          responseMimeType: "application/json",
        },
      }),
    },
  );

  if (!response.ok) {
    await response.body?.cancel();
    console.error("[chat-assist] Gemini error", response.status);
    return buildFallbackAssist(input);
  }

  const data = await response.json() as Record<string, unknown>;
  const text = stripMarkdownFence(extractResponseText(data));

  if (!text) {
    return buildFallbackAssist(input);
  }

  try {
    const parsed = JSON.parse(text) as Record<string, unknown>;
    return {
      source: "gemini",
      model: defaultModel,
      suggestions: sanitizeArray(parsed.suggestions, 3),
      completion: stringValue(parsed.completion) || "",
    };
  } catch (error) {
    console.error("[chat-assist] Failed to parse Gemini JSON", error);
    return buildFallbackAssist(input);
  }
}

Deno.serve(async (request: Request) => {
  const corsResponse = handleCors(request);
  if (corsResponse) {
    return corsResponse;
  }

  if (request.method !== "POST") {
    return methodNotAllowed("POST", request);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization) {
    return errorResponse(
      "Missing Authorization header",
      401,
      undefined,
      request,
    );
  }

  const userClient = createUserClient(authorization);
  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData.user) {
    return errorResponse("Unauthorized", 401, undefined, request);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json() as Record<string, unknown>;
  } catch (_) {
    return errorResponse("Invalid JSON body", 400, undefined, request);
  }

  try {
    const verifiedContext = await loadVerifiedAssistContext(
      userClient,
      body,
      authData.user.id,
    );

    const input: AssistInput = {
      task: stringValue(body.task) === "autocomplete"
        ? "autocomplete"
        : "reply_suggestions",
      ...verifiedContext,
      draft_text: boundedString(body.draft_text, 280),
      locale: boundedString(body.locale, 20),
    };

    const assist = await callGeminiAssist(input);

    return jsonResponse(
      {
        success: true,
        assist,
      },
      200,
      request,
    );
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(error.message, error.status, undefined, request);
    }

    console.error("[chat-assist] context validation failed", error);
    return errorResponse(
      "Unable to prepare chat assist",
      500,
      undefined,
      request,
    );
  }
});
