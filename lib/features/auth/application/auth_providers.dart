import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/auth/integrity_providers.dart';
import 'package:mobi_app/features/auth/data/whatsapp_login_service.dart';

final whatsappLoginServiceProvider = Provider(
  (ref) => WhatsAppLoginService(
    playIntegrityEvidenceProvider: ref
        .read(playIntegrityServiceProvider)
        .evidenceForAction,
  ),
);
