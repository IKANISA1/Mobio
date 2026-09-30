import 'package:flutter/material.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_design_system/theme/app_colors.dart';

const bioPayBlue = AppColors.primary;
const bioPayNfcPurple = AppColors.secondaryDim;
const bioPayQrOrange = AppColors.warning;
const bioPayScanTeal = AppColors.tertiary;

ThemeData bioPayReferenceTheme(BuildContext context) {
  return Theme.of(context);
}

class BioPayTaskCanvas extends StatelessWidget {
  const BioPayTaskCanvas({super.key, required this.child});

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
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }
}
