import 'package:flutter/material.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';

const bioPayBlue = Color(0xFF006DFF);
const bioPayNfcPurple = Color(0xFF6D4CFF);
const bioPayQrOrange = Color(0xFFFF9800);
const bioPayScanTeal = Color(0xFF14B8A6);
const bioPayInk = Color(0xFF101828);
const bioPayMuted = Color(0xFF667085);
const bioPayCanvas = Color(0xFFFBFCFF);
const bioPayPanel = Color(0xFFF5F7FA);
const bioPayChrome = Color(0xFF050815);
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
