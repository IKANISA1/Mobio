import { errorResponse, handleCors, jsonResponse, methodNotAllowed } from "../_shared/http.ts";
import { createUserClient } from "../_shared/supabase.ts";

const defaultModel = Deno.env.get("GEMINI_CHAT_MODEL")?.trim() || "gemini-2.5-flash";
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

function stringValue(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}

function normalizeMessages(raw: unknown): Array<Record<string, unknown>> {
  if (!Array.isArray(raw)) {
    return [];
  }

  return raw
    .map((item) => item && typeof item === "object" ? item as Record<string, unknown> : null)
    .filter((item): item is Record<string, unknown> => item !== null)
    .map((item) => ({
      role: stringValue(item.role) || "participant",
      text: stringValue(item.text) || "",
      created_at: stringValue(item.created_at) || null,
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

  const capitalized = normalizedDraft.charAt(0).toUpperCase() + normalizedDraft.slice(1);
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
  const candidates = Array.isArray(payload.candidates) ? payload.candidates : [];
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
    const details = await response.text();
    console.error("[chat-assist] Gemini error", response.status, details);
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
    console.error("[chat-assist] Failed to parse Gemini JSON", error, text);
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
    return errorResponse("Missing Authorization header", 401, undefined, request);
  }

  const userClient = createUserClient(authorization);
  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData.user) {
    return errorResponse("Unauthorized", 401, authError?.message, request);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json() as Record<string, unknown>;
  } catch (_) {
    return errorResponse("Invalid JSON body", 400, undefined, request);
  }

  const input: AssistInput = {
    task: stringValue(body.task) || "reply_suggestions",
    conversation: body.conversation && typeof body.conversation === "object"
      ? body.conversation as Record<string, unknown>
      : {},
    trip: body.trip && typeof body.trip === "object"
      ? body.trip as Record<string, unknown>
      : null,
    peer: body.peer && typeof body.peer === "object"
      ? body.peer as Record<string, unknown>
      : null,
    messages: normalizeMessages(body.messages),
    draft_text: stringValue(body.draft_text),
    locale: stringValue(body.locale),
  };

  const assist = await callGeminiAssist(input);

  return jsonResponse({
    success: true,
    assist,
  }, 200, request);
});
