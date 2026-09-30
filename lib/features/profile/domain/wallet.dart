/// Exact backend fields used by wallet and subscription workflows.
/// Required amounts and state never inherit display defaults.
abstract final class WalletWireRecord {
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
  );
  static final _memberId = RegExp(r'^[0-9]{6}$');
  static const _maximumInteger = 9007199254740991;

  static Map<String, dynamic> object(Object? value) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw const FormatException('Invalid wallet RPC object');
    }
    return Map<String, dynamic>.from(value);
  }

  static List<Map<String, dynamic>> rows(Object? value) {
    if (value is! List) throw const FormatException('Invalid wallet RPC list');
    return value.map(object).toList(growable: false);
  }

  static String text(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid wallet field: $key');
    }
    return value;
  }

  static String id(Map<String, dynamic> row, String key) {
    final value = text(row, key);
    if (!_uuid.hasMatch(value)) {
      throw FormatException('Invalid wallet ID: $key');
    }
    return value;
  }

  static String memberId(Map<String, dynamic> row, String key) {
    final value = text(row, key);
    if (!_memberId.hasMatch(value)) {
      throw FormatException('Invalid member ID: $key');
    }
    return value;
  }

  static String? optionalText(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('Invalid wallet field: $key');
    return value;
  }

  static String? optionalId(Map<String, dynamic> row, String key) {
    if (row[key] == null) return null;
    return id(row, key);
  }

  static int integer(Map<String, dynamic> row, String key, {int minimum = 0}) {
    final value = row[key];
    if (value is! int || value < minimum || value > _maximumInteger) {
      throw FormatException('Invalid wallet integer: $key');
    }
    return value;
  }

  static String state(
    Map<String, dynamic> row,
    String key,
    Set<String> values,
  ) {
    final value = text(row, key);
    if (!values.contains(value)) {
      throw FormatException('Invalid wallet state: $key');
    }
    return value;
  }

  static bool flag(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! bool) throw FormatException('Invalid wallet flag: $key');
    return value;
  }

  static DateTime date(Map<String, dynamic> row, String key) {
    final value = text(row, key);
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('Invalid wallet date: $key');
    return parsed;
  }

  static DateTime? optionalDate(Map<String, dynamic> row, String key) {
    if (row[key] == null) return null;
    return date(row, key);
  }
}

class WalletSummary {
  const WalletSummary({
    required this.profileId,
    required this.balanceTokens,
    required this.rwfEquivalent,
    required this.lifetimeEarnedTokens,
    required this.lifetimeSentTokens,
    required this.lifetimeReceivedTokens,
    required this.successfulReferrals,
    this.referralCode,
    this.shareUrl,
  });

  final String profileId;
  final int balanceTokens;
  final int rwfEquivalent;
  final int lifetimeEarnedTokens;
  final int lifetimeSentTokens;
  final int lifetimeReceivedTokens;
  final int successfulReferrals;
  final String? referralCode;
  final String? shareUrl;

  factory WalletSummary.fromJson(
    Map<String, dynamic> json, {
    String? expectedProfileId,
  }) {
    final profileId = WalletWireRecord.id(json, 'profile_id');
    if (expectedProfileId != null && profileId != expectedProfileId) {
      throw const FormatException('Wallet summary owner mismatch');
    }
    return WalletSummary(
      profileId: profileId,
      balanceTokens: WalletWireRecord.integer(json, 'balance_tokens'),
      rwfEquivalent: WalletWireRecord.integer(json, 'rwf_equivalent'),
      lifetimeEarnedTokens: WalletWireRecord.integer(
        json,
        'lifetime_earned_tokens',
      ),
      lifetimeSentTokens: WalletWireRecord.integer(
        json,
        'lifetime_sent_tokens',
      ),
      lifetimeReceivedTokens: WalletWireRecord.integer(
        json,
        'lifetime_received_tokens',
      ),
      successfulReferrals: WalletWireRecord.integer(
        json,
        'successful_referrals',
      ),
      referralCode: WalletWireRecord.optionalText(json, 'referral_code'),
      shareUrl: WalletWireRecord.optionalText(json, 'share_url'),
    );
  }
}

