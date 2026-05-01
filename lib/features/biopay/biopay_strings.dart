abstract final class BiopayStrings {
  static const registerTitle = 'Face ID';
  static const registerSubtitle = 'Link your face for secure payments.';

  static const reenrollTitle = 'Update Face ID';
  static const reenrollSubtitle = 'Refresh your face data.';

  static const scanTitle = 'Scan To Pay';
  static const scanSubtitle =
      'Point the camera at the payee to match their BioPay profile.';
  static const scanSearching = 'Looking for a face...';
  static const scanLocked = 'Face locked. Hold steady...';
  static const scanMatching = 'Matching face...';
  static const scanNoMatch = 'No BioPay match found. Try again.';

  // Quality guidance — English
  static const qualityLowLight = 'Move to a brighter area';
  static const qualityTooBright =
      'Too bright — reduce lighting or move to shade';
  static const qualityFaceTooSmall = 'Move closer to the camera';
  static const qualityMultipleFaces = 'Only one face should be visible';
  static const qualityYawTooHigh = 'Face the camera directly';
  static const qualityEyesClosed = 'Please open your eyes';

  // Aliases for controller compatibility
  static String get qualityTooFar => qualityFaceTooSmall;
  static String get qualityBadAngle => qualityYawTooHigh;
  static String get qualityTooDark => qualityLowLight;
  static String get qualityTooBlurry => 'Hold still, image is blurry';

  static const managementCodeTitle = 'Management Code';
  static const managementCodeBody =
      'Save this securely. You\'ll need it to manage your profile on another device.';
}
