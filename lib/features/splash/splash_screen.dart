import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Premium claymorphism splash screen with:
/// - Soft green gradient background
/// - Clay-style logo card with depth shadows
/// - Smooth light gradient overlay
/// - Subtle breathing animation
class MobiSplashScreen extends StatefulWidget {
  const MobiSplashScreen({super.key});

  @override
  State<MobiSplashScreen> createState() => _MobiSplashScreenState();
}

class _MobiSplashScreenState extends State<MobiSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breatheController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // ── Soft green gradient — light at top-left, deeper at bottom-right ──
          gradient: LinearGradient(
            begin: Alignment(-0.8, -0.6),
            end: Alignment(0.8, 0.9),
            colors: [
              Color(0xFF00913D), // lighter vibrant green
              Color(0xFF006D2F), // primary green
              Color(0xFF004A1E), // deep dark green
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // ── Soft radial light overlay (claymorphism ambient glow) ──
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.4),
                    radius: 1.2,
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),

            // ── Subtle floating orb (soft warm light) ──
            Positioned(
              top: MediaQuery.of(context).size.height * 0.15,
              right: MediaQuery.of(context).size.width * 0.1,
              child: AnimatedBuilder(
                animation: _breatheController,
                builder: (context, child) {
                  final t = _breatheController.value;
                  final scale = 1.0 + 0.15 * math.sin(t * math.pi);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.08),
                            Colors.white.withValues(alpha: 0.02),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Center content: Clay logo card ──
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Clay card with logo ──
                  _buildClayLogoCard(),
                  const SizedBox(height: 32),

                  // ── Brand name ──
                  Text(
                        'Mobio',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.95),
                          letterSpacing: 2.0,
                          shadows: [
                            Shadow(
                              color: const Color(
                                0xFF004A1E,
                              ).withValues(alpha: 0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(
                        delay: 600.ms,
                        duration: 800.ms,
                        curve: Curves.easeOut,
                      )
                      .slideY(begin: 0.15, end: 0, duration: 800.ms),

                  const SizedBox(height: 10),

                  // ── Tagline ──
                  Text(
                        'Move with trust',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.6),
                          letterSpacing: 1.5,
                        ),
                      )
                      .animate()
                      .fadeIn(
                        delay: 1000.ms,
                        duration: 800.ms,
                        curve: Curves.easeOut,
                      )
                      .slideY(begin: 0.2, end: 0, duration: 800.ms),

                  const SizedBox(height: 60),

                  // ── Loading indicator ──
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ).animate().fadeIn(delay: 1200.ms, duration: 600.ms),
                ],
              ),
            ),

            // ── Bottom: subtle copyright ──
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 24,
              child: Text(
                '© ${DateTime.now().year} Mobio',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.3),
                  letterSpacing: 0.8,
                ),
              ).animate().fadeIn(delay: 1400.ms, duration: 600.ms),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a claymorphism-styled logo card with:
  /// - Soft inner highlight gradient (top-left light)
  /// - Dual shadow (light above, dark below) for clay depth
  /// - Smooth rounded corners
  /// - Subtle border highlight
  Widget _buildClayLogoCard() {
    return AnimatedBuilder(
          animation: _breatheController,
          builder: (context, child) {
            final t = _breatheController.value;
            final scale = 1.0 + 0.02 * math.sin(t * math.pi);
            final shadowExtra = 4.0 * math.sin(t * math.pi);

            return Transform.scale(
              scale: scale,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(36),
                  // ── Clay surface gradient: lighter top-left → darker bottom-right ──
                  gradient: const LinearGradient(
                    begin: Alignment(-1, -1),
                    end: Alignment(1, 1),
                    colors: [
                      Color(0xFF009944), // light clay surface
                      Color(0xFF007A35), // mid
                      Color(0xFF005E28), // deep shadow
                    ],
                  ),
                  // ── Clay border: subtle light rim ──
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.2,
                  ),
                  // ── Dual shadow for clay depth ──
                  boxShadow: [
                    // Light highlight (pressed-in clay feel)
                    BoxShadow(
                      color: const Color(0xFF00B84D).withValues(alpha: 0.35),
                      blurRadius: 16 + shadowExtra,
                      offset: const Offset(-4, -4),
                    ),
                    // Deep shadow (depth)
                    BoxShadow(
                      color: const Color(0xFF003316).withValues(alpha: 0.6),
                      blurRadius: 20 + shadowExtra,
                      offset: const Offset(6, 8),
                    ),
                    // Soft ambient glow
                    BoxShadow(
                      color: const Color(0xFF00FF6A).withValues(alpha: 0.08),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // ── Inner highlight overlay (glass-on-clay) ──
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(36),
                          gradient: LinearGradient(
                            begin: const Alignment(-1, -1),
                            end: const Alignment(0.5, 0.5),
                            colors: [
                              Colors.white.withValues(alpha: 0.18),
                              Colors.white.withValues(alpha: 0.04),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.35, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // ── Logo ──
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Image.asset(
                        'icon/mobi_logo_transparent.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        )
        .animate()
        .fadeIn(duration: 800.ms, curve: Curves.easeOut)
        .scaleXY(
          begin: 0.7,
          end: 1.0,
          duration: 800.ms,
          curve: Curves.easeOutBack,
        );
  }
}
