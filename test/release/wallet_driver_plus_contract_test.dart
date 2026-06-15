import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260614120000_wallet_referrals_driver_plus.sql';
  const serviceRoleCompatMigrationPath =
      'supabase/migrations/20260614124500_service_role_claim_compat.sql';
  const momoPayerPhoneMigrationPath =
      'supabase/migrations/20260614165000_driver_subscription_momo_payer_phone_matching.sql';
  const scheduledChatPrivacyMigrationPath =
      'supabase/migrations/20260614170000_driver_passenger_scheduled_chat_privacy.sql';
  const helperGrantMigrationPath =
      'supabase/migrations/20260614171500_driver_plus_helper_function_grants.sql';
  const subscriptionStartIdempotencyMigrationPath =
      'supabase/migrations/20260614172000_driver_subscription_start_idempotency.sql';
  const momoOpenAiTransactionsMigrationPath =
      'supabase/migrations/20260614221500_driver_subscription_momo_openai_transactions.sql';
  const productionReadinessMigrationPath =
      'supabase/migrations/20260615103000_wallet_subscription_production_readiness.sql';
  const chatScreenPath = 'lib/features/chat/chat_screen.dart';
  const referralAttributionServicePath =
      'lib/core/services/referral_attribution_service.dart';
  const walletScreenPath = 'lib/features/profile/wallet_screen.dart';
  const driverPlusScreenPath = 'lib/features/profile/driver_plus_screen.dart';
  const appRouterPath = 'lib/core/router/app_router.dart';

  test('wallet and referral rewards are server-owned', () {
    final sql = File(migrationPath).readAsStringSync();
    final referralAttributionService = File(
      referralAttributionServicePath,
    ).readAsStringSync();
    final walletScreen = File(walletScreenPath).readAsStringSync();
    final walletService = File(
      'lib/core/services/wallet_service.dart',
    ).readAsStringSync();
    final appRouter = File(appRouterPath).readAsStringSync();
    final productionReadinessSql = File(
      productionReadinessMigrationPath,
    ).readAsStringSync();

    expect(sql, contains('create table if not exists public.token_wallets'));
    expect(
      sql,
      contains('create table if not exists public.token_ledger_entries'),
    );
    expect(sql, contains('rpc_transfer_tokens'));
    expect(
      productionReadinessSql,
      contains('rpc_lookup_wallet_transfer_recipient'),
    );
    expect(
      productionReadinessSql,
      contains('rpc_admin_reverse_wallet_transfer'),
    );
    expect(productionReadinessSql, contains('wallet_transfer_reversal'));
    expect(productionReadinessSql, contains('install_confidence'));
    expect(productionReadinessSql, contains('reward_confidence'));
    expect(productionReadinessSql, contains('manual_review_recommended'));
    expect(sql, contains('rpc_complete_referral_signup'));
    expect(sql, contains('Successful Mobio app share'));
    expect(sql, contains('100'));
    expect(sql, contains('install_not_verified'));
    expect(sql, contains('duplicate_install'));
    expect(sql, contains('uq_referral_reward_install_once'));
    expect(referralAttributionService, contains('iosul_'));
    expect(
      referralAttributionService,
      contains('ios_universal_link_first_open'),
    );
    expect(
      referralAttributionService,
      contains('shouldCreateIosUniversalLinkInstallId'),
    );
    expect(
      referralAttributionService,
      contains('await prefs.remove(_pendingInstallIdKey)'),
    );
    expect(
      sql,
      contains('revoke insert, update, delete on public.token_wallets'),
    );
    expect(walletScreen, contains('referral.shareUrl'));
    expect(walletScreen, isNot(contains("'\${referral.shareUrl}?ref=")));
    expect(walletScreen, contains("RegExp(r'^\\d{6}\$')"));
    expect(walletScreen, contains('FilteringTextInputFormatter.digitsOnly'));
    expect(walletScreen, contains('_confirmAndTransferTokens'));
    expect(walletScreen, contains('Confirm transfer'));
    expect(walletScreen, contains('Transfer sent'));
    expect(walletScreen, contains('SharedPreferences.getInstance'));
    expect(walletService, contains('idempotencyKey'));
    expect(
      walletService,
      isNot(contains('DateTime.now().microsecondsSinceEpoch')),
    );
    expect(walletScreen, contains('Invite and earn'));
    expect(walletScreen, contains('Share invite'));
    expect(walletScreen, contains('Copy link'));
    expect(appRouter, contains('_safePopToProfile'));
    expect(appRouter, contains('context.go(AppRoutes.profile)'));
  });

  test('driver subscriptions use tokens or MoMo USSD only', () {
    final sql = File(migrationPath).readAsStringSync();
    final compatSql = File(serviceRoleCompatMigrationPath).readAsStringSync();
    final payerPhoneSql = File(momoPayerPhoneMigrationPath).readAsStringSync();
    final helperGrantSql = File(helperGrantMigrationPath).readAsStringSync();
    final idempotencySql = File(
      subscriptionStartIdempotencyMigrationPath,
    ).readAsStringSync();
    final momoOpenAiTransactionsSql = File(
      momoOpenAiTransactionsMigrationPath,
    ).readAsStringSync();
    final momoSmsParser = File(
      'supabase/functions/_shared/momo-sms.ts',
    ).readAsStringSync();
    final driverPlusService = File(
      'lib/core/services/driver_plus_service.dart',
    ).readAsStringSync();
    final driverPlusScreen = File(driverPlusScreenPath).readAsStringSync();
    final adminSubscriptionsScreen = File(
      'lib/features/admin/admin_subscriptions_screen.dart',
    ).readAsStringSync();
    final subscriptionPlanService = File(
      'lib/core/services/subscription_plan_service.dart',
    ).readAsStringSync();
    final productionReadinessSql = File(
      productionReadinessMigrationPath,
    ).readAsStringSync();

    expect(sql, contains("payment_method in ('tokens', 'momo_ussd')"));
    expect(sql, contains("'12345'"));
    expect(sql, contains("'*182*8*1*12345*'"));
    expect(sql, contains('rpc_start_driver_subscription'));
    expect(idempotencySql, contains('client_request_id text'));
    expect(
      idempotencySql,
      contains('uq_driver_subscription_payment_requests_client_request'),
    );
    expect(
      idempotencySql,
      contains('rpc_start_driver_subscription(uuid, text, text)'),
    );
    expect(idempotencySql, contains('p_client_request_id'));
    expect(driverPlusService, contains('p_client_request_id'));
    expect(driverPlusService, contains(r'tel:$encoded'));
    expect(driverPlusScreen, contains('SharedPreferences.getInstance'));
    expect(driverPlusScreen, contains('_subscriptionKeyScope'));
    expect(driverPlusScreen, contains('DRIVER_PROFILE_REQUIRED'));
    expect(driverPlusScreen, contains('SUBSCRIPTION_PLAN_NOT_FOUND'));
    expect(sql, contains('rpc_confirm_driver_subscription_payment'));
    expect(sql, contains('rpc_ingest_driver_subscription_momo_sms'));
    expect(sql, contains('driver_subscription_momo_sms_receipts'));
    expect(
      productionReadinessSql,
      contains('rpc_admin_expire_driver_subscription_payment_requests'),
    );
    expect(
      productionReadinessSql,
      contains('rpc_admin_confirm_momo_sms_receipt'),
    );
    expect(subscriptionPlanService, contains('expireStalePaymentRequests'));
    expect(subscriptionPlanService, contains('confirmMomoSmsReceipt'));
    expect(adminSubscriptionsScreen, contains('Expire stale'));
    expect(adminSubscriptionsScreen, contains('Confirm match'));
    expect(
      momoOpenAiTransactionsSql,
      contains('driver_subscription_momo_transactions'),
    );
    expect(
      momoOpenAiTransactionsSql,
      contains('_sync_driver_subscription_momo_transaction_from_receipt'),
    );
    expect(momoSmsParser, contains('parseMomoSmsWithOpenAi'));
    expect(momoSmsParser, contains('https://api.openai.com/v1/responses'));
    expect(momoSmsParser, contains('OPENAI_API_KEY_REQUIRED'));
    expect(sql, contains('momo_sms_bridge'));
    expect(sql, contains('ambiguous'));
    expect(
      payerPhoneSql,
      contains('_set_subscription_payment_request_payer_snapshot'),
    );
    expect(payerPhoneSql, contains('_momo_phone_match'));
    expect(
      helperGrantSql,
      contains('revoke all on function public._momo_phone_match(text, text)'),
    );
    expect(
      helperGrantSql,
      contains(
        'revoke all on function public._set_subscription_payment_request_payer_snapshot()',
      ),
    );
    expect(payerPhoneSql, contains("'momo_sms_match_fields'"));
    expect(sql, contains("current_setting('request.jwt.claims', true)"));
    expect(compatSql, contains("current_setting('request.jwt.claims', true)"));
    expect(sql.toLowerCase(), isNot(contains('stripe')));

    expect(driverPlusScreen, contains('walletBalanceTokens'));
    expect(driverPlusScreen, contains('walletBalanceTokens >= tokenCost'));
    expect(driverPlusScreen, contains('Pay with MoMo'));
    expect(driverPlusScreen, isNot(contains('MoMo USSD')));
    expect(
      driverPlusScreen,
      isNot(contains('Upgrade to read passenger messages')),
    );
  });

  test('wallet and Mobio Plus pushed pages keep responsive navigation', () {
    final appRouter = File(appRouterPath).readAsStringSync();
    final walletScreen = File(walletScreenPath).readAsStringSync();
    final driverPlusScreen = File(driverPlusScreenPath).readAsStringSync();
    final mobiPageHeader = File(
      'lib/shared/widgets/mobi_page_header.dart',
    ).readAsStringSync();
    final tappableIconButton = File(
      'lib/shared/widgets/tappable_icon_button.dart',
    ).readAsStringSync();

    expect(appRouter, contains('void _safePopToProfile(BuildContext context)'));
    expect(appRouter, contains('context.go(AppRoutes.profile)'));
    expect(appRouter, isNot(contains('if (Navigator.of(context).canPop())')));
    expect(walletScreen, contains('SupabaseConfig.canRunWithoutBackend'));
    expect(driverPlusScreen, contains('SupabaseConfig.canRunWithoutBackend'));
    expect(walletScreen, contains('_previewWalletSummary'));
    expect(walletScreen, contains('_previewLedgerEntries'));
    expect(driverPlusScreen, contains('_previewDriverPlusWallet'));
    expect(driverPlusScreen, contains('_previewDriverPlusPlans'));
    expect(walletScreen, contains("title: 'Wallet unavailable'"));
    expect(driverPlusScreen, contains("title: 'Mobio Plus unavailable'"));
    expect(walletScreen, contains('MobiErrorState'));
    expect(driverPlusScreen, contains('MobiErrorState'));
    expect(walletScreen, contains('onRetry: _load'));
    expect(driverPlusScreen, contains('onRetry: _load'));
    expect(walletScreen, contains("retryLabel: 'Refresh'"));
    expect(driverPlusScreen, contains("retryLabel: 'Refresh'"));

    expect(mobiPageHeader, contains("semanticLabel: 'Back'"));
    expect(mobiPageHeader, contains('const BoxConstraints(minHeight: 56)'));
    expect(mobiPageHeader, contains('FittedBox'));
    expect(
      mobiPageHeader,
      contains('const BoxConstraints(minWidth: 48, minHeight: 48)'),
    );
    expect(tappableIconButton, contains('SystemMouseCursors.click'));
    expect(tappableIconButton, contains('Feedback.forTap(context)'));
    expect(tappableIconButton, contains('enabled: onTap != null'));
  });

  test('plus rules protect driver chat access server-side', () {
    final sql = File(migrationPath).readAsStringSync();
    final scheduledPrivacySql = File(
      scheduledChatPrivacyMigrationPath,
    ).readAsStringSync();
    final chatScreen = File(chatScreenPath).readAsStringSync();

    expect(
      sql,
      contains('create table if not exists public.driver_plus_rules'),
    );
    expect(sql, contains("('bus', false, 0, 0, 0, true, true)"));
    expect(sql, contains("('private', true, 0, 0, 0, false, true)"));
    expect(sql, contains('rpc_send_chat_message'));
    expect(sql, contains('MOBIO_PLUS_REQUIRED'));
    expect(sql, contains('rpc_list_chat_messages'));
    expect(sql, contains('revoke select on public.chat_messages'));
    expect(sql, contains('chat_messages_insert_rpc_only'));
    expect(sql, isNot(contains('v_profile.created_at + make_interval')));
    expect(scheduledPrivacySql, contains("v_trip.role = 'passenger'"));
    expect(
      scheduledPrivacySql,
      contains('Upgrade to Mobio Plus to message passenger scheduled trips.'),
    );
    expect(
      scheduledPrivacySql,
      contains('Mobio Plus required to read this passenger message.'),
    );
    expect(chatScreen, contains('_externalDriverContactLocked'));
    expect(chatScreen, contains('!_externalDriverContactLocked &&'));
    expect(
      chatScreen,
      contains('External contact is available with Mobio Plus.'),
    );
  });
}
