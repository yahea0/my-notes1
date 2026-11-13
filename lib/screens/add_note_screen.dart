import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:math_expressions/math_expressions.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';
import '../services/notification_service.dart';
import '../theme/onyx_theme.dart';
import '../widgets/luxury_3d_glass.dart';
import 'sketch_screen.dart';

class AddNoteScreen extends StatefulWidget {
  final Map? note;
  final dynamic noteKey;

  const AddNoteScreen({super.key, this.note, this.noteKey});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _todoController = TextEditingController();
  final ScrollController _contentScrollController = ScrollController();

  String _selectedCategory = 'عام';
  int? _customTitleColor;
  int? _customContentColor;
  String _fontFamily = 'Tahoma';
  double _titleFontSize = 22.0;
  double _contentFontSize = 16.0;
  bool _styleForTitle = true;

  List<String> _imagePaths = [];
  List<Map<String, String>> _audioRecords = [];
  List<String> _tags = [];
  List<Map<String, dynamic>> _checklist = [];

  String _calcDisplay = '0';
  final List<String> _calcHistory = [];

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingPath;
  Duration _playDuration = Duration.zero;
  Duration _playPosition = Duration.zero;
  StreamSubscription<void>? _completeSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;

  bool _isPinned = false;
  bool _isLocked = false;
  bool _showChecklistInput = false;

  static const List<String> _categories = ['عام', 'العمل', 'الدراسة', 'شخصي'];

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _titleController =
        TextEditingController(text: n != null ? (n['title'] ?? '') : '');
    _contentController =
        TextEditingController(text: n != null ? (n['content'] ?? '') : '');

    final cat = n != null ? (n['category'] as String? ?? 'عام') : 'عام';
    _selectedCategory = _categories.contains(cat) ? cat : 'عام';

    if (n != null) {
      _customTitleColor = n['textColor'] as int?;
      _customContentColor = n['contentColor'] as int?;
      _fontFamily = (n['fontFamily'] as String?) ?? 'Tahoma';
      _titleFontSize = ((n['titleFontSize'] as num?) ?? 22.0).toDouble();
      _contentFontSize = ((n['contentFontSize'] as num?) ?? 16.0).toDouble();
      _imagePaths = List<String>.from(n['imagePaths'] ?? []);
      _audioRecords = List<Map<String, String>>.from(
        (n['audioRecords'] ?? []).map((x) => Map<String, String>.from(x)),
      );
      _tags = List<String>.from(n['tags'] ?? []);
      _checklist = List<Map<String, dynamic>>.from(
        (n['checklist'] ?? []).map((x) => Map<String, dynamic>.from(x)),
      );
      _isPinned = (n['isPinned'] as bool?) ?? false;
      _isLocked = (n['isLocked'] as bool?) ?? false;
      _showChecklistInput = _checklist.isNotEmpty;
    }

