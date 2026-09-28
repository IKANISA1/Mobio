import 'package:flutter/material.dart';

class AuthStorageRecoveryView extends StatefulWidget {
  const AuthStorageRecoveryView({super.key, required this.canReset, required this.resetSavedLogin});
  final bool canReset;
  final Future<void> Function() resetSavedLogin;
  @override State<AuthStorageRecoveryView> createState() => _AuthStorageRecoveryViewState();
}
class _AuthStorageRecoveryViewState extends State<AuthStorageRecoveryView> {
  bool _busy = false;
  bool _reset = false;
  String? _error;
  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Reset saved login?'),
      content: const Text('Only login credentials saved on this device will be removed. Your account, wallet, messages and pending operations will not be deleted. You will need a new login code.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset saved login'))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      // Do not start a second reset on timeout. A native operation may still be
      // running, so this screen stays non-interactive until it actually returns.
      await widget.resetSavedLogin();
      if (mounted) setState(() { _reset = true; _busy = false; });
    } on Object {
      if (mounted) setState(() { _busy = false; _error = 'Unable to reset saved login. Unlock the device and restart Mobio, or contact support.'; });
    }
  }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child:
    SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_reset ? 'Saved login reset' : 'Mobio could not safely start', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Text(_reset ? 'Close and reopen Mobio, then request a new login code.' :
          'Check your connection, unlock the device and restart Mobio. If saved login cannot be read, reset it below. Other account data stays unchanged.', textAlign: TextAlign.center),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Semantics(liveRegion: true, child: Text(_error!))),
        if (widget.canReset && !_reset) Padding(padding: const EdgeInsets.only(top: 24), child:
          FilledButton(onPressed: _busy ? null : _confirmReset, child: Text(_busy ? 'Resetting saved login…' : 'Reset saved login'))),
      ]),
    )),
  )));
}
