export class HttpError extends Error {
  constructor(
    message: string,
    public readonly status = 400,
    public readonly details?: unknown,
  ) {
    super(message);
    this.name = "HttpError";
  }
}

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function asRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpError("JSON object body required", 400);
  }

  return value as Record<string, unknown>;
}

export async function readJsonObject(request: Request) {
  try {
    return asRecord(await request.json());
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }

    throw new HttpError("Invalid JSON body", 400);
  }
}

export function stringField(
  body: Record<string, unknown>,
  field: string,
  options: {
    required?: boolean;
    maxLength?: number;
    pattern?: RegExp;
    allowed?: readonly string[];
  } = {},
): string | null {
  const value = body[field];
  const required = options.required ?? true;

  if (typeof value !== "string") {
    if (!required && (value === undefined || value === null)) {
      return null;
    }
    throw new HttpError(`${field} must be a string`, 400);
  }

  const trimmed = value.trim();
  if (trimmed.length === 0) {
    if (!required) {
      return null;
    }
    throw new HttpError(`${field} is required`, 400);
  }

  if (options.maxLength != null && trimmed.length > options.maxLength) {
    throw new HttpError(`${field} is too long`, 400);
  }

  if (options.pattern && !options.pattern.test(trimmed)) {
    throw new HttpError(`${field} is invalid`, 400);
  }

  if (options.allowed && !options.allowed.includes(trimmed)) {
    throw new HttpError(`${field} is not supported`, 400);
  }

  return trimmed;
}

export function uuidField(
  body: Record<string, unknown>,
  field: string,
  options: { required?: boolean } = {},
): string | null {
  return stringField(body, field, {
    required: options.required ?? true,
    pattern: uuidPattern,
  });
}

export function amountField(
  body: Record<string, unknown>,
  field = "amount",
): number {
  const value = body[field];
  const amount = typeof value === "number"
    ? value
    : typeof value === "string"
    ? Number(value)
    : Number.NaN;

  if (!Number.isFinite(amount) || amount <= 0 || amount > 100_000_000) {
    throw new HttpError(`${field} must be a positive amount`, 400);
  }

  return Math.round(amount * 100) / 100;
}

export function currencyField(
  body: Record<string, unknown>,
  field = "currency",
): string {
  const currency = stringField(body, field, {
    required: true,
    pattern: /^[A-Z]{3}$/,
  });

  return currency!;
}

export function requireAuthorization(request: Request): string {
  const authorization = request.headers.get("Authorization") ??
    request.headers.get("authorization");

  if (!authorization?.trim()) {
    throw new HttpError("Missing Authorization header", 401);
  }

  return authorization.trim();
}
