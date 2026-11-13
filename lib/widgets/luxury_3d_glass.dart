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

    final shouldAnimate = widget.enableShimmer && OnyxSettings.enableShimmer;
    if (shouldAnimate && !_shimmerController.isAnimating) {
      _shimmerController.repeat();
    } else if (!shouldAnimate && _shimmerController.isAnimating) {
      _shimmerController.stop();
    }

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
                alignment: Alignment.center,
                children: [
                  Container(
                    width: double.infinity,
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
                  if (shouldAnimate)
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

class OnyxNotebook3DLogo extends StatefulWidget {
  final double size;
  final bool interactiveTilt;

  const OnyxNotebook3DLogo({
    super.key,
    this.size = 260,
    this.interactiveTilt = true,
  });

  @override
  State<OnyxNotebook3DLogo> createState() => _OnyxNotebook3DLogoState();
}

class _OnyxNotebook3DLogoState extends State<OnyxNotebook3DLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _tiltX = 0;
  double _tiltY = 0;

  @override
  void initState() {
    super.initState();
    // دورة 6400ms: 0.00-0.68 حركة متدرجة، 0.68-1.00 (~2.05 ثانية) راحة مع لمعان
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6400),
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
          final t = _controller.value;
          final floatY = math.sin(t * math.pi * 2) * 8.0;
          final gentleYaw = math.sin(t * math.pi * 2) * 0.05;

          return Transform.translate(
            offset: Offset(0, floatY),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0014)
                ..rotateX(_tiltX - 0.09)
                ..rotateY(_tiltY + gentleYaw),
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _SpiralNotebookPenPainter(
                    t: t,
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

class _SpiralNotebookPenPainter extends CustomPainter {
  final double t;
  final bool isDark;
  final bool enableShimmer;

  const _SpiralNotebookPenPainter({
    required this.t,
    required this.isDark,
    required this.enableShimmer,
  });

  // توليد مسار حبر عضوي يشبه خط اليد البشري الحقيقي
  Offset _sampleHandwritingPoint(
    Offset start,
    double maxWidth,
    double progress,
    double ampY,
    double seed,
  ) {
    final x = start.dx + (maxWidth * progress);
    final wave = math.sin(progress * 28.0 + seed) * ampY +
        math.cos(progress * 51.0 + seed * 1.7) * (ampY * 0.45);
    return Offset(x, start.dy + wave);
  }

  void _drawOrganicInkLine(
    Canvas canvas,
    Offset start,
    double maxWidth,
    double progress,
    double ampY,
    double seed,
    Paint paint,
  ) {
    if (progress <= 0.01) return;
    final int steps = math.max(8, (progress * 36).round());
    final path = Path();
    final first = _sampleHandwritingPoint(start, maxWidth, 0.0, ampY, seed);
    path.moveTo(first.dx, first.dy);
    for (int i = 1; i <= steps; i++) {
      final p = (i / steps) * progress;
      final pt = _sampleHandwritingPoint(start, maxWidth, p, ampY, seed);
      path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    double openFactor = 0.0;
    double penHover = 0.0; // ارتفاع القلم عن السطح عند الفتح أو الإغلاق
    double penBlendToWrite = 0.0; // 0 = مستقر فوق الغلاف، 1 = في وضع الكتابة
    double l1 = 0.0;
    double l2 = 0.0;
    double l3 = 0.0;
    bool isActivelyWriting = false;

    if (t < 0.14) {
      // المرحلة 1: رفع القلم جانبًا مع فتح الغلاف ذي الزمبرك
      final p = Curves.easeInOutCubic.transform(t / 0.14);
      openFactor = p;
      penHover = math.sin(p * math.pi);
      penBlendToWrite = p;
    } else if (t < 0.50) {
      // المرحلة 2: كتابة القلم بيد إنسان وبسرعة متساوية عبر السطور الثلاثة
      openFactor = 1.0;
      penBlendToWrite = 1.0;
      isActivelyWriting = true;
      final wt = (t - 0.14) / 0.36; // 0.0 .. 1.0
      if (wt < 0.30) {
        l1 = (wt / 0.30).clamp(0.0, 1.0);
        penHover = 0.0;
      } else if (wt < 0.35) {
        l1 = 1.0;
        final moveP = (wt - 0.30) / 0.05;
        penHover = math.sin(moveP * math.pi) * 0.45;
      } else if (wt < 0.65) {
        l1 = 1.0;
        l2 = ((wt - 0.35) / 0.30).clamp(0.0, 1.0);
        penHover = 0.0;
      } else if (wt < 0.70) {
        l1 = 1.0;
        l2 = 1.0;
        final moveP = (wt - 0.65) / 0.05;
        penHover = math.sin(moveP * math.pi) * 0.45;
      } else {
        l1 = 1.0;
        l2 = 1.0;
        l3 = ((wt - 0.70) / 0.30).clamp(0.0, 1.0);
        penHover = 0.0;
      }
    } else if (t < 0.60) {
      // المرحلة 3: رفع القلم لأعلى أولاً ثم إغلاق الغلاف بنعومة
      final p = Curves.easeInOutCubic.transform((t - 0.50) / 0.10);
      openFactor = 1.0 - p;
      l1 = 1.0;
      l2 = 1.0;
      l3 = 1.0;
      penHover = math.sin(p * math.pi * 0.7) * 1.15;
      penBlendToWrite = 1.0 - p;
    } else if (t < 0.68) {
      // المرحلة 4: نزول القلم بهدوء واستقراره قطرياً فوق الدفتر المغلق
      final p = Curves.easeOutCubic.transform((t - 0.60) / 0.08);
      openFactor = 0.0;
      penHover = (1.0 - p) * 0.65;
      penBlendToWrite = 0.0;
    } else {
      // المرحلة 5: ثبات ثانيتين مع تطواف ولمعان
      openFactor = 0.0;
      penHover = 0.0;
      penBlendToWrite = 0.0;
    }

    // أبعاد كبيرة ومتوازنة تملأ الإطار
    final double bookW = w * 0.43;
    final double bookH = h * 0.64;
    final double spineX = w * 0.285 + (openFactor * w * 0.215);
    final double bookTop = h * 0.18;
    final double bookBottom = bookTop + bookH;
    final double cornerR = w * 0.045;

    // 1. هالة خفيفة خلف الدفتر
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.13 : 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.5), radius: w * 0.48));
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.48, haloPaint);

    // 2. ظل ثلاثي الأبعاد أسفل الدفتر
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(isDark ? 0.65 : 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(spineX + bookW * 0.48 - openFactor * bookW * 0.32, h * 0.89),
        width: bookW * (1.08 + openFactor * 0.68),
        height: h * 0.09,
      ),
      shadowPaint,
    );

    // 3. الغلاف الخلفي وسماكة الصفحات ثلاثية الأبعاد
    final double depthX = w * 0.028;
    final double depthY = h * 0.024;
    final backCoverRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(spineX, bookTop + depthY, bookW + depthX, bookH),
      topRight: Radius.circular(cornerR),
      bottomRight: Radius.circular(cornerR),
      topLeft: Radius.circular(cornerR * 0.35),
      bottomLeft: Radius.circular(cornerR * 0.35),
    );
    canvas.drawRRect(backCoverRect, Paint()..color = const Color(0xFF0A0A0D));
    canvas.drawRRect(
      backCoverRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.white.withOpacity(0.28),
    );

    final pageBlockRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(spineX, bookTop + depthY * 0.45, bookW + depthX * 0.55, bookH),
      topRight: Radius.circular(cornerR * 0.85),
      bottomRight: Radius.circular(cornerR * 0.85),
    );
    canvas.drawRRect(
      pageBlockRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9EBF0), Color(0xFFC5C9D4)],
        ).createShader(pageBlockRect.outerRect),
    );

    // الصفحة اليمنى البيضاء
    final rightPageRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(spineX, bookTop, bookW, bookH),
      topRight: Radius.circular(cornerR),
      bottomRight: Radius.circular(cornerR),
      topLeft: Radius.circular(cornerR * 0.25),
      bottomLeft: Radius.circular(cornerR * 0.25),
    );
    canvas.drawRRect(
      rightPageRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF0F2F7)],
        ).createShader(rightPageRect.outerRect),
    );

    // سطور مسطرة خفيفة
    final rulePaint = Paint()
      ..color = Colors.black.withOpacity(0.085)
      ..strokeWidth = 1.0;
    for (int i = 1; i <= 5; i++) {
      final ly = bookTop + bookH * (0.20 + i * 0.13);
      canvas.drawLine(
        Offset(spineX + bookW * 0.14, ly),
        Offset(spineX + bookW * 0.86, ly),
        rulePaint,
      );
    }

    // حساب موضع القلم أثناء الكتابة البشرية
    final double xStart = spineX + bookW * 0.16;
    final double y1 = bookTop + bookH * 0.33 - 4;
    final double y2 = bookTop + bookH * 0.46 - 4;
    final double y3 = bookTop + bookH * 0.59 - 4;
    final double w1 = bookW * 0.68;
    final double w2 = bookW * 0.64;
    final double w3 = bookW * 0.58;
    final double ampY = h * 0.009;

    Offset writeNibPoint = Offset(xStart, y1);
    double wristProgress = 0.0;

    if (openFactor > 0.20) {
      final inkPaint = Paint()
        ..color = const Color(0xFF101116)
        ..strokeWidth = w * 0.012
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      _drawOrganicInkLine(canvas, Offset(xStart, y1), w1, l1, ampY, 0.0, inkPaint);
      _drawOrganicInkLine(canvas, Offset(xStart, y2), w2, l2, ampY, 2.2, inkPaint);
      _drawOrganicInkLine(canvas, Offset(xStart, y3), w3, l3, ampY, 4.1, inkPaint);

      if (t >= 0.14 && t < 0.50) {
        final wt = (t - 0.14) / 0.36;
        if (wt < 0.30) {
          wristProgress = l1;
          writeNibPoint = _sampleHandwritingPoint(Offset(xStart, y1), w1, l1, ampY, 0.0);
        } else if (wt < 0.35) {
          final p = (wt - 0.30) / 0.05;
          final fromPt = _sampleHandwritingPoint(Offset(xStart, y1), w1, 1.0, ampY, 0.0);
          final toPt = _sampleHandwritingPoint(Offset(xStart, y2), w2, 0.0, ampY, 2.2);
          writeNibPoint = Offset.lerp(fromPt, toPt, p)!;
          wristProgress = 1.0 - p;
        } else if (wt < 0.65) {
          wristProgress = l2;
          writeNibPoint = _sampleHandwritingPoint(Offset(xStart, y2), w2, l2, ampY, 2.2);
        } else if (wt < 0.70) {
          final p = (wt - 0.65) / 0.05;
          final fromPt = _sampleHandwritingPoint(Offset(xStart, y2), w2, 1.0, ampY, 2.2);
          final toPt = _sampleHandwritingPoint(Offset(xStart, y3), w3, 0.0, ampY, 4.1);
          writeNibPoint = Offset.lerp(fromPt, toPt, p)!;
          wristProgress = 1.0 - p;
        } else {
          wristProgress = l3;
          writeNibPoint = _sampleHandwritingPoint(Offset(xStart, y3), w3, l3, ampY, 4.1);
        }
      } else {
        writeNibPoint = _sampleHandwritingPoint(Offset(xStart, y3), w3, l3, ampY, 4.1);
      }
    }

    // 4. الغلاف الأمامي المتحرك حول الزمبرك
    final double angle = openFactor * math.pi * 0.92;
    final double cosA = math.cos(angle);
    final double coverEdgeX = spineX + bookW * cosA;
    final double liftY = math.sin(angle) * (h * 0.045);

    final coverPath = Path()
      ..moveTo(spineX, bookTop)
      ..lineTo(coverEdgeX, bookTop - liftY)
      ..lineTo(coverEdgeX, bookBottom - liftY)
      ..lineTo(spineX, bookBottom)
      ..close();

    final bool showingInnerCover = cosA < 0;
    canvas.drawPath(
      coverPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: showingInnerCover
              ? [const Color(0xFFE7E9F0), const Color(0xFFD0D4DF)]
              : [const Color(0xFF23252E), const Color(0xFF0A0A0D)],
        ).createShader(coverPath.getBounds()),
    );

    if (!showingInnerCover && cosA > 0.28) {
      final plateW = bookW * 0.56 * cosA;
      final plateH = bookH * 0.23;
      final plateCenterX = spineX + bookW * 0.54 * cosA;
      final plateCenterY = bookTop + bookH * 0.30 - liftY * 0.5;
      final plate = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(plateCenterX, plateCenterY),
          width: plateW,
          height: plateH,
        ),
        Radius.circular(w * 0.025),
      );
      canvas.drawRRect(plate, Paint()..color = Colors.white.withOpacity(0.92));
      canvas.drawLine(
        Offset(plateCenterX - plateW * 0.3, plateCenterY - 3),
        Offset(plateCenterX + plateW * 0.3, plateCenterY - 3),
        Paint()
          ..color = const Color(0xFF0B0B0E)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(plateCenterX - plateW * 0.3, plateCenterY + 5),
        Offset(plateCenterX + plateW * 0.14, plateCenterY + 5),
        Paint()
          ..color = const Color(0xFF0B0B0E).withOpacity(0.45)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawPath(
      coverPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.35
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.92),
            Colors.white.withOpacity(0.28),
            Colors.white.withOpacity(0.65),
          ],
        ).createShader(coverPath.getBounds()),
    );

    if (enableShimmer) {
      final sx = -w * 0.4 + (t * w * 1.9);
      canvas.save();
      canvas.clipPath(coverPath);
      canvas.drawRect(
        Rect.fromLTWH(sx, 0, w * 0.28, h),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.transparent,
              Colors.white.withOpacity(0.22),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(sx, 0, w * 0.28, h)),
      );
      canvas.restore();
    }

    // 5. الزمبرك المعدني الحلزوني (7 حلقات بارزة)
    const int coilCount = 7;
    for (int i = 0; i < coilCount; i++) {
      final double cy = bookTop + bookH * (0.11 + (i * 0.78 / (coilCount - 1)));
      canvas.drawCircle(
        Offset(spineX + w * 0.022, cy),
        w * 0.013,
        Paint()..color = const Color(0xFF14151B),
      );
      final coilRect = Rect.fromCenter(
        center: Offset(spineX - w * 0.008, cy),
        width: w * 0.072,
        height: h * 0.036,
      );
      canvas.drawArc(
        coilRect,
        math.pi * 0.45,
        math.pi * 1.35,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.015
          ..strokeCap = StrokeCap.round
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFF8C919E), Color(0xFF1A1B20)],
          ).createShader(coilRect),
      );
    }

    // 6. القلم ثلاثي الأبعاد باللون الأسود والأبيض الأنيق
    // موضع الاستراحة متمركز بدقة داخل حدود الدفتر المغلق
    final Offset restTip = Offset(spineX + bookW * 0.23, bookTop + bookH * 0.72);
    Offset penTip = Offset.lerp(restTip, writeNibPoint, penBlendToWrite)!;
    // تطبيق ارتفاع القلم عن السطح عند فتح/إغلاق الدفتر أو الانتقال بين الأسطر
    penTip = penTip.translate(penHover * (w * 0.02), -penHover * (h * 0.095));

    // زاوية المعصم البشرية + اهتزاز خفيف أثناء الكتابة
    final double handRock = isActivelyWriting
        ? (0.09 * wristProgress + math.sin(t * 185.0) * 0.025)
        : 0.0;
    final double penAngle =
        ui.lerpDouble(-0.78, -0.88, penBlendToWrite)! + handRock;

    final double penLen = w * 0.35;
    final double penThick = w * 0.052;
    final double penScale = 1.0 + (penHover * 0.06);

    // ظل القلم (يتوسع ويبتعد قليلاً عند رفع القلم عن الورق)
    canvas.save();
    canvas.translate(
      penTip.dx + 4 + penHover * 6,
      penTip.dy + 6 + penHover * 14,
    );
    canvas.rotate(penAngle);
    canvas.scale(penScale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, -penThick * 0.45, penLen, penThick * 0.9),
        Radius.circular(penThick),
      ),
      Paint()
        ..color = Colors.black.withOpacity((0.46 - penHover * 0.16).clamp(0.15, 0.5))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 + penHover * 6),
    );
    canvas.restore();

    canvas.save();
    canvas.translate(penTip.dx, penTip.dy);
    canvas.rotate(penAngle);
    canvas.scale(penScale);

    final nibPath = Path()
      ..moveTo(0, 0)
      ..lineTo(penLen * 0.16, -penThick * 0.46)
      ..lineTo(penLen * 0.16, penThick * 0.46)
      ..close();
    canvas.drawPath(
      nibPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFF9EA3B0)],
        ).createShader(nibPath.getBounds()),
    );
    canvas.drawCircle(Offset(1.2, 0), w * 0.008, Paint()..color = Colors.black);

    final lowerBarrel = Rect.fromLTWH(
      penLen * 0.16,
      -penThick * 0.48,
      penLen * 0.24,
      penThick * 0.96,
    );
    canvas.drawRect(
      lowerBarrel,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFD5D8E2), Color(0xFF9DA2B0)],
        ).createShader(lowerBarrel),
    );

    final upperBarrel = RRect.fromRectAndCorners(
      Rect.fromLTWH(
        penLen * 0.40,
        -penThick * 0.48,
        penLen * 0.60,
        penThick * 0.96,
      ),
      topRight: Radius.circular(penThick * 0.48),
      bottomRight: Radius.circular(penThick * 0.48),
    );
    canvas.drawRRect(
      upperBarrel,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3E404A), Color(0xFF0E0F13), Color(0xFF050507)],
        ).createShader(upperBarrel.outerRect),
    );

    canvas.drawRect(
      Rect.fromLTWH(
        penLen * 0.39,
        -penThick * 0.50,
        penLen * 0.04,
        penThick,
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          penLen * 0.55,
          -penThick * 0.72,
          penLen * 0.34,
          penThick * 0.24,
        ),
        Radius.circular(penThick),
      ),
      Paint()..color = Colors.white.withOpacity(0.92),
    );

    canvas.drawLine(
      Offset(penLen * 0.16, -penThick * 0.24),
      Offset(penLen * 0.94, -penThick * 0.24),
      Paint()
        ..color = Colors.white.withOpacity(0.65)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpiralNotebookPenPainter oldDelegate) =>
      oldDelegate.t != t ||
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
