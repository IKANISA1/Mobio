import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

class MobiOtpCodeField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String label;
  final bool hasError;

  const MobiOtpCodeField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.enabled,
    this.label = 'Verification code',
    this.hasError = false,
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
    final digits = value.replaceAll(RegExp(r'\D'), '');
    // A full autofill or clipboard code replaces all cells, including when
    // another cell has focus. Partial pastes start at the focused cell.
    final start = digits.length >= _digitCount ? 0 : index;
    if (digits.isEmpty) {
      _controllers[index].clear();
    } else {
      final count = digits.length.clamp(1, _digitCount - start);
      for (var offset = 0; offset < count; offset++) {
        _controllers[start + offset].value = TextEditingValue(
          text: digits[offset],
          selection: const TextSelection.collapsed(offset: 1),
        );
      }
      _focusNodes[(start + count).clamp(0, _digitCount - 1)].requestFocus();
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
          widget.label,
          style: AppTypography.labelSm.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Semantics(
          container: true,
          label: widget.hasError
              ? '${widget.label}, invalid code'
              : widget.label,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 6 * 48 + 5 * AppSpacing.xs
                  ? 6
                  : 3;
              final width =
                  (constraints.maxWidth - (columns - 1) * AppSpacing.xs) /
                  columns;
              return Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.sm,
                children: List.generate(_digitCount, (index) {
                  final isFocused = _focusNodes[index].hasFocus;
                  final isFilled = _controllers[index].text.isNotEmpty;

                  return SizedBox(
                    width: width,
                    child: Focus(
                      onKeyEvent: (_, event) => _handleKeyEvent(index, event),
                      child: AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 140),
                        height: 64,
                        decoration: BoxDecoration(
                          color: widget.hasError
                              ? cs.errorContainer
                              : ext.surfaceContainerLowest.withValues(
                                  alpha: 0.92,
                                ),
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          border: Border.all(
                            color: widget.hasError
                                ? cs.error
                                : isFocused
                                ? cs.primary
                                : isFilled
                                ? cs.onSurface.withValues(alpha: 0.42)
                                : Colors.transparent,
                          ),
                        ),
                        child: Semantics(
                          label: 'Digit ${index + 1} of $_digitCount',
                          child: Center(
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
                              maxLines: 1,
                              autofillHints: index == 0
                                  ? const [AutofillHints.oneTimeCode]
                                  : null,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(_digitCount),
                              ],
                              style: AppTypography.titleLg.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                filled: false,
                                counterText: '',
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                              ),
                              onChanged: (value) =>
                                  _handleDigitChanged(index, value),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}
