import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

class MobiOtpCodeField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String label;

  const MobiOtpCodeField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.enabled,
    this.label = 'Verification code',
  });

  @override
  State<MobiOtpCodeField> createState() => _MobiOtpCodeFieldState();
}

class _MobiOtpCodeFieldState extends State<MobiOtpCodeField> {
  static const _digitCount = 6;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_digitCount, (_) => TextEditingController());
    _focusNodes = List.generate(_digitCount, (_) => FocusNode());
    for (final node in _focusNodes) {
      node.addListener(_handleFocusChanged);
    }
    widget.controller.addListener(_syncFromExternalController);
    _syncFromExternalController();
  }

  @override
  void didUpdateWidget(covariant MobiOtpCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFromExternalController);
      widget.controller.addListener(_syncFromExternalController);
      _syncFromExternalController();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromExternalController);
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node
        ..removeListener(_handleFocusChanged)
        ..dispose();
    }
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _syncFromExternalController() {
    if (_syncing) return;

    final digits = widget.controller.text.replaceAll(RegExp(r'\D'), '');
    for (var i = 0; i < _digitCount; i += 1) {
      final value = i < digits.length ? digits[i] : '';
      if (_controllers[i].text != value) {
        _controllers[i].text = value;
      }
    }
  }

  void _publishCode() {
    final code = _controllers.map((controller) => controller.text).join();
    _syncing = true;
    widget.controller.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    _syncing = false;
    widget.onChanged(code);
  }

  void _setCode(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > _digitCount
        ? digits.substring(0, _digitCount)
        : digits;

    for (var i = 0; i < _digitCount; i += 1) {
      _controllers[i].text = i < limited.length ? limited[i] : '';
    }

    final focusIndex = limited.length >= _digitCount
        ? _digitCount - 1
        : limited.length;
    _focusNodes[focusIndex].requestFocus();
    _publishCode();
  }

  void _appendDigit(String digit) {
    if (!widget.enabled) return;
    final code = widget.controller.text.replaceAll(RegExp(r'\D'), '');
    if (code.length >= _digitCount) return;
    _setCode('$code$digit');
  }

  void _deleteDigit() {
    if (!widget.enabled) return;
    final code = widget.controller.text.replaceAll(RegExp(r'\D'), '');
    if (code.isEmpty) return;
    _setCode(code.substring(0, code.length - 1));
  }

  void _handleDigitChanged(int index, String value) {
    final digit = value.replaceAll(RegExp(r'\D'), '');
    if (digit != value) {
      _controllers[index].text = digit;
    }

    if (digit.isNotEmpty && index < _digitCount - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    _publishCode();
  }

  KeyEventResult _handleKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.backspace ||
        _controllers[index].text.isNotEmpty ||
        index == 0) {
      return KeyEventResult.ignored;
    }

    _controllers[index - 1].clear();
    _focusNodes[index - 1].requestFocus();
    _publishCode();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: AppTypography.labelSm.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Semantics(
          textField: true,
          label: widget.label,
          child: Row(
            children: List.generate(_digitCount, (index) {
              final isFocused = _focusNodes[index].hasFocus;
              final isFilled = _controllers[index].text.isNotEmpty;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == _digitCount - 1 ? 0 : AppSpacing.xs,
                  ),
                  child: Focus(
                    onKeyEvent: (_, event) => _handleKeyEvent(index, event),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      height: 64,
                      decoration: BoxDecoration(
                        color: ext.surfaceContainerLowest.withValues(
                          alpha: 0.92,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(
                          color: isFocused || isFilled
                              ? cs.onSurface.withValues(alpha: 0.42)
                              : Colors.transparent,
                        ),
                      ),
                      child: TextField(
                        key: ValueKey('mobi_otp_digit_$index'),
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        enabled: widget.enabled,
                        textAlign: TextAlign.center,
                        textAlignVertical: TextAlignVertical.center,
                        keyboardType: TextInputType.number,
                        textInputAction: index == _digitCount - 1
                            ? TextInputAction.done
                            : TextInputAction.next,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        maxLength: 1,
                        autofillHints: index == 0
                            ? const [AutofillHints.oneTimeCode]
                            : null,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(1),
                        ],
                        style: AppTypography.titleLg.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                        ),
                        onChanged: (value) => _handleDigitChanged(index, value),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _OtpNumberKeypad(
          enabled: widget.enabled,
          onDigit: _appendDigit,
          onBackspace: _deleteDigit,
        ),
      ],
    );
  }
}

class _OtpNumberKeypad extends StatelessWidget {
  const _OtpNumberKeypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'backspace'],
    ];

    return Column(
      children: [
        for (final row in rows) ...[
          Row(
            children: [
              for (final value in row)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _OtpKeypadButton(
                      value: value,
                      enabled: enabled,
                      onTap: value == 'backspace'
                          ? onBackspace
                          : value.isEmpty
                          ? null
                          : () => onDigit(value),
                    ),
                  ),
                ),
            ],
          ),
          if (row != rows.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _OtpKeypadButton extends StatelessWidget {
  const _OtpKeypadButton({
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final String value;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) {
      return const SizedBox(height: 48);
    }

    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final isBackspace = value == 'backspace';

    return SizedBox(
      height: 48,
      child: TextButton(
        onPressed: enabled ? onTap : null,
        style: TextButton.styleFrom(
          foregroundColor: cs.onSurface,
          disabledForegroundColor: cs.onSurfaceVariant.withValues(alpha: 0.36),
          backgroundColor: ext.surfaceContainerLow.withValues(alpha: 0.72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          padding: EdgeInsets.zero,
        ),
        child: isBackspace
            ? const Icon(Icons.backspace_outlined, size: 22)
            : Text(
                value,
                style: AppTypography.titleLg.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}
