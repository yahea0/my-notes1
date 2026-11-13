import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/onyx_theme.dart';
import '../widgets/luxury_3d_glass.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  final bool manualPreview;

  const SplashScreen({super.key, this.manualPreview = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  Timer? _navTimer;
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    if (!widget.manualPreview) {
      _navTimer = Timer(const Duration(milliseconds: 3000), _goHome);
    }
  }

  void _goHome() {
    if (!mounted) return;
    _navTimer?.cancel();
    if (widget.manualPreview) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 520),
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = OnyxSettings.isDark;
    final pal = OnyxPalette.of(isDark);

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      body: OnyxBackdrop(
        palette: pal,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeController,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Onyx3DGlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        borderRadius: 99,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: pal.accent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: pal.accent.withOpacity(0.7),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ONYX 3D GLASS',
                              style: TextStyle(
                                color: pal.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Onyx3DGlassCard(
                        padding: const EdgeInsets.all(10),
                        borderRadius: 16,
                        onTap: () {
                          _navTimer?.cancel();
                          OnyxSettings.setIsDark(!isDark);
                        },
                        child: Icon(
                          isDark ? Icons.light_mode : Icons.dark_mode,
                          color: pal.textPrimary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const OnyxSculptedPrism3D(size: 235),
                  const SizedBox(height: 22),
                  Text(
                    'ملاحظاتي',
                    style: applyArabicFont(
                      'Cairo',
                      TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: pal.textPrimary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سجل أفكارك.. تنظم حياتك',
                    style: applyArabicFont(
                      'Cairo',
                      TextStyle(
                        fontSize: 16,
                        color: pal.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Onyx3DGlassCard(
                    enableShimmer: true,
                    isHighlighted: true,
                    borderRadius: 20,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _featureMini(pal, Icons.auto_awesome, 'زجاج 3D'),
                        _featureMini(pal, Icons.mic_none, 'تسجيل صوتي'),
                        _featureMini(pal, Icons.brush_outlined, 'رسم حر'),
                        _featureMini(pal, Icons.lock_outline, 'قفل سري'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: Onyx3DButton(
                      label: widget.manualPreview
                          ? 'العودة إلى التطبيق'
                          : 'دخول مساحة العمل',
                      icon: Icons.arrow_back,
                      onPressed: _goHome,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureMini(OnyxPalette pal, IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: pal.textPrimary),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: pal.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
