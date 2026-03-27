function toHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
}

export async function hashOtpCode(code: string): Promise<string> {
  const normalized = code.replace(/\D/g, "");
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(normalized),
  );

  return toHex(new Uint8Array(digest));
}
