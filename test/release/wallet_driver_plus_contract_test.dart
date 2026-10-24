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
  const referralInviteeRewardMigrationPath =
      'supabase/migrations/20260615124500_referral_invitee_reward_and_manual_code.sql';
  const walletRedemptionMigrationPath =
      'supabase/migrations/20260616110000_wallet_redemptions_and_insurance_config.sql';
  const driverPlanCapsMigrationPath =
      'supabase/migrations/20260616002000_driver_plan_caps_rentals_and_moto_allowance.sql';
  const driverVehiclePolicyMigrationPath =
      'supabase/migrations/20260616004500_driver_vehicle_policy_enforcement.sql';
  const chatScreenPath = 'lib/features/chat/presentation/chat_screen.dart';
  const referralAttributionServicePath =
      'lib/features/profile/data/referral_attribution_service.dart';
  const walletScreenPath =
      'lib/features/profile/presentation/wallet_screen.dart';
  const driverPlusScreenPath =
      'lib/features/profile/presentation/driver_plus_screen.dart';
  const appRouterPath = 'lib/app/router/app_router.dart';

  test('wallet and referral rewards are server-owned', () {
    final sql = File(migrationPath).readAsStringSync();
    final referralAttributionService = File(
      referralAttributionServicePath,
    ).readAsStringSync();
    final walletScreen = File(walletScreenPath).readAsStringSync();
    final walletService = File(
      'lib/features/profile/data/wallet_service.dart',
    ).readAsStringSync();
    final walletJournal = File(
      'lib/features/profile/data/wallet_operation_journal.dart',
    ).readAsStringSync();
    final adminService = File(
      'lib/features/admin/data/admin_service.dart',
    ).readAsStringSync();
    final adminUserSheet = File(
      'lib/features/admin/presentation/widgets/admin_user_sheet.dart',
    ).readAsStringSync();
    final appRouter = File(appRouterPath).readAsStringSync();
    final productionReadinessSql = File(
      productionReadinessMigrationPath,
    ).readAsStringSync();
    final referralInviteeRewardSql = File(
      referralInviteeRewardMigrationPath,
    ).readAsStringSync();
    final walletRedemptionSql = File(
      walletRedemptionMigrationPath,
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
    expect(referralInviteeRewardSql, contains('invitee_reward_tokens'));
    expect(referralInviteeRewardSql, contains('v_invitee_id'));
    expect(
      referralInviteeRewardSql,
      contains('Mobio invite code signup reward'),
    );
    expect(
      referralInviteeRewardSql,
      contains('uq_referral_reward_invitee_once'),
    );
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
    // Pending attribution now uses one atomic record. Its acknowledged cleanup,
    // owner races and unknown-outcome replay prevention are exercised through
    // the installed SDK in referral_attribution_race_test.dart.
    expect(
      sql,
      contains('revoke insert, update, delete on public.token_wallets'),
    );
    expect(walletScreen, contains('referral.shareUrl'));
    expect(walletScreen, isNot(contains("'\${referral.shareUrl}?ref=")));
    expect(walletScreen, contains('normalizeMobioMemberId('));
    expect(walletScreen, contains('mobioMemberIdInputError('));
    expect(
      walletScreen,
      contains('LengthLimitingTextInputFormatter(mobioMemberIdLength)'),
    );
    expect(walletScreen, contains('FilteringTextInputFormatter.digitsOnly'));
    expect(walletScreen, contains('_confirmAndTransferTokens'));
    expect(walletScreen, contains('Confirm transfer'));
    expect(walletScreen, contains('Transfer sent'));
    expect(walletScreen, contains('WalletOperationJournal.newOperationId()'));
    expect(walletJournal, contains('SharedPreferences.getInstance'));
    expect(walletService, contains('idempotencyKey'));
    expect(
      walletService,
      isNot(contains('DateTime.now().microsecondsSinceEpoch')),
    );
    expect(walletScreen, contains('Invite and earn'));
    expect(walletScreen, contains('You are getting Mobio'));
    expect(walletScreen, contains('quick rides and instant payment'));
    expect(walletScreen, contains('100 TOKENS'));
    expect(walletScreen, contains('Enter invite code'));
    expect(walletScreen, contains('_walletInviteUrl(summary)'));
    expect(walletScreen, contains('Share invite'));
    expect(walletScreen, contains('Copy link'));
    expect(walletScreen, contains('Redeem'));
    expect(walletScreen, contains('_minimumRedemptionTokens = 5000'));
    expect(walletScreen, contains('_confirmAndRedeemTokens'));
    expect(walletScreen, contains('.redemptionOperation('));
    expect(walletService, contains('rpc_prepare_wallet_operation'));
    expect(walletService, contains('rpc_execute_wallet_operation'));
    expect(walletRedemptionSql, contains('token_redemption_requests'));
    expect(
      walletRedemptionSql,
      contains('amount_tokens bigint not null check (amount_tokens >= 5000)'),
    );
    expect(walletRedemptionSql, contains('token_redemption_admin_member_id'));
    expect(walletRedemptionSql, contains('REGISTERED_MOMO_REQUIRED'));
    expect(
      walletRedemptionSql,
      contains('rpc_admin_list_token_redemption_requests'),
    );
    expect(
      walletRedemptionSql,
      contains('rpc_admin_update_token_redemption_status'),
    );
    expect(walletRedemptionSql, contains('rpc_admin_adjust_user_tokens'));
    expect(walletRedemptionSql, contains('manual_token_credit'));
    expect(adminService, contains('adjustUserTokens'));
    expect(
      adminUserSheet,
      contains('copy.messageRewardAction(copy.number(3000))'),
    );
    expect(adminUserSheet, contains('copy.messageRewardConfirm('));
    expect(adminUserSheet, contains('await onAddInsuranceReward();'));
    final englishCopy = File('lib/l10n/app_en.arb').readAsStringSync();
    expect(englishCopy, contains('Add {amount} TOKENS'));
    expect(englishCopy, contains('Motor insurance purchase reward'));
    expect(appRouter, contains('_safePopToProfile'));
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
      'lib/features/profile/data/driver_plus_service.dart',
    ).readAsStringSync();
    final driverPlusScreen = File(driverPlusScreenPath).readAsStringSync();
    final adminSubscriptionsScreen = File(
      'lib/features/admin/presentation/admin_subscriptions_screen.dart',
    ).readAsStringSync();
    final subscriptionPlanService = File(
      'lib/features/profile/data/subscription_plan_service.dart',
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
    expect(driverPlusService, contains('rw.mobi.app/biopay_ussd_dialer'));
    expect(driverPlusService, contains('launchUssd'));
    expect(driverPlusService, contains('TargetPlatform.android'));
    expect(driverPlusScreen, contains('SharedPreferences.getInstance'));
    expect(driverPlusScreen, contains('_subscriptionKeyScope'));
    expect(driverPlusScreen, contains('DRIVER_PROFILE_REQUIRED'));
    expect(driverPlusScreen, contains('SUBSCRIPTION_PLAN_NOT_FOUND'));
    expect(sql, contains('rpc_confirm_driver_subscription_payment'));
    expect(sql, contains('rpc_ingest_driver_subscription_momo_sms'));
    expect(sql, contains('driver_subscription_momo_sms_receipts'));
    expect(sql, contains('sms_hash text not null unique'));
    expect(sql, contains('uq_driver_subscription_momo_sms_provider_ref'));
    expect(payerPhoneSql, contains('where sms_hash = v_sms_hash'));
    expect(
      payerPhoneSql,
      contains('and provider_transaction_ref = v_provider_ref'),
    );
    expect(payerPhoneSql, contains("'duplicate', true"));
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
    expect(
      momoOpenAiTransactionsSql,
      contains('uq_driver_subscription_momo_transactions_receipt'),
    );
    expect(
      momoOpenAiTransactionsSql,
      contains('uq_driver_subscription_momo_transactions_provider_ref'),
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
    expect(driverPlusScreen, contains('if (canPayTokens)'));
    expect(driverPlusScreen, contains('Pay with TOKENS'));
    expect(driverPlusScreen, isNot(contains('Pay tokens')));
    expect(driverPlusScreen, contains('Pay with MoMo'));
    expect(driverPlusScreen, isNot(contains('MoMo USSD')));
    expect(driverPlusScreen, contains('TextOverflow.ellipsis'));
    expect(driverPlusScreen, contains('softWrap: false'));
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
    final mobiButton = File(
      'lib/shared/widgets/mobi_button.dart',
    ).readAsStringSync();

    expect(appRouter, contains('void _safePopToProfile(BuildContext context)'));
    // Push and direct-entry return behavior is exercised through the real
    // router in app/router/return_navigation_test.dart.
    expect(appRouter, isNot(contains('if (Navigator.of(context).canPop())')));
    expect(walletScreen, contains('SupabaseConfig.canRunWithoutBackend'));
    // The page's explicit local preview gate is stricter than the legacy
    // no-backend alias; real account failures still render unavailable.
    expect(driverPlusScreen, contains('SupabaseConfig.isLocalUiPreview'));
    expect(walletScreen, contains('_previewWalletSummary'));
    expect(walletScreen, contains('_previewLedgerEntries'));
    expect(walletScreen, contains('_walletLedgerLabel(entry.reason)'));
    expect(walletScreen, isNot(contains("entry.reason.replaceAll('_', ' ')")));
    expect(walletScreen, contains('QrImageView'));
    expect(walletScreen, contains('_walletInviteQrData(summary)'));
    expect(walletScreen, contains("label: 'Invite QR code'"));
    expect(driverPlusScreen, contains('_previewDriverPlusWallet'));
    expect(driverPlusScreen, contains('_previewDriverPlusPlans'));
    expect(walletScreen, contains("title: 'Wallet unavailable'"));
    expect(driverPlusScreen, contains("title: 'Mobio Plus unavailable'"));
    expect(walletScreen, contains('MobiErrorState'));
    expect(driverPlusScreen, contains('MobiErrorState'));
    expect(walletScreen, contains('onRetry: refresh'));
    expect(walletScreen, contains('onRefresh: refresh'));
    expect(
      RegExp(
        r'Future<void>\s+refresh\(\)\s+async\s*\{\s*if\s*\(origin\.isCurrent\)\s*await\s+_load\(action:\s*origin\);',
      ).hasMatch(walletScreen),
      isTrue,
    );
    // Refresh uses the rendered account; retained A callbacks cannot read B.
    // Positive and replacement races use actual widgets in the profile suite.
    expect(driverPlusScreen, contains('onRetry: refresh'));
    expect(driverPlusScreen, contains('onRefresh: refresh'));
    expect(
      RegExp(
        r'Future<void>\s+refresh\(\)\s+async\s*\{\s*if\s*\(_current\(renderedAccount\)\)\s*await\s+_load\(\);',
      ).hasMatch(driverPlusScreen),
      isTrue,
    );
    expect(walletScreen, contains("retryLabel: 'Refresh'"));
    expect(driverPlusScreen, contains("retryLabel: 'Refresh'"));

    expect(mobiPageHeader, contains("semanticLabel: 'Back'"));
    expect(mobiPageHeader, contains('const BoxConstraints(minHeight: 56)'));
    // Large-text layout and back navigation are exercised by
    // accessibility_resilience_test, without requiring text to shrink.
    expect(mobiPageHeader, contains('decoration: TextDecoration.none'));
    expect(
      mobiPageHeader,
      contains('const BoxConstraints(minWidth: 48, minHeight: 48)'),
    );
    expect(tappableIconButton, contains('SystemMouseCursors.click'));
    expect(tappableIconButton, contains('Feedback.forTap(context)'));
    expect(tappableIconButton, contains('enabled: onTap != null'));
    expect(mobiButton, contains('TextAlign.center'));
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

  test('driver plan policy covers rentals others and moto allowances', () {
    final migration = File(driverPlanCapsMigrationPath).readAsStringSync();
    final enforcementMigration = File(
      driverVehiclePolicyMigrationPath,
    ).readAsStringSync();

    expect(migration, contains("('moto', true, 365, 1, 365, false, true)"));
    expect(migration, contains("('rentals', true, 30, 1, 30, false, true)"));
    expect(migration, contains("('private', true, 30, 1, 30, false, true)"));
    expect(migration, contains("'rentals'"));
    expect(migration, contains('15000'));
    expect(migration, contains('1000'));
    expect(migration, contains('free_credit_days'));
    expect(migration, contains('free_daily_request_limit'));
    expect(migration, contains('free_total_request_limit'));
    expect(migration, contains('30'));
    expect(
      enforcementMigration,
      contains('create trigger enforce_driver_vehicle_policy_before_insert'),
    );
    expect(
      enforcementMigration,
      contains('public._driver_vehicle_policy_status'),
    );
    expect(enforcementMigration, contains("v_vehicle_type = 'private'"));
    expect(enforcementMigration, contains("interval '30 days'"));
    expect(enforcementMigration, contains('v_day_used < 1'));
    expect(enforcementMigration, contains('v_total_used < 30'));
    expect(
      enforcementMigration,
      contains('Others include one free driver trip credit per day.'),
    );
    expect(enforcementMigration, contains("v_vehicle_type = 'rentals'"));
    expect(enforcementMigration, contains('rentals_daily_free_credit_used'));
    expect(
      enforcementMigration,
      contains('Rentals include one free driver trip credit per day.'),
    );
    expect(enforcementMigration, contains("v_vehicle_type = 'moto'"));
    expect(enforcementMigration, contains('v_day_used < 1'));
    expect(enforcementMigration, contains('v_total_used < 365'));
    expect(enforcementMigration, contains("interval '365 days'"));
    expect(enforcementMigration, contains('Moto Taxi includes one free'));
  });
}
