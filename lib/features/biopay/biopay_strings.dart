abstract final class BiopayStrings {
  static const registerTitle = 'Face ID';
  static const registerSubtitle = 'Link your Face ID.';
  static const registerConsent =
      'BioPay creates a face embedding on-device, sends it securely to Mobio for matching, and lets you delete it later from Privacy & Data.';

  static const reenrollTitle = 'Re-link Face ID';
  static const reenrollSubtitle = 'Update your secure face embedding.';

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

  // Quality guidance — Kinyarwanda (G-7)
  static const qualityLowLightRw = "Jya ahantu h'umucyo";
  static const qualityTooBrightRw = 'Umucyo ni mwinshi — jya mu gicucu';
  static const qualityFaceTooSmallRw = "Egera hafi y'ikamera";
  static const qualityMultipleFacesRw = 'Umuntu umwe gusa agomba kugaragara';
  static const qualityYawTooHighRw = 'Erekeza mu kamera';
  static const qualityEyesClosedRw = 'Fungura amaso yawe';

  static const managementCodeTitle = 'Your Management Code';
  static const managementCodeBody =
      'Save this code securely. You will need it to manage your BioPay profile from another device.';
}
