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

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    return WalletSummary(
      profileId: json['profile_id'] as String? ?? '',
      balanceTokens: (json['balance_tokens'] as num?)?.toInt() ?? 0,
      rwfEquivalent: (json['rwf_equivalent'] as num?)?.toInt() ?? 0,
      lifetimeEarnedTokens:
          (json['lifetime_earned_tokens'] as num?)?.toInt() ?? 0,
      lifetimeSentTokens: (json['lifetime_sent_tokens'] as num?)?.toInt() ?? 0,
      lifetimeReceivedTokens:
          (json['lifetime_received_tokens'] as num?)?.toInt() ?? 0,
      successfulReferrals: (json['successful_referrals'] as num?)?.toInt() ?? 0,
      referralCode: json['referral_code'] as String?,
      shareUrl: json['share_url'] as String?,
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

  factory TokenLedgerEntry.fromJson(Map<String, dynamic> json) {
    return TokenLedgerEntry(
      id: json['id'] as String? ?? '',
      direction: json['direction'] as String? ?? 'credit',
      amountTokens: (json['amount_tokens'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String? ?? '',
      note: json['note'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
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
      memberId: json['member_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Mobio member',
    );
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
      transferId: json['transfer_id'] as String? ?? '',
      status: json['status'] as String? ?? 'completed',
      senderLedgerEntryId: json['sender_ledger_entry_id'] as String?,
      receiverLedgerEntryId: json['receiver_ledger_entry_id'] as String?,
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
      redemptionId: json['redemption_id'] as String? ?? '',
      transferId: json['transfer_id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      adminMemberId: json['admin_member_id'] as String? ?? '',
      amountTokens: (json['amount_tokens'] as num?)?.toInt() ?? 0,
      amountRwf: (json['amount_rwf'] as num?)?.toInt() ?? 0,
      momoNumber: json['momo_number'] as String?,
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
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      shareUrl: json['share_url'] as String? ?? '',
      rewardTokens: (json['reward_tokens'] as num?)?.toInt() ?? 100,
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
      driverId: json['driver_id'] as String? ?? '',
      vehicleTypeId: json['vehicle_type_id'] as String? ?? 'cab',
      requiresPlus: json['requires_plus'] as bool? ?? true,
      isFreeForever: json['is_free_forever'] as bool? ?? false,
      hasActiveSubscription: json['has_active_subscription'] as bool? ?? false,
      canReceiveNewRequest: json['can_receive_new_request'] as bool? ?? false,
      canReply: json['can_reply'] as bool? ?? false,
      canReadMessages: json['can_read_messages'] as bool? ?? false,
      canShowWhatsapp: json['can_show_whatsapp'] as bool? ?? false,
      upgradeRequired: json['upgrade_required'] as bool? ?? true,
      usedToday: (json['used_today'] as num?)?.toInt() ?? 0,
      usedTotal: (json['used_total'] as num?)?.toInt() ?? 0,
      remainingToday: (json['remaining_today'] as num?)?.toInt() ?? 0,
      remainingTotal: (json['remaining_total'] as num?)?.toInt() ?? 0,
      trialEndsAt: DateTime.tryParse(json['trial_ends_at'] as String? ?? ''),
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
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      paymentMethod: json['payment_method'] as String? ?? 'momo_ussd',
      referenceCode: json['reference_code'] as String? ?? '',
      amountTokens: (json['amount_tokens'] as num?)?.toInt() ?? 0,
      amountRwf: (json['amount_rwf'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'RWF',
      momoPayCode: json['momo_pay_code'] as String? ?? '12345',
      ussdCode: json['ussd_code'] as String?,
      subscriptionId: json['subscription_id'] as String?,
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
    );
  }
}
