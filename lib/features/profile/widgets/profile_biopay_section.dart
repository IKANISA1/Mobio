import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/biopay/models/biopay_handle.dart';
import 'package:mobi_app/models/country.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';

class ProfileBiopaySection extends StatelessWidget {
  const ProfileBiopaySection({
    super.key,
    required this.handleController,
    required this.handleType,
    required this.selectedCountry,
    required this.onHandleTypeChanged,
    required this.hintText,
  });

  final TextEditingController handleController;
  final BiopayHandleType handleType;
  final Country selectedCountry;
  final ValueChanged<BiopayHandleType> onHandleTypeChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MobiSectionHeader(
          title: 'BioPay',
          caption: selectedCountry.momoBrand.isNotEmpty
              ? selectedCountry.momoBrand
              : 'Handle',
          icon: LucideIcons.creditCard,
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: ext.surfaceContainerLow,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: _buildHandleSelector(context, cs, ext),
              ),
              const SizedBox(height: 18),
              _buildHandleInput(cs, ext),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHandleSelector(
    BuildContext context,
    ColorScheme cs,
    MobiThemeExtension ext,
  ) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: ext.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: BiopayHandleType.values.map((type) {
          final isActive = handleType == type;
          return _TappableSelector(
            onTap: () => onHandleTypeChanged(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? cs.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                type.label,
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHandleInput(ColorScheme cs, MobiThemeExtension ext) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: cs.primary, width: 2),
      ),
      child: TextField(
        controller: handleController,
        keyboardType: handleType == BiopayHandleType.number
            ? TextInputType.phone
            : TextInputType.text,
        textCapitalization: handleType == BiopayHandleType.code
            ? TextCapitalization.characters
            : TextCapitalization.none,
        style: AppTypography.titleMd.copyWith(
          letterSpacing: -0.4,
          color: cs.onSurface,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTypography.titleMd.copyWith(
            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _TappableSelector extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _TappableSelector({required this.onTap, required this.child});

  @override
  State<_TappableSelector> createState() => _TappableSelectorState();
}

class _TappableSelectorState extends State<_TappableSelector> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: _pressed ? 0.8 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: widget.child,
        ),
      ),
    );
  }
}
