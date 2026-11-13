import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/onyx_theme.dart';

class OnyxBackdrop extends StatelessWidget {
  final Widget child;
  final OnyxPalette palette;

  const OnyxBackdrop({
    super.key,
    required this.child,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.7),
                radius: 1.4,
                colors: palette.isDark
                    ? [
                        const Color(0xFF1B1C22),
                        const Color(0xFF0A0A0D),
                        const Color(0xFF040406),
                      ]
                    : [
                        Colors.white,
                        const Color(0xFFF3F4F8),
                        const Color(0xFFE7E9F0),
                      ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _BackdropGeometryPainter(palette: palette),
          ),
        ),
        child,
      ],
    );
  }
}

class _BackdropGeometryPainter extends CustomPainter {
  final OnyxPalette palette;
  const _BackdropGeometryPainter({required this.palette});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = (palette.isDark ? Colors.white : Colors.black).withOpacity(0.035)
      ..strokeWidth = 0.8;
    const step = 46.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    _draw3DOrb(
      canvas,
      Offset(size.width * 0.86, size.height * 0.16),
      68,
      palette.isDark,
    );
    _draw3DOrb(
      canvas,
      Offset(size.width * 0.12, size.height * 0.78),
      54,
      palette.isDark,
    );
  }

  void _draw3DOrb(Canvas canvas, Offset center, double radius, bool isDark) {
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(isDark ? 0.45 : 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawCircle(center.translate(0, 14), radius * 0.92, shadowPaint);

    final orbPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.38, -0.42),
        radius: 1.0,
        colors: isDark
            ? [
                Colors.white.withOpacity(0.24),
                Colors.white.withOpacity(0.06),
                Colors.black.withOpacity(0.45),
              ]
            : [
                Colors.white,
                const Color(0xFFDCDFE8),
                const Color(0xFFBFC4D0),
              ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, orbPaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(isDark ? 0.45 : 0.95),
          (isDark ? Colors.white : Colors.black).withOpacity(0.08),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _BackdropGeometryPainter oldDelegate) =>
      oldDelegate.palette.isDark != palette.isDark;
}

class Onyx3DGlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enableShimmer;
  final bool isHighlighted;

  const Onyx3DGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 22,
    this.onTap,
    this.onLongPress,
    this.enableShimmer = false,
    this.isHighlighted = false,
  });

  @override
  State<Onyx3DGlassCard> createState() => _Onyx3DGlassCardState();
}

class _Onyx3DGlassCardState extends State<Onyx3DGlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    if (widget.enableShimmer && OnyxSettings.enableShimmer) {
      _shimmerController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant Onyx3DGlassCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldAnimate = widget.enableShimmer && OnyxSettings.enableShimmer;
    if (shouldAnimate && !_shimmerController.isAnimating) {
      _shimmerController.repeat();
    } else if (!shouldAnimate && _shimmerController.isAnimating) {
      _shimmerController.stop();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = OnyxPalette.of(OnyxSettings.isDark);
    final enable3D = OnyxSettings.enable3D;
    final blur = OnyxSettings.blurSigma;
    final radius = BorderRadius.circular(widget.borderRadius);

    Widget content = AnimatedScale(
      scale: _pressed ? 0.982 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: widget.margin,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: enable3D
              ? [
                  BoxShadow(
                    color: pal.shadowDeep,
                    blurRadius: widget.isHighlighted ? 26 : 18,
                    offset: const Offset(0, 10),
                    spreadRadius: -3,
                  ),
                  if (pal.isDark)
                    BoxShadow(
                      color: Colors.white.withOpacity(
                        widget.isHighlighted ? 0.08 : 0.03,
                      ),
                      blurRadius: 1,
                      offset: const Offset(0, -1),
                    )
                  else
                    BoxShadow(
                      color: Colors.white.withOpacity(0.9),
                      blurRadius: 12,
                      offset: const Offset(-2, -3),
                    ),
                ]
              : [
                  BoxShadow(
                    color: pal.shadowDeep.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: CustomPaint(
              painter: _Glass3DBevelPainter(
                borderRadius: widget.borderRadius,
                palette: pal,
                isHighlighted: widget.isHighlighted,
                enable3D: enable3D,
              ),
              child: Stack(
                children: [
                  Container(
                    padding: widget.padding ?? const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          pal.cardTop,
                          pal.cardBottom,
                        ],
                      ),
                    ),
                    child: widget.child,
                  ),
                  if (widget.enableShimmer && OnyxSettings.enableShimmer)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, _) {
                            final t = _shimmerController.value;
                            final dx = -1.6 + (t * 3.2);
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: radius,
                                gradient: LinearGradient(
                                  begin: Alignment(dx - 0.5, -1),
                                  end: Alignment(dx + 0.5, 1),
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withOpacity(
                                      pal.isDark ? 0.09 : 0.45,
                                    ),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.onTap == null && widget.onLongPress == null) {
      return content;
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: content,
    );
  }
}

class _Glass3DBevelPainter extends CustomPainter {
  final double borderRadius;
  final OnyxPalette palette;
  final bool isHighlighted;
  final bool enable3D;

  const _Glass3DBevelPainter({
    required this.borderRadius,
    required this.palette,
    required this.isHighlighted,
    required this.enable3D,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect =
        RRect.fromRectAndRadius(rect.deflate(0.6), Radius.circular(borderRadius));

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHighlighted ? 1.5 : 1.05
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          palette.isDark
              ? Colors.white.withOpacity(isHighlighted ? 0.55 : 0.34)
              : Colors.white,
          palette.glassBorder,
          palette.isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.14),
        ],
      ).createShader(rect);

    canvas.drawRRect(rrect, borderPaint);

    if (enable3D) {
      final topShine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            palette.glassHighlight,
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, 4));
      canvas.drawLine(
        Offset(borderRadius, 1.3),
        Offset(size.width - borderRadius, 1.3),
        topShine,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Glass3DBevelPainter oldDelegate) =>
      oldDelegate.palette.isDark != palette.isDark ||
      oldDelegate.isHighlighted != isHighlighted ||
      oldDelegate.enable3D != enable3D;
}

class OnyxSculptedPrism3D extends StatefulWidget {
  final double size;
  final bool interactiveTilt;

