// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Mobio';

  @override
  String get tabDiscover => 'Découvrir';

  @override
  String get tabProfile => 'Profil';

  @override
  String get tabDashboard => 'Tableau de bord';

  @override
  String get tabUsers => 'Utilisateurs';

  @override
  String get modePassenger => 'Passager';

  @override
  String get modeDriver => 'Chauffeur';

  @override
  String get errorGeneric => 'Quelque chose a mal tourné';

  @override
  String get errorNoNetwork => 'Pas de connexion Internet';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get done => 'Terminé';

  @override
  String get loading => 'Chargement…';

  @override
  String get noResults => 'Aucun résultat trouvé';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get configErrorTitle => 'Impossible de démarrer Mobio';

  @override
  String get configErrorBody =>
      'Cet APK a été compilé sans SUPABASE_URL et SUPABASE_ANON_KEY.';

  @override
  String get configErrorAction =>
      'Recompilez l\'application avec les valeurs --dart-define pour les deux clés.';

  @override
  String get whatsappOpenChat => 'Ouvrir WhatsApp';

  @override
  String get scheduleTrip => 'Planifier un trajet';

  @override
  String get viewBookings => 'Réservations';

  @override
  String get nearby => 'À proximité';

  @override
  String get bpPay => 'Payer';

  @override
  String get bpRecipient => 'Qui payez-vous ?';

  @override
  String get bpPhone => 'Numéro de téléphone';

  @override
  String get bpContacts => 'Choisir un contact';

  @override
  String get bpManual => 'Saisir les coordonnées';

  @override
  String get bpContinue => 'Continuer';

  @override
  String get bpMethods => 'Moyens de paiement';

  @override
  String get bpAddMethod => 'Ajouter un moyen';

  @override
  String get bpSave => 'Enregistrer';

  @override
  String get bpSaved => 'Enregistré';

  @override
  String get bpNotSaved => 'Modifications non enregistrées';

  @override
  String get bpSaveDraft => 'Enregistrer pour plus tard';

  @override
  String get bpProvider => 'Établissement';

  @override
  String get bpMethodKind => 'Type de compte';

  @override
  String get bpIdentifier => 'Numéro ou compte destinataire';

  @override
  String get bpLabel => 'Votre libellé';

  @override
  String get bpLoginPhone => 'Téléphone de connexion bancaire (facultatif)';

  @override
  String get bpSim => 'Libellé SIM (facultatif)';

  @override
  String get bpSendRole => 'Payer depuis ce compte';

  @override
  String get bpReceiveRole => 'Recevoir ici';

  @override
  String get bpDiscoverable =>
      'Partager avec ceux qui connaissent mon téléphone vérifié';

  @override
  String get bpPreferred => 'Utiliser comme compte préféré';

  @override
  String get bpPrivateDefault => 'Privé jusqu’à votre partage';

  @override
  String get bpAmount => 'Montant (RWF)';

  @override
  String get bpWholeAmount => 'Saisissez 1 à 10 000 000 RWF entiers';

  @override
  String get bpPurpose => 'Objet du paiement';

  @override
  String get bpTransfer => 'Virement à une personne';

  @override
  String get bpMerchant => 'Payer un commerçant';

  @override
  String get bpReference => 'Référence (facultative)';

  @override
  String get bpFrom => 'Depuis';

  @override
  String get bpMyAccounts => 'Mes comptes';

  @override
  String get bpAllAccounts => 'Comparer mes comptes';

  @override
  String get bpCompare => 'Trouver les options';

  @override
  String get bpOptions => 'Options de paiement';

  @override
  String get bpMore => 'Autres options';

  @override
  String get bpNoOptions =>
      'Aucune option validée. Vérifiez le compte source, le libellé SIM et les coordonnées.';

  @override
  String get bpNoShared =>
      'Aucune coordonnée partagée avec vous. Saisissez-les ou demandez-les au destinataire.';

  @override
  String get bpUnverified =>
      'Coordonnées saisies — vérifiez avec le destinataire';

  @override
  String get bpShared => 'Coordonnées partagées via Mobio';

  @override
  String get bpFee => 'Frais';

  @override
  String get bpFeeUnknown => 'Frais inconnus';

  @override
  String get bpFeeCap => 'Frais jusqu’à';

  @override
  String get bpPartialFee =>
      'Frais de cet établissement ; autres frais inconnus';

  @override
  String get bpTotal => 'Total';

  @override
  String get bpTotalCap => 'Total jusqu’à';

  @override
  String get bpReview => 'Vérifier le paiement';

  @override
  String get bpChange => 'Modifier';

  @override
  String get bpOpenProvider => 'Ouvrir les instructions';

  @override
  String get bpOpenMomo => 'Ouvrir MoMo';

  @override
  String get bpOpenBank => 'Ouvrir le menu bancaire';

  @override
  String get bpCopy => 'Copier';

  @override
  String get bpCopied => 'Copié';

  @override
  String get bpCopyInstructions => 'Copier les instructions';

  @override
  String get bpSimGuidance =>
      'Choisissez la SIM liée au compte source dans le composeur.';

  @override
  String get bpExternalOnly =>
      'Terminez chez votre prestataire. Saisissez votre code PIN uniquement là-bas.';

  @override
  String get bpOutcome => 'État du paiement';

  @override
  String get bpOutcomeUnknown => 'Confirmation indisponible';

  @override
  String get bpOutcomeHelp =>
      'Revenir dans Mobio ne confirme pas le paiement. Vérifiez auprès du prestataire avant de réessayer.';

  @override
  String get bpUserReported => 'Vous avez déclaré avoir terminé';

  @override
  String get bpReportDone => 'J’ai terminé les étapes du prestataire';

  @override
  String get bpPrepared => 'Prêt à ouvrir le prestataire';

  @override
  String get bpHandoff => 'Prestataire ouvert';

  @override
  String get bpOperatorReviewed => 'Examiné par un opérateur';

  @override
  String get bpReceiverAcknowledged => 'Accusé par le destinataire';

  @override
  String get bpProviderConfirmed => 'Confirmation du prestataire reçue';

  @override
  String get bpRefreshRequired =>
      'Reconnectez-vous, actualisez et vérifiez à nouveau.';

  @override
  String get bpRefresh => 'Actualiser';

  @override
  String get bpRequests => 'Demandes de paiement';

  @override
  String get bpCreateRequest => 'Créer une demande';

  @override
  String get bpShare => 'Partager';

  @override
  String get bpScope => 'Périmètre du partage';

  @override
  String get bpProfileScope => 'Moyens de réception sélectionnés';

  @override
  String get bpMethodScope => 'Un moyen de réception';

  @override
  String get bpRequestScope => 'Demande de montant';

  @override
  String get bpAnyAmount => 'Laisser le payeur saisir le montant';

  @override
  String get bpExpiry => 'Expire le';

  @override
  String get bpActive => 'Actif';

  @override
  String get bpExpired => 'Expiré';

  @override
  String get bpRevoked => 'Révoqué';

  @override
  String get bpRevoke => 'Révoquer le lien';

  @override
  String get bpViewAsPayer => 'Voir comme payeur';

  @override
  String get bpSharing => 'Contrôles du partage';

  @override
  String get bpGrantee => 'ID Mobio (6 chiffres)';

  @override
  String get bpGrant => 'Partager avec ce compte';

  @override
  String get bpRemove => 'Supprimer';

  @override
  String get bpActivity => 'Activité';

  @override
  String get bpRecents => 'Destinataires récents';

  @override
  String get bpFavorite => 'Favori';

  @override
  String get bpNickname => 'Surnom privé';

  @override
  String get bpPayAgain => 'Payer à nouveau';

  @override
  String get bpTemplates => 'Modèles de demande';

  @override
  String get bpSaveTemplate => 'Enregistrer comme modèle';

  @override
  String get bpUseTemplate => 'Créer une nouvelle demande';

  @override
  String get bpEmpty => 'Aucun élément pour le moment';

  @override
  String get bpSupport => 'Obtenir de l’aide';

  @override
  String get bpSupportSummary => 'Vérifier le résumé d’assistance';

  @override
  String get bpSupportNotice =>
      'Partagez ce résumé uniquement si vous souhaitez le transmettre à l’assistance.';

  @override
  String get bpScan => 'Scanner un QR';

  @override
  String get bpPaste => 'Coller un lien de paiement';

  @override
  String get bpGallery => 'Choisir une image QR';

  @override
  String get bpInvalidQr =>
      'Ce code de paiement Mobio n’est pas pris en charge.';

  @override
  String get bpCancel => 'Annuler';

  @override
  String get bpBack => 'Retour';

  @override
  String get bpSignIn => 'Se connecter pour continuer';

  @override
  String get bpLinkUnavailable =>
      'Demande indisponible. Demandez un nouveau lien.';

  @override
  String get bpUsePhone =>
      'Ouvrez ce lien sur votre téléphone pour utiliser le prestataire.';

  @override
  String get bpManualDevice =>
      'Cet appareil utilise les instructions manuelles.';

  @override
  String get bpSourceUnavailable =>
      'Envoi non activé, ou libellé SIM requis manquant';

  @override
  String get bpCheckFields => 'Vérifiez les coordonnées saisies.';

  @override
  String get bpResume => 'Reprendre le paiement enregistré';

  @override
  String get bpNewPayment => 'Nouveau paiement';

  @override
  String get bpBankAccount => 'Compte bancaire';

  @override
  String get bpBankAlias => 'Alias bancaire pris en charge';

  @override
  String get bpRoutes => 'Parcours prestataires';

  @override
  String get bpRouteEvidence => 'Preuves prestataire et tarif';

  @override
  String get bpAddRoute => 'Ajouter un parcours à vérifier';

  @override
  String get bpDraftRoute => 'Brouillon';

  @override
  String get bpTestedRoute => 'Tests appareil enregistrés';

  @override
  String get bpApprovedRoute => 'Approuvé';

  @override
  String get bpDisabledRoute => 'Désactivé';

  @override
  String get bpRecordTest => 'Enregistrer les tests terminés';

  @override
  String get bpApproveRoute => 'Approuver la version testée';

  @override
  String get bpDisableRoute => 'Désactiver ce parcours';

  @override
  String get bpRouteNotice =>
      'Les codes d’entrée sont des éléments de recherche. Des instructions complètes testées et un examen indépendant sont requis avant activation.';

  @override
  String get bpDestinationProvider => 'Établissement destinataire';

  @override
  String get bpRail => 'Réseau de paiement';

  @override
  String get bpMinAmount => 'Minimum RWF';

  @override
  String get bpMaxAmount => 'Maximum RWF';

  @override
  String get bpExactFee => 'Frais exacts';

  @override
  String get bpCappedFee => 'Plafond de frais';

  @override
  String get bpAllInFee => 'Inclut tous les frais';

  @override
  String get bpSteps => 'Nombre d’étapes vérifié (facultatif)';

  @override
  String get bpInstruction => 'Modèle d’instructions validé';

  @override
  String get bpInstructionHelp =>
      'Utilisez les paramètres destinataire et montant. Jamais de code PIN ni d’identifiant secret.';

  @override
  String get bpDeviceEvidence => 'Lien des preuves de test appareil';

  @override
  String get bpTariffEvidence => 'Lien de preuve tarifaire';

  @override
  String get bpRequiresSim => 'Nécessite une SIM liée';

  @override
  String get bpRequiresLoginPhone => 'Nécessite le téléphone bancaire';

  @override
  String get bpDialMode => 'Composeur contrôlé par l’utilisateur';

  @override
  String get bpManualMode => 'Instructions manuelles';

  @override
  String get bpReviewVersion => 'Version';

  @override
  String get bpNfcWrite => 'Écrire une carte NFC';

  @override
  String get bpNfcHold => 'Approchez la carte du téléphone';

  @override
  String get bpNfcScoped =>
      'Choisissez un lien enregistré. Sa révocation désactive aussi le lien de cette carte.';

  @override
  String get bpNfcRecovery =>
      'Vérifiez que le NFC est activé puis réessayez, ou partagez le lien.';

  @override
  String get bpNfcVerified => 'Carte écrite et relue avec succès';

  @override
  String get bpBearerScope =>
      'Toute personne disposant du lien peut voir ces coordonnées après connexion, jusqu’à expiration ou révocation.';

  @override
  String get bpFeeReviewed => 'Preuve tarifaire examinée';

  @override
  String get bpCheckProviderFee => 'Vérifiez les frais chez votre prestataire';

  @override
  String get bpValidFrom => 'Valide à partir du (UTC)';

  @override
  String get bpValidUntil => 'Valide jusqu’au (UTC)';

  @override
  String get bpTestEvidence => 'URL des preuves de test sur appareil';

  @override
  String get bpRecipientFormat => 'Format du destinataire chez le prestataire';

  @override
  String get bpOriginalIdentifier => 'Identifiant original';

  @override
  String get bpReferenceLocalOnly =>
      'Ce parcours ne transmet pas la référence. Elle reste dans votre activité Mobio.';

  @override
  String get bpLeaveDraft =>
      'Enregistrez ce brouillon pour continuer plus tard. En cas d’échec, vos saisies restent sur cet écran.';

  @override
  String get bpDiscard => 'Abandonner les modifications';

  @override
  String get bpDetailsChanged =>
      'Les coordonnées de réception ont changé. Créez un nouveau lien.';

  @override
  String get bpSaveQr => 'Enregistrer le QR';

  @override
  String get bpRecipientChanged =>
      'Les coordonnées de réception ont changé. Comparez à nouveau les options.';

  @override
  String get bpSourceChanged =>
      'Votre compte source a changé. Comparez à nouveau les options.';

  @override
  String get bpFeeChanged =>
      'Les informations sur les frais ont changé. Comparez à nouveau les options.';

  @override
  String get bpRouteChanged =>
      'Cette option ou son autorisation de partage a changé. Comparez à nouveau.';

  @override
  String get bpNfcLock => 'Rendre la carte non modifiable';

  @override
  String get bpNfcLockNotice =>
      'Cette action empêche définitivement de réécrire la carte. Le lien peut toujours expirer ou être révoqué : la carte ne donnera alors plus accès à une demande utilisable. Vérifiez le lien avant de verrouiller.';

  @override
  String get bpNfcLocked => 'La carte est non modifiable';

  @override
  String get bpAcknowledge => 'J’ai reçu ce paiement';

  @override
  String get bpRecordEvidence => 'Enregistrer une preuve externe';

  @override
  String get bpEvidenceReference =>
      'Référence de la preuve (6 caractères minimum)';

  @override
  String get bpOperatorNotice =>
      'Saisissez la référence de la preuve examinée. Cela enregistre un examen par un opérateur, sans créer de reçu confirmé par le prestataire.';

  @override
  String get bpMissingSim =>
      'Indiquez la SIM de ce compte dans Moyens de paiement, puis comparez à nouveau.';

  @override
  String get bpMissingLogin =>
      'Ajoutez le numéro de connexion de ce compte bancaire dans Moyens de paiement, puis comparez à nouveau.';

  @override
  String get faceRegister => 'Enregistrer mon visage';

  @override
  String get faceScanTitle => 'Scanner pour payer';

  @override
  String get faceScanInstruction =>
      'Scannez la personne que vous voulez payer.';

  @override
  String get faceRegisterInstruction => 'Placez votre visage dans le cadre.';

  @override
  String get faceConsent =>
      'Permettez aux autres de trouver votre numéro de réception MoMo en scannant votre visage. Vous pouvez le supprimer à tout moment.';

  @override
  String get faceReceivingMethod => 'Numéro de réception MoMo';

  @override
  String get faceManageMethods => 'Ajouter ou modifier les numéros';

  @override
  String get faceStartCamera => 'Ouvrir la caméra';

  @override
  String get faceCapture => 'Prendre une photo';

  @override
  String get faceScanAction => 'Scanner le destinataire';

  @override
  String get faceUpdate => 'Actualiser le visage';

  @override
  String get facePause => 'Suspendre la recherche par visage';

  @override
  String get faceResume => 'Réactiver la recherche par visage';

  @override
  String get faceRemove => 'Supprimer mon visage';

  @override
  String get faceReady => 'Visage enregistré';

  @override
  String get faceProcessing => 'Enregistrement du visage…';

  @override
  String get facePaused => 'Recherche par visage suspendue';

  @override
  String get faceRemoved => 'Votre visage a été supprimé';

  @override
  String get faceReenroll =>
      'Actualisez votre visage pour continuer à utiliser Scanner pour payer.';

  @override
  String get faceOpening => 'Ouverture de MoMo…';

  @override
  String get faceOpened =>
      'Continuez dans le composeur. MoMo gère le montant et le code PIN.';

  @override
  String get faceManualPlatform =>
      'L’ouverture automatique USSD est disponible sur Android. Copiez ce code et utilisez un téléphone compatible.';

  @override
  String get faceCopyCode => 'Copier le code USSD';

  @override
  String get faceCopied => 'Code copié';

  @override
  String get faceNoMatch =>
      'Aucun destinataire trouvé. Réessayez ou utilisez un numéro ou un QR.';

  @override
  String get faceAmbiguous =>
      'Résultat incertain. Reprenez une photo ou utilisez un numéro ou un QR.';

  @override
  String get faceNoFace =>
      'Aucun visage détecté. Gardez le visage dans le cadre.';

  @override
  String get faceMultiple => 'Gardez un seul visage dans le cadre.';

  @override
  String get facePoorCapture =>
      'Éclairez mieux le visage et stabilisez la caméra.';

  @override
  String get faceUnavailable =>
      'La recherche par visage est indisponible. Réessayez ou utilisez un numéro ou un QR.';

  @override
  String get faceRecipientUnavailable =>
      'Ce destinataire n’a pas de numéro de réception disponible. Utilisez un numéro ou un QR.';

  @override
  String get faceCameraError =>
      'Caméra indisponible. Vérifiez l’autorisation, puis réessayez.';

  @override
  String get faceTimeout => 'Cela prend trop de temps. Réessayez.';

  @override
  String get faceOutcomeUnknown =>
      'Le résultat n’est pas confirmé. Vérifiez l’état actuel ou l’activité avant de réessayer.';

  @override
  String get faceSignIn => 'Reconnectez-vous pour continuer.';

  @override
  String get faceSelectMethod =>
      'Choisissez d’abord un numéro de réception MoMo.';

  @override
  String get faceDialFailed =>
      'Le composeur n’a pas pu s’ouvrir. Copiez le code ou utilisez une autre méthode.';

  @override
  String get faceManual => 'Utiliser un numéro';

  @override
  String get faceQr => 'Scanner un QR';

  @override
  String get faceTryAgain => 'Réessayer';

  @override
  String get faceDone => 'Terminé';

  @override
  String get faceWorking => 'Veuillez patienter…';

  @override
  String get faceSetUp => 'Configurer';

  @override
  String get faceRefresh => 'Vérifier l’enregistrement';
}
