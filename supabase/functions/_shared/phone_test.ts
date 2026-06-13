import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { normalizePhoneWithCountry } from "./phone.ts";

Deno.test("normalizePhoneWithCountry removes local trunk zero", () => {
  assertEquals(
    normalizePhoneWithCountry("0788123456", "+250"),
    "+250788123456",
  );
});

Deno.test("normalizePhoneWithCountry keeps canonical E.164 values", () => {
  assertEquals(
    normalizePhoneWithCountry("+250788123456", "+250"),
    "+250788123456",
  );
});

Deno.test("normalizePhoneWithCountry handles pasted country code without plus", () => {
  assertEquals(
    normalizePhoneWithCountry("250788123456", "+250"),
    "+250788123456",
  );
});

Deno.test("normalizePhoneWithCountry handles non-Rwanda local numbers", () => {
  assertEquals(
    normalizePhoneWithCountry("0999 971 114", "+356"),
    "+356999971114",
  );
  assertEquals(
    normalizePhoneWithCountry("020 7946 0958", "+44"),
    "+442079460958",
  );
});

Deno.test("normalizePhoneWithCountry keeps 00-prefixed international numbers", () => {
  assertEquals(
    normalizePhoneWithCountry("004915112345678", "+49"),
    "+4915112345678",
  );
});