  const OnyxSculptedPrism3D({
    super.key,
    this.size = 220,
    this.interactiveTilt = true,
  });

  @override
  State<OnyxSculptedPrism3D> createState() => _OnyxSculptedPrism3DState();
}

class _OnyxSculptedPrism3DState extends State<OnyxSculptedPrism3D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _tiltX = 0;
  double _tiltY = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = OnyxPalette.of(OnyxSettings.isDark);

    return GestureDetector(
      onPanUpdate: widget.interactiveTilt
          ? (details) {
              setState(() {
                _tiltY = (_tiltY + details.delta.dx * 0.006).clamp(-0.35, 0.35);
                _tiltX = (_tiltX - details.delta.dy * 0.006).clamp(-0.35, 0.35);
              });
            }
          : null,
      onPanEnd: widget.interactiveTilt
          ? (_) => setState(() {
                _tiltX = 0;
                _tiltY = 0;
              })
          : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final phase = _controller.value;
          final floatY = math.sin(phase * math.pi * 2) * 7.0;
          final autoTilt = math.sin(phase * math.pi * 2) * 0.05;

          return Transform.translate(
            offset: Offset(0, floatY),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0014)
                ..rotateX(_tiltX + autoTilt * 0.5)
                ..rotateY(_tiltY + autoTilt),
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _SculptedPrismPainter(
                    phase: phase,
                    isDark: pal.isDark,
                    enableShimmer: OnyxSettings.enableShimmer,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SculptedPrismPainter extends CustomPainter {
  final double phase;
  final bool isDark;
  final bool enableShimmer;

  const _SculptedPrismPainter({
    required this.phase,
    required this.isDark,
    required this.enableShimmer,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.48;
    final cy = h * 0.50;

    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.16 : 0.09),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: w * 0.48));
    canvas.drawCircle(Offset(cx, cy), w * 0.48, haloPaint);

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(isDark ? 0.65 : 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.89),
        width: w * 0.56,
        height: h * 0.10,
      ),
      shadowPaint,
    );

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-0.35);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Colors.white.withOpacity(0.40),
                Colors.white.withOpacity(0.05),
                Colors.white.withOpacity(0.25),
              ]
            : [
                Colors.white,
                Colors.black.withOpacity(0.18),
                Colors.white,
              ],
      ).createShader(Rect.fromCenter(center: Offset.zero, width: w * 0.72, height: h * 0.34));
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * 0.72, height: h * 0.32),
      ringPaint,
    );
    canvas.restore();

    final topPoint = Offset(cx, h * 0.14);
    final midCenter = Offset(cx, h * 0.46);
    final leftTop = Offset(w * 0.20, h * 0.29);
    final rightTop = Offset(w * 0.76, h * 0.29);
    final leftBottom = Offset(w * 0.20, h * 0.68);
    final rightBottom = Offset(w * 0.76, h * 0.68);
    final bottomPoint = Offset(cx, h * 0.83);

    final topFace = Path()
      ..moveTo(topPoint.dx, topPoint.dy)
      ..lineTo(rightTop.dx, rightTop.dy)
      ..lineTo(midCenter.dx, midCenter.dy)
      ..lineTo(leftTop.dx, leftTop.dy)
      ..close();

    final leftFace = Path()
      ..moveTo(leftTop.dx, leftTop.dy)
      ..lineTo(midCenter.dx, midCenter.dy)
      ..lineTo(bottomPoint.dx, bottomPoint.dy)
      ..lineTo(leftBottom.dx, leftBottom.dy)
      ..close();

    final rightFace = Path()
      ..moveTo(midCenter.dx, midCenter.dy)
      ..lineTo(rightTop.dx, rightTop.dy)
      ..lineTo(rightBottom.dx, rightBottom.dy)
      ..lineTo(bottomPoint.dx, bottomPoint.dy)
      ..close();

    canvas.drawPath(
      topFace,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.white.withOpacity(0.38), Colors.white.withOpacity(0.12)]
              : [Colors.white, const Color(0xFFDADCE4)],
        ).createShader(topFace.getBounds()),
    );

    canvas.drawPath(
      leftFace,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [Colors.white.withOpacity(0.22), Colors.white.withOpacity(0.04)]
              : [const Color(0xFFF6F7FA), const Color(0xFFCFD3DE)],
        ).createShader(leftFace.getBounds()),
    );

    canvas.drawPath(
      rightFace,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [Colors.white.withOpacity(0.10), Colors.black.withOpacity(0.50)]
              : [const Color(0xFFD4D7E2), const Color(0xFF9EA4B3)],
        ).createShader(rightFace.getBounds()),
    );

    canvas.save();
    canvas.translate(cx, cy * 0.98);
    canvas.rotate(-0.14);
    final innerCard = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w * 0.34, height: h * 0.25),
      Radius.circular(w * 0.045),
    );
    canvas.drawRRect(
      innerCard,
      Paint()
        ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.10),
    );
    canvas.drawRRect(
      innerCard,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.white.withOpacity(isDark ? 0.55 : 0.95),
    );
    final Color baseLineColor =
        (isDark ? Colors.white : const Color(0xFF121216));
    final linePaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.6
      ..color = baseLineColor.withOpacity(0.75);
    canvas.drawLine(
      Offset(-w * 0.11, -h * 0.05),
      Offset(w * 0.11, -h * 0.05),
      linePaint,
    );
    canvas.drawLine(
      Offset(-w * 0.11, 0),
      Offset(w * 0.06, 0),
      linePaint..color = baseLineColor.withOpacity(0.45),
    );
    canvas.drawLine(
      Offset(-w * 0.11, h * 0.05),
      Offset(w * 0.03, h * 0.05),
      linePaint..color = baseLineColor.withOpacity(0.30),
    );
    canvas.restore();

    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.95),
          Colors.white.withOpacity(0.25),
          Colors.white.withOpacity(0.75),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(topFace, edgePaint);
    canvas.drawPath(leftFace, edgePaint);
    canvas.drawPath(rightFace, edgePaint);

    final penPath = Path()
      ..moveTo(w * 0.80, h * 0.17)
      ..lineTo(w * 0.89, h * 0.25)
      ..lineTo(w * 0.67, h * 0.52)
      ..lineTo(w * 0.56, h * 0.56)
      ..lineTo(w * 0.60, h * 0.44)
      ..close();
    canvas.drawPath(
      penPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isDark
              ? [Colors.white.withOpacity(0.88), Colors.white.withOpacity(0.18)]
              : [Colors.white, const Color(0xFF454752)],
        ).createShader(penPath.getBounds()),
    );
    canvas.drawPath(
      penPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withOpacity(0.9),
    );

    if (enableShimmer) {
      final sx = -w * 0.5 + (phase * w * 2.0);
      final clip = Path()
        ..addPath(topFace, Offset.zero)
        ..addPath(leftFace, Offset.zero)
        ..addPath(rightFace, Offset.zero);
      canvas.save();
      canvas.clipPath(clip);
      final beamPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(isDark ? 0.24 : 0.58),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(sx, 0, w * 0.34, h));
      canvas.drawRect(Rect.fromLTWH(sx, 0, w * 0.34, h), beamPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SculptedPrismPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.isDark != isDark ||
      oldDelegate.enableShimmer != enableShimmer;
}

