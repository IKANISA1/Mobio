import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/constants/app_enums.dart';
import 'package:mobi_app/features/auth/data/whatsapp_login_service.dart';

/// Network-free responses for actual WhatsApp login widget journeys.
class FakeWhatsAppLoginService implements WhatsAppLoginService {
  Future<WhatsAppLoginResult> Function()? send;
  Future<WhatsAppLoginResult> Function()? verify;
  int sendCount = 0;
  String? lastPhone;
  String? lastCode;
  AppRole? lastRole;

  @override
  Future<void> cancelVerification({required Object owner}) async {}

  @override
  Future<WhatsAppLoginResult> sendLoginOtp({
    required String phone,
    required String countryCode,
    required AppRole role,
  }) async {
    sendCount++;
    lastPhone = phone;
    lastRole = role;
    return send != null
        ? send!()
        : const WhatsAppLoginResult(success: true, retryAfterSeconds: 60);
  }

  @override
  Future<WhatsAppLoginResult> verifyLoginOtp({
    Object? owner,
    required String phone,
    required String code,
    required String countryCode,
    required AppRole role,
  }) async {
    lastCode = code;
    lastRole = role;
    return verify != null
        ? verify!()
        : WhatsAppLoginResult(success: true, role: role);
  }
}

Future<void> enterPreviewPhone(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, '789000123');
  tester.testTextInput.hide();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> requestPreviewCode(WidgetTester tester) async {
  await enterPreviewPhone(tester);
  await tester.ensureVisible(find.text('Send code'));
  await tester.tap(find.text('Send code'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> enterPreviewCode(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('mobi_otp_digit_0')),
    '123456',
  );
  tester.testTextInput.hide();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}