    _completeSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _currentlyPlayingPath = null;
          _playPosition = Duration.zero;
        });
      }
    });
    _durationSub = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _playDuration = d);
    });
    _positionSub = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _playPosition = p);
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _completeSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _todoController.dispose();
    _contentScrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildNoteMap({bool asCopy = false}) {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy/MM/dd').format(now);
    final timeStr = DateFormat('hh:mm a').format(now);

    return {
      'title':
          asCopy ? 'نسخة من ${_titleController.text}' : _titleController.text,
      'content': _contentController.text,
      'category': _selectedCategory,
      'date':
          (!asCopy && widget.note != null) ? widget.note!['date'] : dateStr,
      'time':
          (!asCopy && widget.note != null) ? widget.note!['time'] : timeStr,
      'isFavorite': (!asCopy && widget.note != null)
          ? (widget.note!['isFavorite'] ?? false)
          : false,
      'isArchived': (!asCopy && widget.note != null)
          ? (widget.note!['isArchived'] ?? false)
          : false,
      'isPinned': asCopy ? false : _isPinned,
      'isLocked': asCopy ? false : _isLocked,
      'textColor': _customTitleColor,
      'contentColor': _customContentColor,
      'fontFamily': _fontFamily,
      'titleFontSize': _titleFontSize,
      'contentFontSize': _contentFontSize,
      'imagePaths': List<String>.from(_imagePaths),
      'audioRecords':
          _audioRecords.map((e) => Map<String, String>.from(e)).toList(),
      'tags': List<String>.from(_tags),
      'checklist':
          _checklist.map((e) => Map<String, dynamic>.from(e)).toList(),
      'updatedAt': now.millisecondsSinceEpoch,
    };
  }

  void _saveNote() {
    final hasAnyData = _titleController.text.trim().isNotEmpty ||
        _contentController.text.trim().isNotEmpty ||
        _imagePaths.isNotEmpty ||
        _audioRecords.isNotEmpty ||
        _checklist.isNotEmpty;

    if (!hasAnyData) {
      Navigator.pop(context);
      return;
    }

    final noteData = _buildNoteMap();
    if (widget.note == null) {
      Hive.box('notes').add(noteData);
    } else {
      Hive.box('notes').put(widget.noteKey, noteData);
    }
    Navigator.pop(context);
  }

  void _duplicateNote() {
    Hive.box('notes').add(_buildNoteMap(asCopy: true));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إنشاء نسخة من الملاحظة')),
    );
  }

  Future<void> _setReminder() async {
    final pal = OnyxPalette.of(OnyxSettings.isDark);
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: (pal.isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
            colorScheme: pal.isDark
                ? const ColorScheme.dark(
                    primary: Colors.white,
                    onPrimary: Colors.black,
                    surface: Color(0xFF161616),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Colors.black,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (time == null || !mounted) return;
    final ok = await NotificationService.scheduleAlarmReminder(
      context: context,
      time: time,
      title: _titleController.text,
      body: _contentController.text,
    );

    if (ok && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم ضبط المنبه في ${time.format(context)}')),
      );
    }
  }

  void _searchInNote() {
    final pal = OnyxPalette.of(OnyxSettings.isDark);
    final searchController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.elevatedBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: pal.glassBorder),
        ),
        title:
            Text('البحث داخل الملاحظة', style: TextStyle(color: pal.textPrimary)),
        content: TextField(
          controller: searchController,
          autofocus: true,
          style: TextStyle(color: pal.textPrimary),
          decoration: InputDecoration(
            hintText: 'أدخل الكلمة للبحث...',
            hintStyle: TextStyle(color: pal.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(color: pal.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final query = searchController.text;
              Navigator.pop(ctx);
              if (query.isEmpty) return;
              final startIndex = _contentController.text.indexOf(query);
              if (startIndex != -1) {
                _contentController.selection = TextSelection(
                  baseOffset: startIndex,
                  extentOffset: startIndex + query.length,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لم يتم العثور على النص.')),
                );
              }
            },
            child: Text('بحث', style: TextStyle(color: pal.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _pickColor() {
    final pal = OnyxPalette.of(OnyxSettings.isDark);
    Color currentColor = _styleForTitle
        ? resolveAdaptiveNoteColor(_customTitleColor, pal)
        : resolveAdaptiveNoteColor(_customContentColor, pal, isContent: true);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.elevatedBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: pal.glassBorder),
        ),
        title: Text(
          _styleForTitle ? 'اختر لون العنوان' : 'اختر لون النص',
          style: TextStyle(color: pal.textPrimary),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) {
              setState(() {
                if (_styleForTitle) {
                  _customTitleColor = color.value;
                } else {
                  _customContentColor = color.value;
                }
              });
            },
            pickerAreaHeightPercent: 0.7,
            enableAlpha: false,
            displayThumbColor: true,
            paletteType: PaletteType.hsvWithHue,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                if (_styleForTitle) {
                  _customTitleColor = null;
                } else {
                  _customContentColor = null;
                }
              });
              Navigator.pop(ctx);
            },
            child: Text('افتراضي', style: TextStyle(color: pal.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('تم', style: TextStyle(color: pal.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _pickFont() {
    final pal = OnyxPalette.of(OnyxSettings.isDark);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26)),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: pal.elevatedBg.withOpacity(0.92),
                    border:
                        Border(top: BorderSide(color: pal.glassStrongBorder)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: pal.divider,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'اختر الخط وحجمه',
                        style: TextStyle(
                          color: pal.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text('العنوان'),
                            selected: _styleForTitle,
                            onSelected: (_) =>
                                setModalState(() => _styleForTitle = true),
                            selectedColor: pal.accent,
                            labelStyle: TextStyle(
                              color: _styleForTitle
                                  ? pal.onAccent
                                  : pal.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          ChoiceChip(
                            label: const Text('النص'),
                            selected: !_styleForTitle,
                            onSelected: (_) =>
                                setModalState(() => _styleForTitle = false),
                            selectedColor: pal.accent,
                            labelStyle: TextStyle(
                              color: !_styleForTitle
                                  ? pal.onAccent
                                  : pal.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 76,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: kOnyxFonts.length,
                          itemBuilder: (context, index) {
                            final f = kOnyxFonts[index];
                            final bool isSelected = _fontFamily == f['id'];
                            return GestureDetector(
                              onTap: () {
                                setModalState(() => _fontFamily = f['id']!);
                                setState(() {});
                              },
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected ? pal.accent : pal.chipBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? pal.accent
                                        : pal.glassBorder,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  f['name']!,
                                  style: applyArabicFont(
                                    f['id']!,
                                    TextStyle(
                                      color: isSelected
                                          ? pal.onAccent
                                          : pal.textPrimary,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'حجم الخط (${(_styleForTitle ? _titleFontSize : _contentFontSize).toInt()})',
                        style: TextStyle(color: pal.textPrimary),
                      ),
                      Slider(
                        value:
                            _styleForTitle ? _titleFontSize : _contentFontSize,
                        min: 12,
                        max: 40,
                        activeColor: pal.accent,
                        onChanged: (val) {
                          setModalState(() {
                            if (_styleForTitle) {
                              _titleFontSize = val;
                            } else {
                              _contentFontSize = val;
                            }
                          });
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage();
      if (images.isNotEmpty && mounted) {
        setState(() => _imagePaths.addAll(images.map((e) => e.path)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر اختيار الصور: $e')),
        );
      }
    }
  }

  Future<void> _openSketchStudio() async {
    final String? savedPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SketchScreen()),
    );
    if (savedPath != null && mounted) {
      setState(() => _imagePaths.add(savedPath));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إدراج الرسم في الملاحظة')),
      );
    }
  }

  void _viewGallery(int initialIndex) {
    if (_imagePaths.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => _GalleryModal(
        imagePaths: _imagePaths,
        initialIndex: initialIndex,
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _recordTimer?.cancel();
      try {
        final path = await _audioRecorder.stop();
        if (!mounted) return;
        setState(() {
          _isRecording = false;
          _recordSeconds = 0;
          if (path != null) {
            _audioRecords.add({
              'path': path,
              'name': 'تسجيل ${_audioRecords.length + 1}',
            });
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ التسجيل الصوتي')),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isRecording = false;
          _recordSeconds = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } else {
      try {
        if (await _audioRecorder.hasPermission()) {
          final dir = await getApplicationDocumentsDirectory();
          final path =
              '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _audioRecorder.start(const RecordConfig(), path: path);
          if (!mounted) return;
          setState(() {
            _isRecording = true;
            _recordSeconds = 0;
          });
          _recordTimer?.cancel();
          _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted && _isRecording) {
              setState(() => _recordSeconds++);
            }
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم رفض إذن الميكروفون')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في بدء التسجيل: $e')),
          );
        }
      }
    }
  }

  Future<void> _togglePlayAudio(String path) async {
    try {
      if (_currentlyPlayingPath == path) {
        await _audioPlayer.stop();
        if (mounted) {
          setState(() {
            _currentlyPlayingPath = null;
            _playPosition = Duration.zero;
          });
        }
      } else {
        final file = File(path);
        if (!file.existsSync()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ملف الصوت غير موجود على الجهاز')),
            );
          }
          return;
        }
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(path));
        if (mounted) setState(() => _currentlyPlayingPath = path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تشغيل الصوت: $e')),
        );
      }
    }
  }

  void _renameAudio(int index) {
    final pal = OnyxPalette.of(OnyxSettings.isDark);
    final controller =
        TextEditingController(text: _audioRecords[index]['name']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.elevatedBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: pal.glassBorder),
        ),
        title: Text('اسم التسجيل', style: TextStyle(color: pal.textPrimary)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: pal.textPrimary),
          decoration: InputDecoration(
            hintText: 'أدخل اسماً...',
            hintStyle: TextStyle(color: pal.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(color: pal.textMuted)),
          ),
          TextButton(
            onPressed: () {
              setState(() => _audioRecords[index]['name'] = controller.text);
              Navigator.pop(ctx);
            },
            child: Text('حفظ', style: TextStyle(color: pal.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _insertTextAtCursor(String snippet) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (selection.start == -1) {
      _contentController.text = text + snippet;
    } else {
      final newText =
          text.replaceRange(selection.start, selection.end, snippet);
      _contentController.value = TextEditingValue(
        text: newText,
        selection:
            TextSelection.collapsed(offset: selection.start + snippet.length),
      );
    }
    setState(() {});
  }

  String _evaluateExpression(String raw) {
    try {
      final String exp = raw
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('−', '-')
          .replaceAllMapped(
            RegExp(r'(\d+(?:\.\d+)?)%(?!\d)'),
            (m) => '(${m[1]}/100)',
          )
          .replaceAllMapped(
            RegExp(r'√(\d+(?:\.\d+)?)'),
            (m) => 'sqrt(${m[1]})',
          )
          .replaceAll('√', 'sqrt');

      final Parser p = Parser();
      final Expression parsed = p.parse(exp);
      final ContextModel cm = ContextModel();
      final double eval = parsed.evaluate(EvaluationType.REAL, cm);
      if (eval.isNaN || eval.isInfinite) return 'خطأ';
      final resultStr =
          eval.toStringAsFixed(eval.truncateToDouble() == eval ? 0 : 2);
      if (_calcHistory.isEmpty || _calcHistory.first != '$raw = $resultStr') {
        _calcHistory.insert(0, '$raw = $resultStr');
        if (_calcHistory.length > 4) _calcHistory.removeLast();
      }
      return resultStr;
    } catch (_) {
      return 'خطأ';
    }
  }

  void _showCalculatorDialog() {
    final pal = OnyxPalette.of(OnyxSettings.isDark);
    _calcDisplay = '0';
    final List<String> buttons = [
      '(', ')', '^', '√',
      'C', '⌫', '%', '÷',
      '7', '8', '9', '×',
      '4', '5', '6', '−',
      '1', '2', '3', '+',
      '0', '.', '=',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Onyx3DGlassCard(
                padding: const EdgeInsets.all(14),
                borderRadius: 26,
                isHighlighted: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الحاسبة الذكية 3D',
                          style: TextStyle(
                            color: pal.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: pal.chipBg,
                              shape: BoxShape.circle,
                              border: Border.all(color: pal.glassBorder),
                            ),
                            child: Icon(
                              Icons.close,
                              color: pal.textPrimary,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_calcHistory.isNotEmpty)
                      SizedBox(
                        height: 28,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _calcHistory
                              .map(
                                (h) => GestureDetector(
                                  onTap: () => setModalState(
                                    () =>
                                        _calcDisplay = h.split('=').last.trim(),
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: pal.chipBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      h,
                                      style: TextStyle(
                                        color: pal.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: pal.isDark
                            ? Colors.black.withOpacity(0.55)
                            : Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: pal.glassBorder),
                      ),
                      width: double.infinity,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Text(
                          _calcDisplay,
                          style: TextStyle(
                            fontSize: 32,
                            color: pal.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 4,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.25,
                      children: buttons.map((e) {
                        final bool isEq = e == '=';
                        final bool isOp = [
                          'C', '⌫', '%', '÷', '×', '−', '+', '(', ')', '^', '√'
                        ].contains(e);

                        return Material(
                          color: isEq
                              ? pal.accent
                              : (isOp
                                  ? pal.chipBg.withOpacity(0.9)
                                  : pal.inputFill),
                          borderRadius: BorderRadius.circular(14),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                if (e == 'C') {
                                  _calcDisplay = '0';
                                } else if (e == '⌫') {
                                  if (_calcDisplay.isNotEmpty &&
                                      _calcDisplay != '0') {
                                    _calcDisplay = _calcDisplay.substring(
                                      0,
                                      _calcDisplay.length - 1,
                                    );
                                    if (_calcDisplay.isEmpty) {
                                      _calcDisplay = '0';
                                    }
                                  }
                                } else if (e == '=') {
                                  _calcDisplay =
                                      _evaluateExpression(_calcDisplay);
                                } else {
                                  if (_calcDisplay == '0' &&
                                      e != '.' &&
                                      !['÷', '×', '+', '^', '%'].contains(e)) {
                                    _calcDisplay = e;
                                  } else {
                                    _calcDisplay += e;
                                  }
                                }
                              });
                            },
                            child: Center(
                              child: Text(
                                e,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: isEq || isOp
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isEq ? pal.onAccent : pal.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: Onyx3DButton(
                        label: 'إدراج النتيجة في النص',
                        icon: Icons.input,
                        onPressed: () {
                          if (_calcDisplay != 'خطأ') {
                            _insertTextAtCursor(_calcDisplay);
                          }
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSettingsSheet() {
    final pal = OnyxPalette.of(OnyxSettings.isDark);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: pal.elevatedBg.withOpacity(0.92),
                border: Border(top: BorderSide(color: pal.glassStrongBorder)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: pal.divider,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Icon(Icons.alarm, color: pal.textPrimary),
                    title: Text(
                      'تذكير / منبه',
                      style: TextStyle(color: pal.textPrimary),
                    ),
                    onTap: _setReminder,
                  ),
                  ListTile(
                    leading: Icon(Icons.search, color: pal.textPrimary),
                    title: Text(
                      'البحث عن نص داخل الملاحظة',
                      style: TextStyle(color: pal.textPrimary),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _searchInNote();
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      _isLocked ? Icons.lock_open : Icons.lock_outline,
                      color: pal.textPrimary,
                    ),
                    title: Text(
                      _isLocked
                          ? 'إلغاء قفل الملاحظة'
                          : 'حماية الملاحظة برقم سري',
                      style: TextStyle(color: pal.textPrimary),
                    ),
                    subtitle: Text(
                      'رمز القفل الحالي: ${OnyxSettings.vaultPin}',
                      style: TextStyle(color: pal.textMuted, fontSize: 12),
                    ),
                    onTap: () {
                      setState(() => _isLocked = !_isLocked);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _isLocked
                                ? 'سيتم قفل الملاحظة عند الحفظ'
                                : 'تم إلغاء قفل الملاحظة',
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.copy, color: pal.textPrimary),
                    title: Text(
                      'إنشاء نسخة من الملاحظة',
                      style: TextStyle(color: pal.textPrimary),
                    ),
                    onTap: _duplicateNote,
                  ),
                  ListTile(
                    leading: Icon(Icons.share, color: pal.textPrimary),
                    title: Text(
                      'مشاركة / إرسال',
                      style: TextStyle(color: pal.textPrimary),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final text =
                          '${_titleController.text}\n\n${_contentController.text}';
                      final validImages = _imagePaths
                          .where((p) => File(p).existsSync())
                          .map((p) => XFile(p))
                          .toList();
                      if (validImages.isNotEmpty) {
                        await Share.shareXFiles(
                          validImages,
                          text: text.trim().isEmpty ? null : text,
                        );
                      } else {
                        await Share.share(text);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatSeconds(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  int _wordCount(String txt) {
    final clean = txt.trim();
    if (clean.isEmpty) return 0;
    return clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  @override
  Widget build(BuildContext context) {
    final pal = OnyxPalette.of(OnyxSettings.isDark);
    final Color titleColor = resolveAdaptiveNoteColor(_customTitleColor, pal);
    final Color contentColor =
        resolveAdaptiveNoteColor(_customContentColor, pal, isContent: true);

    final TextStyle titleStyle = applyArabicFont(
      _fontFamily,
      TextStyle(
        fontSize: _titleFontSize,
        fontWeight: FontWeight.bold,
        color: titleColor,
      ),
    );
    final TextStyle contentStyle = applyArabicFont(
      _fontFamily,
      TextStyle(
        fontSize: _contentFontSize,
        color: contentColor,
        height: 1.65,
      ),
    );

    final int words = _wordCount(_contentController.text);
    final int doneCount = _checklist.where((c) => c['done'] == true).length;

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: pal.textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.note == null ? 'ملاحظة جديدة' : 'تعديل الملاحظة',
          style: TextStyle(color: pal.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: _isLocked ? 'مقفلة' : 'قفل الملاحظة',
            icon: Icon(
              _isLocked ? Icons.lock : Icons.lock_open_outlined,
              color: _isLocked ? pal.textPrimary : pal.textMuted,
            ),
            onPressed: () => setState(() => _isLocked = !_isLocked),
          ),
          IconButton(
            tooltip: 'تثبيت',
            icon: Icon(
              _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: _isPinned ? Colors.amber : pal.textPrimary,
            ),
            onPressed: () => setState(() => _isPinned = !_isPinned),
          ),
          IconButton(
            tooltip: 'حفظ',
            icon: Icon(Icons.check, color: pal.textPrimary),
            onPressed: _saveNote,
          ),
        ],
      ),
      body: OnyxBackdrop(
        palette: pal,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isRecording)
                      Onyx3DGlassCard(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        borderRadius: 18,
                        isHighlighted: true,
                        enableShimmer: true,
                        child: Row(
                          children: [
                            const Icon(Icons.mic, color: Colors.red, size: 26),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'جاري التسجيل... ${_formatSeconds(_recordSeconds)}',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _RecordingWaveBars(seed: _recordSeconds),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _toggleRecording,
                              icon: const Icon(Icons.stop, size: 18),
                              label: const Text('إيقاف'),
                            ),
                          ],
                        ),
                      ),
                    Onyx3DGlassCard(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      borderRadius: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _titleController,
                            style: titleStyle,
                            decoration: InputDecoration(
                              hintText: 'عنوان الملاحظة...',
                              hintStyle: TextStyle(color: pal.textMuted),
                              border: InputBorder.none,
                            ),
                          ),
                          Divider(color: pal.divider),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ..._tags.map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pal.chipBg,
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(color: pal.glassBorder),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '#$tag',
                                        style: TextStyle(
                                          color: pal.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () =>
                                            setState(() => _tags.remove(tag)),
                                        child: Icon(
                                          Icons.close,
                                          size: 13,
                                          color: pal.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 135,
                                child: TextField(
                                  controller: _tagController,
                                  style: TextStyle(
                                    color: pal.textPrimary,
                                    fontSize: 12.5,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: '+ أضف وسماً...',
                                    hintStyle: TextStyle(
                                      color: pal.textMuted,
                                      fontSize: 12,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  onSubmitted: (val) {
                                    final clean =
                                        val.trim().replaceAll('#', '');
                                    if (clean.isNotEmpty &&
                                        !_tags.contains(clean)) {
                                      setState(() => _tags.add(clean));
                                    }
                                    _tagController.clear();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_imagePaths.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          height: 108,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _imagePaths.length,
                            itemBuilder: (context, index) {
                              final imgFile = File(_imagePaths[index]);
                              return Stack(
                                children: [
                                  GestureDetector(
                                    onTap: () => _viewGallery(index),
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 10),
                                      width: 108,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border:
                                            Border.all(color: pal.glassBorder),
                                        color: pal.chipBg,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(15),
                                        child: imgFile.existsSync()
                                            ? Image.file(
                                                imgFile,
                                                fit: BoxFit.cover,
                                              )
                                            : Icon(
                                                Icons.broken_image_outlined,
                                                color: pal.textMuted,
                                              ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => setState(
                                        () => _imagePaths.removeAt(index),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: Colors.black87,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    if (_audioRecords.isNotEmpty)
                      ...List.generate(_audioRecords.length, (index) {
                        final record = _audioRecords[index];
                        final path = record['path'] ?? '';
                        final bool isPlayingThis =
                            _currentlyPlayingPath == path;

                        return Onyx3DGlassCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          borderRadius: 16,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isPlayingThis
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_fill,
                                      color: isPlayingThis
                                          ? pal.danger
                                          : pal.textPrimary,
                                      size: 32,
                                    ),
                                    onPressed: () => _togglePlayAudio(path),
                                  ),
                                  Expanded(
                                    child: Text(
                                      record['name'] ?? 'تسجيل صوتي',
                                      style: TextStyle(
                                        color: pal.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      color: pal.textMuted,
                                      size: 19,
                                    ),
                                    onPressed: () => _renameAudio(index),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: pal.danger,
                                      size: 19,
                                    ),
                                    onPressed: () {
                                      if (isPlayingThis) _audioPlayer.stop();
                                      setState(() {
                                        if (isPlayingThis) {
                                          _currentlyPlayingPath = null;
                                        }
                                        _audioRecords.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (isPlayingThis &&
                                  _playDuration.inMilliseconds > 0)
                                Slider(
                                  value: _playPosition.inMilliseconds
                                      .clamp(0, _playDuration.inMilliseconds)
                                      .toDouble(),
                                  max: _playDuration.inMilliseconds.toDouble(),
                                  activeColor: pal.accent,
                                  onChanged: (v) => _audioPlayer.seek(
                                    Duration(milliseconds: v.toInt()),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    if (_showChecklistInput || _checklist.isNotEmpty)
                      Onyx3DGlassCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        borderRadius: 18,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'قائمة المهام ($doneCount/${_checklist.length})',
                                  style: TextStyle(
                                    color: pal.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                                if (_checklist.isNotEmpty)
                                  Text(
                                    '${((doneCount / _checklist.length) * 100).round()}%',
                                    style: TextStyle(
                                      color: pal.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            if (_checklist.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: doneCount / _checklist.length,
                                backgroundColor: pal.chipBg,
                                color: pal.accent,
                                minHeight: 4,
                              ),
                            ],
                            const SizedBox(height: 8),
                            ...List.generate(_checklist.length, (i) {
                              final item = _checklist[i];
                              final bool done = item['done'] == true;
                              return Row(
                                children: [
                                  Checkbox(
                                    value: done,
                                    activeColor: pal.accent,
                                    checkColor: pal.onAccent,
                                    onChanged: (v) => setState(
                                      () => _checklist[i]['done'] = v ?? false,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      item['text']?.toString() ?? '',
                                      style: TextStyle(
                                        color: done
                                            ? pal.textMuted
                                            : pal.textPrimary,
                                        decoration: done
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: pal.textMuted,
                                    ),
                                    onPressed: () =>
                                        setState(() => _checklist.removeAt(i)),
                                  ),
                                ],
                              );
                            }),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _todoController,
                                    style: TextStyle(
                                      color: pal.textPrimary,
                                      fontSize: 13.5,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: '+ أضف مهمة جديدة...',
                                      hintStyle:
                                          TextStyle(color: pal.textMuted),
                                      border: InputBorder.none,
                                    ),
                                    onSubmitted: (val) {
                                      if (val.trim().isEmpty) return;
                                      setState(() {
                                        _checklist.add({
                                          'text': val.trim(),
                                          'done': false,
                                        });
                                      });
                                      _todoController.clear();
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.add_circle_outline,
                                    color: pal.textPrimary,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    final val = _todoController.text.trim();
                                    if (val.isEmpty) return;
                                    setState(() {
                                      _checklist.add({
                                        'text': val,
                                        'done': false,
                                      });
                                    });
                                    _todoController.clear();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    Onyx3DGlassCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 24,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 220),
                        child: TextField(
                          controller: _contentController,
                          scrollController: _contentScrollController,
                          maxLines: null,
                          style: contentStyle,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'اكتب ملاحظتك هنا...',
                            hintStyle: TextStyle(color: pal.textMuted),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$words كلمة · ${_contentController.text.length} حرف',
                          style: TextStyle(color: pal.textMuted, fontSize: 12),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => _insertTextAtCursor('\n• '),
                              child: Text(
                                '• نقطة',
                                style: TextStyle(
                                  color: pal.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _insertTextAtCursor('\n──────────\n'),
                              child: Text(
                                '— فاصل',
                                style: TextStyle(
                                  color: pal.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: pal.elevatedBg,
            border: Border(top: BorderSide(color: pal.divider)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'إدراج صور',
                  icon: Icon(Icons.image_outlined, color: pal.textSecondary),
                  onPressed: _pickImages,
                ),
                IconButton(
                  tooltip: 'لوحة الرسم الحر',
                  icon: Icon(Icons.brush_outlined, color: pal.textSecondary),
                  onPressed: _openSketchStudio,
                ),
                IconButton(
                  tooltip: 'تسجيل صوتي',
                  icon: Icon(
                    _isRecording ? Icons.stop_circle : Icons.mic_none,
                    color: _isRecording ? Colors.red : pal.textSecondary,
                    size: _isRecording ? 28 : 24,
                  ),
                  onPressed: _toggleRecording,
                ),
                IconButton(
                  tooltip: 'قائمة مهام',
                  icon: Icon(
                    Icons.checklist_rounded,
                    color: _showChecklistInput
                        ? pal.textPrimary
                        : pal.textSecondary,
                  ),
                  onPressed: () => setState(
                    () => _showChecklistInput = !_showChecklistInput,
                  ),
                ),
                IconButton(
                  tooltip: 'الألوان',
                  icon:
                      Icon(Icons.color_lens_outlined, color: pal.textSecondary),
                  onPressed: _pickColor,
                ),
                IconButton(
                  tooltip: 'الخط والحجم',
                  icon: Icon(Icons.text_fields, color: pal.textSecondary),
                  onPressed: _pickFont,
                ),
                IconButton(
                  tooltip: 'الحاسبة الذكية',
                  icon:
                      Icon(Icons.calculate_outlined, color: pal.textSecondary),
                  onPressed: _showCalculatorDialog,
                ),
                IconButton(
                  tooltip: 'خيارات وتذكير ومشاركة',
                  icon: Icon(Icons.tune, color: pal.textSecondary),
                  onPressed: _showSettingsSheet,
                ),
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: pal.elevatedBg,
                  underline: const SizedBox.shrink(),
                  icon: Icon(Icons.arrow_drop_down, color: pal.textPrimary),
                  style: TextStyle(color: pal.textPrimary, fontSize: 13.5),
                  items: _categories
                      .map(
                        (v) =>
                            DropdownMenuItem<String>(value: v, child: Text(v)),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingWaveBars extends StatelessWidget {
  final int seed;
  const _RecordingWaveBars({required this.seed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(14, (i) {
        final h = 6.0 + ((math.sin(seed + i * 0.9).abs()) * 14.0);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 4,
          height: h,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.85),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

class _GalleryModal extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;

  const _GalleryModal({
    required this.imagePaths,
    required this.initialIndex,
  });

  @override
  State<_GalleryModal> createState() => _GalleryModalState();
}

class _GalleryModalState extends State<_GalleryModal> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          PhotoViewGallery.builder(
            itemCount: widget.imagePaths.length,
            pageController: _pageController,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: FileImage(File(widget.imagePaths[index])),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2.5,
              );
            },
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