class Onyx3DPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const Onyx3DPillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = OnyxPalette.of(OnyxSettings.isDark);
    final enable3D = OnyxSettings.enable3D;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(left: 10, top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: pal.isDark
                      ? [Colors.white, const Color(0xFFDADCE2)]
                      : [const Color(0xFF1D1E24), const Color(0xFF060608)],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [pal.cardTop, pal.cardBottom],
                ),
          border: Border.all(
            color: isSelected
                ? (pal.isDark ? Colors.white : Colors.black)
                : pal.glassBorder,
            width: 1.1,
          ),
          boxShadow: enable3D
              ? [
                  BoxShadow(
                    color: isSelected
                        ? (pal.isDark
                            ? Colors.white.withOpacity(0.18)
                            : Colors.black.withOpacity(0.24))
                        : pal.shadowDeep.withOpacity(0.45),
                    blurRadius: isSelected ? 16 : 10,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? pal.onAccent : pal.textSecondary,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? pal.onAccent : pal.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Onyx3DButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const Onyx3DButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    final pal = OnyxPalette.of(OnyxSettings.isDark);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: isPrimary
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: pal.isDark
                      ? [Colors.white, const Color(0xFFD8DAE0)]
                      : [const Color(0xFF1F2026), const Color(0xFF070709)],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [pal.cardTop, pal.cardBottom],
                ),
          border: Border.all(
            color: isPrimary ? pal.glassHighlight : pal.glassStrongBorder,
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: pal.shadowDeep,
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 19,
                color: isPrimary ? pal.onAccent : pal.textPrimary,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? pal.onAccent : pal.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
