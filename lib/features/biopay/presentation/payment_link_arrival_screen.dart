import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/utils/navigation_utils.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/domain/payment_entry.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PaymentLinkArrivalScreen extends ConsumerStatefulWidget {
  const PaymentLinkArrivalScreen({super.key, required this.token});
  final String token;
  @override
  ConsumerState<PaymentLinkArrivalScreen> createState() =>
      _PaymentLinkArrivalScreenState();
}

class _PaymentLinkArrivalScreenState
    extends ConsumerState<PaymentLinkArrivalScreen> {
  Map<String, dynamic>? _preview;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final preview = await ref
          .read(paymentDiscoveryServiceProvider)
          .previewLink(widget.token);
      if (mounted) setState(() => _preview = preview);
    } on Object {
      if (mounted) setState(() => _preview = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = paymentCopy(context);
    final service = ref.read(paymentDiscoveryServiceProvider);
    final available = _preview?['available'] == true;
    return PaymentTaskScaffold(
      title: l.bpRequests,
      busy: _loading,
      onBack: () => safePop(context, fallback: '/biopay'),
      action: !available
          ? null
          : PaymentAction(
              label: service.ownerId == null ? l.bpSignIn : l.bpContinue,
              onPressed: () {
                final next = Uri(
                  path: '/biopay/send',
                  queryParameters: {
                    'entry': bioPayShareUri(widget.token).toString(),
                  },
                ).toString();
                if (service.ownerId == null) {
                  context.go(
                    Uri(
                      path: '/login',
                      queryParameters: {'redirect': next},
                    ).toString(),
                  );
                } else {
                  // Navigation deliberately selects BioPay before pushing its task.
                  unawaited((GoRouter.of(context)..go('/biopay')).push(next));
                }
              },
            ),
      children: [
        if (!_loading && !available) ...[
          PaymentError(l.bpLinkUnavailable),
          PaymentAction(
            label: l.bpManual,
            onPressed: () => context.go('/biopay/send'),
            secondary: true,
          ),
        ],
        if (available) ...[
          Text(
            _preview!['label'] as String,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            _preview!['amount_rwf'] == null
                ? l.bpAnyAmount
                : '${_preview!['amount_rwf']} RWF',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          Text(l.bpExternalOnly),
          if (service.deviceFamily == 'web' ||
              service.deviceFamily == 'desktop') ...[
            Text(l.bpUsePhone),
            Center(
              child: Semantics(
                label: l.bpRequestScope,
                child: QrImageView(
                  data: bioPayShareUri(widget.token).toString(),
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            PaymentAction(
              label: l.bpCopy,
              secondary: true,
              onPressed: () => Clipboard.setData(
                ClipboardData(text: bioPayShareUri(widget.token).toString()),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
