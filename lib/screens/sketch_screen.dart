import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/onyx_theme.dart';
import '../widgets/luxury_3d_glass.dart';

class _SketchStroke {
  final List<Offset> points;
  final Color color;
  final double width;

  _SketchStroke({
    required this.points,
    required this.color,
    required this.width,
  });
}

class SketchScreen extends StatefulWidget {
  const SketchScreen({super.key});

  @override
  State<SketchScreen> createState() => _SketchScreenState();
}

class _SketchScreenState extends State<SketchScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final List<_SketchStroke> _strokes = [];
  _SketchStroke? _activeStroke;

  Color _inkColor = Colors.white;
  bool _darkCanvas = true;
  double _strokeWidth = 3.5;
  bool _saving = false;

  Future<void> _saveSketch() async {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ارسم شيئاً أولاً قبل الحفظ')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final dir = await getApplicationDocumentsDirectory();
        final path =
            '${dir.path}/sketch_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(path);
        await file.writeAsBytes(byteData.buffer.asUint8List());
        if (mounted) {
          Navigator.pop(context, path);
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ الرسم: $e')),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final pal = OnyxPalette.of(OnyxSettings.isDark);

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'لوحة الرسم الحر',
          style: TextStyle(color: pal.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: pal.textPrimary),
        actions: [
          IconButton(
            tooltip: 'تراجع',
            icon: const Icon(Icons.undo),
            onPressed: _strokes.isEmpty
                ? null
                : () => setState(() => _strokes.removeLast()),
          ),
          IconButton(
            tooltip: 'مسح اللوحة',
            icon: const Icon(Icons.delete_outline),
            onPressed: _strokes.isEmpty
                ? null
                : () => setState(() => _strokes.clear()),
          ),
          IconButton(
            tooltip: 'حفظ وإدراج',
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _saving ? null : _saveSketch,
          ),
        ],
      ),
      body: OnyxBackdrop(
        palette: pal,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Onyx3DGlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                borderRadius: 18,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _colorDot(Colors.white, 'أبيض', pal),
                            const SizedBox(width: 8),
                            _colorDot(const Color(0xFFA1A1AA), 'فضي', pal),
                            const SizedBox(width: 8),
                            _colorDot(const Color(0xFF0A0A0D), 'أسود', pal),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _darkCanvas = !_darkCanvas;
                              if (!_darkCanvas && _inkColor == Colors.white) {
                                _inkColor = const Color(0xFF0A0A0D);
                              } else if (_darkCanvas &&
                                  _inkColor == const Color(0xFF0A0A0D)) {
                                _inkColor = Colors.white;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: pal.chipBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: pal.glassBorder),
                            ),
                            child: Text(
                              _darkCanvas ? 'لوحة سوداء' : 'لوحة بيضاء',
                              style: TextStyle(
                                color: pal.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'السُمك (${_strokeWidth.toStringAsFixed(1)})',
                          style:
                              TextStyle(color: pal.textSecondary, fontSize: 12),
                        ),
                        Expanded(
                          child: Slider(
                            value: _strokeWidth,
                            min: 1.5,
                            max: 14.0,
                            activeColor: pal.accent,
                            onChanged: (v) => setState(() => _strokeWidth = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Onyx3DGlassCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 24,
                  isHighlighted: true,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: GestureDetector(
                        onPanStart: (details) {
                          setState(() {
                            _activeStroke = _SketchStroke(
                              points: [details.localPosition],
                              color: _inkColor,
                              width: _strokeWidth,
                            );
                            _strokes.add(_activeStroke!);
                          });
                        },
                        onPanUpdate: (details) {
                          if (_activeStroke == null) return;
                          setState(() {
                            _activeStroke!.points.add(details.localPosition);
                          });
                        },
                        onPanEnd: (_) => _activeStroke = null,
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: _darkCanvas
                              ? const Color(0xFF0A0B0F)
                              : Colors.white,
                          child: CustomPaint(
                            painter: _SketchPainter(strokes: _strokes),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorDot(Color c, String label, OnyxPalette pal) {
    final bool selected = _inkColor == c;
    return GestureDetector(
      onTap: () => setState(() => _inkColor = c),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? pal.accent : pal.chipBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: pal.glassBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? pal.onAccent : pal.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SketchPainter extends CustomPainter {
  final List<_SketchStroke> strokes;
  const _SketchPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (s.points.length == 1) {
        canvas.drawCircle(
          s.points.first,
          s.width / 2,
          paint..style = PaintingStyle.fill,
        );
        continue;
      }

      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (int i = 1; i < s.points.length; i++) {
        path.lineTo(s.points[i].dx, s.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) => true;
}
