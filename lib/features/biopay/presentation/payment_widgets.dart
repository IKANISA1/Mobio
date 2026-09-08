import 'package:flutter/material.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery.dart';
import 'package:mobi_app/l10n/app_localizations.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

AppLocalizations paymentCopy(BuildContext context) =>
    AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));

const paymentProviders = <String, String>{
  'mtn_rw': 'MTN MoMo',
  'airtel_rw': 'Airtel Money',
  'bk_rw': 'Bank of Kigali',
  'bpr_rw': 'BPR Bank',
  'im_rw': 'I&M Bank',
  'access_rw': 'Access Bank',
  'equity_rw': 'Equity Bank',
};

class PaymentTaskScaffold extends StatelessWidget {
  const PaymentTaskScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.onBack,
    this.action,
    this.busy = false,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback onBack;
  final Widget? action;
  final bool busy;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        onPressed: onBack,
        tooltip: paymentCopy(context).bpBack,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.headlineLg.copyWith(fontSize: 24),
      ),
      toolbarHeight: MediaQuery.textScalerOf(context).scale(24) > 32
          ? (MediaQuery.textScalerOf(context).scale(24) * 2.4 + 16)
                .clamp(64, 160)
                .toDouble()
          : 64,
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          key: ValueKey(title),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (busy)
              Semantics(
                liveRegion: true,
                child: const LinearProgressIndicator(),
              ),
            ...children.expand((w) => [w, const SizedBox(height: 16)]),
          ],
        ),
      ),
    ),
    bottomNavigationBar: action == null
        ? null
        : Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SafeArea(
              minimum: const EdgeInsets.all(16),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 568),
                  child: action!,
                ),
              ),
            ),
          ),
  );
}

class PaymentPanel extends StatelessWidget {
  const PaymentPanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class PaymentAction extends StatelessWidget {
  const PaymentAction({
    super.key,
    required this.label,
    this.onPressed,
    this.secondary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  @override
  Widget build(BuildContext context) {
    const style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(double.infinity, 52)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      shape: WidgetStatePropertyAll(StadiumBorder()),
    );
    return secondary
        ? OutlinedButton(
            style: style,
            onPressed: onPressed,
            child: Text(label, textAlign: TextAlign.center),
          )
        : FilledButton(
            style: style,
            onPressed: onPressed,
            child: Text(label, textAlign: TextAlign.center),
          );
  }
}

class PaymentDetail extends StatelessWidget {
  const PaymentDetail(this.label, this.value, {super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}

String paymentFeeLabel(AppLocalizations l, PaymentFee fee) {
  if (fee.certainty == FeeCertainty.unknown || fee.francs == null) {
    return l.bpFeeUnknown;
  }
  final amount = '${fee.francs} RWF';
  final value = fee.certainty == FeeCertainty.capped
      ? '${l.bpFeeCap} $amount'
      : '${l.bpFee} $amount';
  return fee.allIn ? value : '$value · ${l.bpPartialFee}';
}

String paymentEvidenceLabel(AppLocalizations l, PaymentEvidence e) =>
    switch (e) {
      PaymentEvidence.draft => l.bpSaved,
      PaymentEvidence.prepared => l.bpPrepared,
      PaymentEvidence.handoffOpened => l.bpHandoff,
      PaymentEvidence.outcomeUnknown => l.bpOutcomeUnknown,
      PaymentEvidence.userReported => l.bpUserReported,
      PaymentEvidence.receiverAcknowledged => l.bpReceiverAcknowledged,
      PaymentEvidence.operatorReviewed => l.bpOperatorReviewed,
      PaymentEvidence.providerConfirmed => l.bpProviderConfirmed,
    };

String paymentKindLabel(AppLocalizations l, PaymentMethodKind kind) =>
    switch (kind) {
      PaymentMethodKind.mobileWallet => 'MoMo / Airtel Money',
      PaymentMethodKind.merchantCode => l.bpMerchant,
      PaymentMethodKind.bankAccount => l.bpBankAccount,
      PaymentMethodKind.bankAlias => l.bpBankAlias,
    };

class PaymentError extends StatelessWidget {
  const PaymentError(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: PaymentPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

String paymentSourceReason(AppLocalizations l, String reason) =>
    switch (reason) {
      'notSending' => l.bpSourceUnavailable,
      'missingSim' => l.bpMissingSim,
      'missingLogin' => l.bpMissingLogin,
      _ => l.bpNoOptions,
    };
