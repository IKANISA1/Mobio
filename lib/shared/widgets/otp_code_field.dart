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
      ],
    );
  }
}