class TokenLedgerEntry {
  const TokenLedgerEntry({
    required this.id,
    required this.direction,
    required this.amountTokens,
    required this.reason,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String direction;
  final int amountTokens;
  final String reason;
  final DateTime createdAt;
  final String? note;

  factory TokenLedgerEntry.fromJson(
    Map<String, dynamic> json, {
    String? expectedProfileId,
  }) {
    if (expectedProfileId != null &&
        WalletWireRecord.id(json, 'profile_id') != expectedProfileId) {
      throw const FormatException('Wallet ledger owner mismatch');
    }
    return TokenLedgerEntry(
      id: WalletWireRecord.id(json, 'id'),
      direction: WalletWireRecord.state(json, 'direction', {'credit', 'debit'}),
      amountTokens: WalletWireRecord.integer(json, 'amount_tokens', minimum: 1),
      reason: WalletWireRecord.text(json, 'reason'),
      note: WalletWireRecord.optionalText(json, 'note'),
      createdAt: WalletWireRecord.date(json, 'created_at'),
    );
  }
}

class WalletTransferRecipient {
  const WalletTransferRecipient({
    required this.memberId,
    required this.displayName,
  });

  final String memberId;
  final String displayName;

  factory WalletTransferRecipient.fromJson(Map<String, dynamic> json) {
    return WalletTransferRecipient(
      memberId: WalletWireRecord.memberId(json, 'member_id'),
      displayName: WalletWireRecord.text(json, 'display_name'),
    );
  }

  factory WalletTransferRecipient.fromLookupJson(
    Map<String, dynamic> json, {
    required String requestedMemberId,
  }) {
    if (!RegExp(r'^[0-9]{6}$').hasMatch(requestedMemberId)) {
      throw StateError('INVALID_MEMBER_ID');
    }
    if (json['member_id'] != requestedMemberId) {
      throw StateError('RECIPIENT_ID_MISMATCH');
    }
    return WalletTransferRecipient.fromJson(json);
  }
}

class WalletTransferReceipt {
  const WalletTransferReceipt({
    required this.transferId,
    required this.status,
    this.senderLedgerEntryId,
    this.receiverLedgerEntryId,
  });

  final String transferId;
  final String status;
  final String? senderLedgerEntryId;
  final String? receiverLedgerEntryId;

  factory WalletTransferReceipt.fromJson(Map<String, dynamic> json) {
    return WalletTransferReceipt(
      transferId: WalletWireRecord.id(json, 'transfer_id'),
      status: WalletWireRecord.state(json, 'status', {'completed', 'reversed'}),
      senderLedgerEntryId: WalletWireRecord.optionalId(
        json,
        'sender_ledger_entry_id',
      ),
      receiverLedgerEntryId: WalletWireRecord.optionalId(
        json,
        'receiver_ledger_entry_id',
      ),
    );
  }
}

class WalletRedemptionReceipt {
  const WalletRedemptionReceipt({
    required this.redemptionId,
    required this.transferId,
    required this.status,
    required this.adminMemberId,
    required this.amountTokens,
    required this.amountRwf,
    this.momoNumber,
  });

  final String redemptionId;
  final String transferId;
  final String status;
  final String adminMemberId;
  final int amountTokens;
  final int amountRwf;
  final String? momoNumber;

  factory WalletRedemptionReceipt.fromJson(Map<String, dynamic> json) {
    return WalletRedemptionReceipt(
      redemptionId: WalletWireRecord.id(json, 'redemption_id'),
      transferId: WalletWireRecord.id(json, 'transfer_id'),
      status: WalletWireRecord.state(json, 'status', {
        'pending',
        'cash_sent',
        'cancelled',
        'failed',
      }),
      adminMemberId: WalletWireRecord.memberId(json, 'admin_member_id'),
      amountTokens: WalletWireRecord.integer(json, 'amount_tokens', minimum: 1),
      amountRwf: WalletWireRecord.integer(json, 'amount_rwf', minimum: 1),
      momoNumber: WalletWireRecord.optionalText(json, 'momo_number'),
    );
  }
}

class ReferralCode {
  const ReferralCode({
    required this.id,
    required this.code,
    required this.shareUrl,
    required this.rewardTokens,
  });

  final String id;
  final String code;
  final String shareUrl;
  final int rewardTokens;

  factory ReferralCode.fromJson(Map<String, dynamic> json) {
    return ReferralCode(
      id: WalletWireRecord.id(json, 'id'),
      code: WalletWireRecord.text(json, 'code'),
      shareUrl: WalletWireRecord.text(json, 'share_url'),
      rewardTokens: WalletWireRecord.integer(json, 'reward_tokens'),
    );
  }
}

class DriverPlusStatus {
  const DriverPlusStatus({
    required this.driverId,
    required this.vehicleTypeId,
    required this.requiresPlus,
    required this.isFreeForever,
    required this.hasActiveSubscription,
    required this.canReceiveNewRequest,
    required this.canReply,
    required this.canReadMessages,
    required this.canShowWhatsapp,
    required this.upgradeRequired,
    required this.usedToday,
    required this.usedTotal,
    required this.remainingToday,
    required this.remainingTotal,
    this.trialEndsAt,
  });

  final String driverId;
  final String vehicleTypeId;
  final bool requiresPlus;
  final bool isFreeForever;
  final bool hasActiveSubscription;
  final bool canReceiveNewRequest;
  final bool canReply;
  final bool canReadMessages;
  final bool canShowWhatsapp;
  final bool upgradeRequired;
  final int usedToday;
  final int usedTotal;
  final int remainingToday;
  final int remainingTotal;
  final DateTime? trialEndsAt;

  factory DriverPlusStatus.fromJson(Map<String, dynamic> json) {
    return DriverPlusStatus(
      driverId: WalletWireRecord.id(json, 'driver_id'),
      vehicleTypeId: WalletWireRecord.text(json, 'vehicle_type_id'),
      requiresPlus: WalletWireRecord.flag(json, 'requires_plus'),
      isFreeForever: WalletWireRecord.flag(json, 'is_free_forever'),
      hasActiveSubscription: WalletWireRecord.flag(
        json,
        'has_active_subscription',
      ),
      canReceiveNewRequest: WalletWireRecord.flag(
        json,
        'can_receive_new_request',
      ),
      canReply: WalletWireRecord.flag(json, 'can_reply'),
      canReadMessages: WalletWireRecord.flag(json, 'can_read_messages'),
      canShowWhatsapp: WalletWireRecord.flag(json, 'can_show_whatsapp'),
      upgradeRequired: WalletWireRecord.flag(json, 'upgrade_required'),
      usedToday: WalletWireRecord.integer(json, 'used_today'),
      usedTotal: WalletWireRecord.integer(json, 'used_total'),
      remainingToday: WalletWireRecord.integer(json, 'remaining_today'),
      remainingTotal: WalletWireRecord.integer(json, 'remaining_total'),
      trialEndsAt: WalletWireRecord.optionalDate(json, 'trial_ends_at'),
    );
  }
}

class DriverSubscriptionPaymentRequest {
  const DriverSubscriptionPaymentRequest({
    required this.id,
    required this.status,
    required this.paymentMethod,
    required this.referenceCode,
    required this.amountTokens,
    required this.amountRwf,
    required this.currency,
    required this.momoPayCode,
    this.ussdCode,
    this.subscriptionId,
    this.expiresAt,
  });

  final String id;
  final String status;
  final String paymentMethod;
  final String referenceCode;
  final int amountTokens;
  final int amountRwf;
  final String currency;
  final String momoPayCode;
  final String? ussdCode;
  final String? subscriptionId;
  final DateTime? expiresAt;

  factory DriverSubscriptionPaymentRequest.fromJson(Map<String, dynamic> json) {
    return DriverSubscriptionPaymentRequest(
      id: WalletWireRecord.id(json, 'id'),
      status: WalletWireRecord.state(json, 'status', {
        'pending',
        'dialer_opened',
        'confirmed',
        'failed',
        'expired',
        'cancelled',
      }),
      paymentMethod: WalletWireRecord.state(json, 'payment_method', {
        'tokens',
        'momo_ussd',
      }),
      referenceCode: WalletWireRecord.text(json, 'reference_code'),
      amountTokens: WalletWireRecord.integer(json, 'amount_tokens', minimum: 1),
      amountRwf: WalletWireRecord.integer(json, 'amount_rwf', minimum: 1),
      currency: WalletWireRecord.text(json, 'currency'),
      momoPayCode: WalletWireRecord.text(json, 'momo_pay_code'),
      ussdCode: WalletWireRecord.optionalText(json, 'ussd_code'),
      subscriptionId: WalletWireRecord.optionalId(json, 'subscription_id'),
      expiresAt: WalletWireRecord.date(json, 'expires_at'),
    );
  }
}
