import 'package:flutter/material.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_design_system/theme/app_colors.dart';

const bioPayBlue = AppColors.primary;
const bioPayNfcPurple = AppColors.secondaryDim;
const bioPayQrOrange = AppColors.warning;
const bioPayScanTeal = AppColors.tertiary;
const bioPayInk = Color(0xFF191C1F);
const bioPayMuted = Color(0xFF717173);
const bioPayCanvas = Color(0xFFF7F7F7);
const bioPayPanel = Color(0xFFF4F5F6);
const bioPayChrome = Color(0xFF000D19);
const bioPayDarkPanel = Color(0xFF161618);
const bioPayDarkPanelAlt = Color(0xFF222224);

ThemeData bioPayLightTheme(BuildContext context) {
  return Theme.of(context);
}

class BioPayLightCanvas extends StatelessWidget {
  const BioPayLightCanvas({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SoftGradient(child: child);
  }
}

class BioPayIconBox extends StatelessWidget {
  const BioPayIconBox({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    this.dimension = 48,
    this.iconSize = 24,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double dimension;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: dimension,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }
}
