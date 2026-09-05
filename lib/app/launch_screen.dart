import 'package:flutter/material.dart';
import 'package:mobi_app/shared/widgets/mobi_brand_mark.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

/// ONB-00's quiet launch composition adapted to Mobio's own mark and name.
/// Light is observed; the black dark counterpart is a target adaptation.
class MobiLaunchScreen extends StatelessWidget {
  const MobiLaunchScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.white,
      body: SafeArea(
        child: Center(
          child: Semantics(
            label: 'Mobio is loading',
            liveRegion: true,
            child: ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MobiBrandMark(),
                    Text(
                      'Mobio',
                      style: AppTypography.displayLg.copyWith(
                        fontSize: 48,
                        fontWeight: FontWeight.w600,
                        color: dark ? Colors.white : const Color(0xFF191C1F),
                      ),
                    ),
                    const SizedBox(width: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MobiLaunchApp extends StatelessWidget {
  const MobiLaunchApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mobio',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: ThemeMode.system,
    home: const MobiLaunchScreen(),
  );
}
