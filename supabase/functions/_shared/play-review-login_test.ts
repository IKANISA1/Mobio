import {
  GOOGLE_PLAY_REVIEW_OTP,
  GOOGLE_PLAY_REVIEW_PHONE,
  googlePlayReviewMetadata,
  isGooglePlayReviewOtp,
  isGooglePlayReviewPhone,
} from "./play-review-login.ts";

Deno.test("Google Play review login constants match Play Console credentials", () => {
  if (GOOGLE_PLAY_REVIEW_PHONE != "+250788767816") {
    throw new Error("Unexpected Google Play review phone.");
  }
  if (GOOGLE_PLAY_REVIEW_OTP != "123456") {
    throw new Error("Unexpected Google Play review OTP.");
  }
});

Deno.test("Google Play review login only accepts exact phone and OTP", () => {
  if (!isGooglePlayReviewPhone("+250788767816")) {
    throw new Error("Expected reviewer phone to be accepted.");
  }
  if (isGooglePlayReviewPhone("+250788767817")) {
    throw new Error("Non-reviewer phone must not be accepted.");
  }
  if (!isGooglePlayReviewOtp("+250788767816", "123456")) {
    throw new Error("Expected reviewer OTP to be accepted.");
  }
  if (isGooglePlayReviewOtp("+250788767816", "000000")) {
    throw new Error("Wrong reviewer OTP must not be accepted.");
  }
});

Deno.test("Google Play review metadata is explicit for audit logs", () => {
  const metadata = googlePlayReviewMetadata();
  if (metadata.google_play_review_login != true) {
    throw new Error("Expected audit metadata marker.");
  }
  if (metadata.review_account_phone != GOOGLE_PLAY_REVIEW_PHONE) {
    throw new Error("Expected audit metadata phone.");
  }
});
