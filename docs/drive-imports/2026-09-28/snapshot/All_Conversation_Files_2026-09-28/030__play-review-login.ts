export const GOOGLE_PLAY_REVIEW_PHONE = "+250788767816";
export const GOOGLE_PLAY_REVIEW_OTP = "123456";

export function isGooglePlayReviewPhone(phone: string): boolean {
  return phone.trim() == GOOGLE_PLAY_REVIEW_PHONE;
}

export function isGooglePlayReviewOtp(phone: string, code: string): boolean {
  return isGooglePlayReviewPhone(phone) &&
    code.trim() == GOOGLE_PLAY_REVIEW_OTP;
}

export function googlePlayReviewMetadata() {
  return {
    google_play_review_login: true,
    review_account_phone: GOOGLE_PLAY_REVIEW_PHONE,
  };
}

export function appLoginOtpDelivery(isReviewLogin: boolean) {
  return isReviewLogin
    ? {
      deliveryMode: "review_code",
      message:
        "Use the code supplied for store review. No WhatsApp message is sent.",
    }
    : {
      deliveryMode: "whatsapp",
      message: "OTP sent to your WhatsApp",
    };
}
