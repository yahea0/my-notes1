import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../utils/code_highlighter.dart';
import '../utils/link_detector.dart';
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
  late final CodeSyntaxTextController _contentController;
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _todoController = TextEditingController();
  final ScrollController _contentScrollController = ScrollController();
  final List<TapGestureRecognizer> _linkRecognizers = [];

  String _selectedCategory = 'عام';
  int? _customTitleColor;
  int? _customContentColor;
  String _fontFamily = 'Tahoma';
  double _titleFontSize = 22.0;
  double _contentFontSize = 16.0;

  List<String> _imagePaths = [];
  List<Map<String, String>> _audioRecords = [];
  List<String> _tags = [];
  List<Map<String, dynamic>> _checklist = [];

  String _codeMode = 'auto';
  String _manualLangId = '';
  CodeLanguageInfo? _detectedLang;
  bool _wrapCodeLines = false;
  bool _isReadingMode = false;
  bool _showExtrasPanel = false;

  // إحصائيات محدثة بشكل مؤجّل (Debounce) لمنع أي تعليق مع الملفات الضخمة
  Timer? _metaDebounce;
  Timer? _undoDebounce;
  int _cachedLineCount = 1;
  int _cachedMaxLineCols = 40;
  int _cachedWordCount = 0;
  List<DetectedLink> _cachedLinks = const [];

  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  String _lastUndoSnapshot = '';
  bool _applyingHistory = false;
  late String _initialSignature;

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
    final initialTitle = n != null ? (n['title'] ?? '').toString() : '';
    final initialContent = n != null ? (n['content'] ?? '').toString() : '';

    _titleController = TextEditingController(text: initialTitle);
    _contentController = CodeSyntaxTextController(text: initialContent);
    _lastUndoSnapshot = initialContent;

    final cat = n != null ? (n['category'] as String? ?? 'عام') : 'عام';
    _selectedCategory = _categories.contains(cat) ? cat : 'عام';

    if (n != null) {
      _customTitleColor = n['textColor'] as int?;
      _customContentColor = n['contentColor'] as int?;
      _fontFamily = (n['fontFamily'] as String?) ?? OnyxSettings.defaultFont;
      _contentFontSize = ((n['contentFontSize'] as num?) ??
              OnyxSettings.defaultContentSize)
          .toDouble();
      _titleFontSize = ((n['titleFontSize'] as num?) ??
              (_contentFontSize + 6.0).clamp(18.0, 38.0))
          .toDouble();
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
      _codeMode = (n['codeMode'] as String?) ?? 'auto';
      _manualLangId = (n['codeLanguage'] as String?) ?? '';
      _showChecklistInput = _checklist.isNotEmpty;
    } else {
      _fontFamily = OnyxSettings.defaultFont;
      _contentFontSize = OnyxSettings.defaultContentSize;
      _titleFontSize = (_contentFontSize + 6.0).clamp(18.0, 38.0);
    }

    _recomputeMetadataImmediate();
    _initialSignature = _computeSignature();

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

  void _disposeLinkRecognizers() {
    for (final r in _linkRecognizers) {
      r.dispose();
    }
    _linkRecognizers.clear();
  }

  @override
  void dispose() {
    _disposeLinkRecognizers();
    _metaDebounce?.cancel();
    _undoDebounce?.cancel();
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

  bool get _isCodeActive {
    if (_codeMode == 'off') return false;
    if (_codeMode == 'on') return true;
    return _detectedLang != null;
  }

  CodeLanguageInfo? get _activeLanguage {
    if (_codeMode == 'off') return null;
    if (_manualLangId.isNotEmpty) return getLanguageById(_manualLangId);
    if (_detectedLang != null) return _detectedLang;
    if (_codeMode == 'on') return getLanguageById('dart');
    return null;
  }

  void _refreshCodeControllerFlags() {
    if (_codeMode == 'auto') {
      _detectedLang = CodeDetector.detect(_contentController.text);
    } else if (_codeMode == 'on') {
      _detectedLang = CodeDetector.detect(_contentController.text) ??
          getLanguageById(_manualLangId.isNotEmpty ? _manualLangId : 'dart');
    } else {
      _detectedLang = null;
    }
    _contentController.syntaxEnabled = _isCodeActive;
    _contentController.isDarkTheme = OnyxSettings.isDark;
    _contentController.languageId = _activeLanguage?.id ?? 'dart';
  }

  // حساب الأسطر وأقصى طول سطر بدون تخصيص ذاكرة أو split() بطيئة
  void _computeFastMetrics(String text) {
    if (text.isEmpty) {
      _cachedLineCount = 1;
      _cachedMaxLineCols = 32;
      _cachedWordCount = 0;
      return;
    }

    int lines = 1;
    int maxCols = 32;
    int start = 0;
    while (true) {
      final idx = text.indexOf('\n', start);
      if (idx == -1) {
        final col = text.length - start;
        if (col > maxCols) maxCols = col;
        break;
      }
      final col = idx - start;
      if (col > maxCols) maxCols = col;
      lines++;
      start = idx + 1;
    }
    _cachedLineCount = lines;
    _cachedMaxLineCols = maxCols;

    // عدّ الكلمات بسرعة فائقة دون RegExp على كامل 250KB
    if (text.length > 60000) {
      // تقدير دقيق وسريع جداً للملفات الضخمة أو عد سريع
      int words = 0;
      bool inSpace = true;
      for (int i = 0; i < text.length; i++) {
        final c = text.codeUnitAt(i);
        final isWs = c == 32 || c == 10 || c == 13 || c == 9;
        if (isWs) {
          inSpace = true;
        } else if (inSpace) {
          words++;
          inSpace = false;
        }
      }
      _cachedWordCount = words;
    } else {
      final clean = text.trim();
      _cachedWordCount = clean.isEmpty
          ? 0
          : clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    }
  }

  void _recomputeMetadataImmediate() {
    final text = _contentController.text;
    _computeFastMetrics(text);
    _refreshCodeControllerFlags();
    final linkSample =
        text.length > 35000 ? text.substring(0, 35000) : text;
    _cachedLinks = LinkDetector.extractLinks(linkSample);
  }

  void _onContentChanged(String newVal) {
    if (!_applyingHistory) {
      _undoDebounce?.cancel();
      _undoDebounce = Timer(const Duration(milliseconds: 550), () {
        if (!mounted) return;
        if (_contentController.text != _lastUndoSnapshot) {
          _undoStack.add(_lastUndoSnapshot);
          final maxHistory = _contentController.text.length > 30000 ? 12 : 35;
          if (_undoStack.length > maxHistory) _undoStack.removeAt(0);
          _redoStack.clear();
          _lastUndoSnapshot = _contentController.text;
        }
      });
    }

    // تحديث الأسطر والطول فورياً أو بمؤقت خفيف لمنع تقطيع الكتابة على 5000+ سطر
    _metaDebounce?.cancel();
    _metaDebounce = Timer(
      Duration(milliseconds: newVal.length > 15000 ? 320 : 120),
      () {
        if (!mounted) return;
        _recomputeMetadataImmediate();
        setState(() {});
      },
    );
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _applyingHistory = true;
    _redoStack.add(_contentController.text);
    final prev = _undoStack.removeLast();
    _lastUndoSnapshot = prev;
    _contentController.value = TextEditingValue(
      text: prev,
      selection: TextSelection.collapsed(offset: prev.length),
    );
    _applyingHistory = false;
    _recomputeMetadataImmediate();
    setState(() {});
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _applyingHistory = true;
    _undoStack.add(_contentController.text);
    final next = _redoStack.removeLast();
    _lastUndoSnapshot = next;
    _contentController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _applyingHistory = false;
    _recomputeMetadataImmediate();
    setState(() {});
  }

  String _computeSignature() {
    return [
      _titleController.text,
      _contentController.text.length.toString(),
      _contentController.text.hashCode.toString(),
      _selectedCategory,
      _customTitleColor?.toString() ?? '',
      _customContentColor?.toString() ?? '',
      _fontFamily,
      _titleFontSize.toStringAsFixed(1),
      _contentFontSize.toStringAsFixed(1),
      _isPinned.toString(),
      _isLocked.toString(),
      _codeMode,
      _manualLangId,
      _imagePaths.join('|'),
      _audioRecords.map((e) => '${e['path']}:${e['name']}').join('|'),
      _tags.join('|'),
      _checklist.map((e) => '${e['text']}:${e['done']}').join('|'),
    ].join('§');
  }

  bool get _hasUnsavedChanges => _computeSignature() != _initialSignature;

  Future<void> _stopRecordingSafelyIfNeeded({bool saveResult = false}) async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      _isRecording = false;
      _recordSeconds = 0;
      if (saveResult && path != null) {
        _audioRecords.add({
          'path': path,
          'name': 'تسجيل ${_audioRecords.length + 1}',
        });
      }
    } catch (_) {
      _isRecording = false;
      _recordSeconds = 0;
    }
  }

  Future<void> _handleBackPressed() async {
    if (!OnyxSettings.confirmOnExit || (!_hasUnsavedChanges && !_isRecording)) {
      await _stopRecordingSafelyIfNeeded();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final pal = OnyxPalette.of(OnyxSettings.isDark);
    final String? action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.elevatedBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: pal.glassStrongBorder),
        ),
        title: Text(
          'هل تريد حفظ الملاحظة؟',
          style: TextStyle(color: pal.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          _isRecording
              ? 'لا يزال التسجيل الصوتي يعمل. يمكنك حفظ الملاحظة مع التسجيل أو الإلغاء.'
              : 'لديك تعديلات لم تُحفظ بعد. اختر حفظ وخروج أو إلغاء لتجاهلها.',
          style: TextStyle(color: pal.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text(
              'إلغاء',
              style: TextStyle(color: pal.danger, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: pal.accent,
              foregroundColor: pal.onAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text(
              'حفظ وخروج',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (!mounted || action == null) return;
    if (action == 'discard') {
      await _stopRecordingSafelyIfNeeded();
      if (mounted) Navigator.of(context).pop();
    } else if (action == 'save') {
      await _saveNote();
    }
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
      'isTrashed': false,
      'isPinned': asCopy ? false : _isPinned,
      'isLocked': asCopy ? false : _isLocked,
      'codeMode': _codeMode,
      'codeLanguage': _activeLanguage?.id ?? _manualLangId,
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

  Future<void> _saveNote() async {
    await _stopRecordingSafelyIfNeeded(saveResult: true);
    if (!mounted) return;

    final hasAnyData = _titleController.text.trim().isNotEmpty ||
        _contentController.text.trim().isNotEmpty ||
        _imagePaths.isNotEmpty ||
        _audioRecords.isNotEmpty ||
        _checklist.isNotEmpty;

    if (!hasAnyData) {
      Navigator.of(context).pop();
      return;
    }

    final noteData = _buildNoteMap();
    if (widget.note == null) {
      Hive.box('notes').add(noteData);
    } else {
      Hive.box('notes').put(widget.noteKey, noteData);
    }
    Navigator.of(context).pop();
  }

  void _duplicateNote() {
    Hive.box('notes').add(_buildNoteMap(asCopy: true));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إنشاء نسخة من الملاحظة')),
    );
  }

  Future<void> _launchLink(String url) async {
    final ok = await NotificationService.openExternalUrl(url);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الرابط، تأكد من صلاحية الرابط')),
      );
    }
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
    final now = DateTime.now();
    final candidate =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final bool isTomorrow = candidate.isBefore(now);

    final ok = await NotificationService.scheduleAlarmReminder(
      context: context,
      time: time,
      title: _titleController.text,
      body: _contentController.text.length > 150
          ? _contentController.text.substring(0, 150)
          : _contentController.text,
    );

    if (ok && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم ضبط المنبه ${isTomorrow ? 'غداً' : 'اليوم'} الساعة ${time.format(context)}',
          ),
        ),
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
                setState(() => _isReadingMode = false);
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
    final Color currentColor =
        resolveAdaptiveNoteColor(_customContentColor ?? _customTitleColor, pal);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.elevatedBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: pal.glassBorder),
        ),
        title:
            Text('اختر لون الملاحظة', style: TextStyle(color: pal.textPrimary)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) {
              setState(() {
                _customTitleColor = color.value;
                _customContentColor = color.value;
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
                _customTitleColor = null;
                _customContentColor = null;
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
                    color: pal.elevatedBg.withOpacity(0.94),
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
                        'حجم الخط (${_contentFontSize.toInt()})',
                        style: TextStyle(color: pal.textPrimary),
                      ),
                      Slider(
                        value: _contentFontSize.clamp(12.0, 32.0),
                        min: 12,
                        max: 32,
                        activeColor: pal.accent,
                        onChanged: (val) {
                          setModalState(() {
                            _contentFontSize = val;
                            _titleFontSize = (val + 6.0).clamp(18.0, 38.0);
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
        setState(() {
          _imagePaths.addAll(images.map((e) => e.path));
          _showExtrasPanel = true;
        });
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
      setState(() {
        _imagePaths.add(savedPath);
        _showExtrasPanel = true;
      });
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
            _showExtrasPanel = true;
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
    final String newText;
    final int newOffset;
    if (selection.start == -1) {
      newText = text + snippet;
      newOffset = newText.length;
    } else {
      newText = text.replaceRange(selection.start, selection.end, snippet);
      newOffset = selection.start + snippet.length;
    }
    _undoStack.add(_lastUndoSnapshot);
    _lastUndoSnapshot = newText;
    _applyingHistory = true;
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    _applyingHistory = false;
    _recomputeMetadataImmediate();
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
                          'الحاسبة',
                          style: TextStyle(
                            color: pal.textSecondary,
                            fontSize: 15,
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

                        final Color btnBg = isEq
                            ? pal.accent
                            : isOp
                                ? (pal.isDark
                                    ? const Color(0xFF282A33)
                                    : const Color(0xFFDCE0EA))
                                : (pal.isDark
                                    ? const Color(0xFF17181E)
                                    : const Color(0xFFF4F5F8));
                        final Color btnText =
                            isEq ? pal.onAccent : pal.textPrimary;

                        return Material(
                          color: btnBg,
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
                                  color: btnText,
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
                color: pal.elevatedBg.withOpacity(0.94),
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

  void _showLanguagePicker(OnyxPalette pal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 400,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pal.elevatedBg.withOpacity(0.95),
              border: Border(top: BorderSide(color: pal.glassStrongBorder)),
            ),
            child: Column(
              children: [
                Text(
                  'اختر لغة البرمجة',
                  style: TextStyle(
                    color: pal.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading:
                            Icon(Icons.auto_fix_high, color: pal.textPrimary),
                        title: Text(
                          'تعرّف تلقائي على اللغة',
                          style: TextStyle(color: pal.textPrimary),
                        ),
                        onTap: () {
                          setState(() {
                            _codeMode = 'auto';
                            _manualLangId = '';
                            _recomputeMetadataImmediate();
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                      ...kSupportedCodeLanguages.map(
                        (lang) => ListTile(
                          leading: Icon(Icons.code, color: pal.textSecondary),
                          title: Text(
                            lang.displayName,
                            style: TextStyle(color: pal.textPrimary),
                          ),
                          trailing: _activeLanguage?.id == lang.id
                              ? Icon(Icons.check, color: pal.accent)
                              : null,
                          onTap: () {
                            setState(() {
                              _codeMode = 'on';
                              _manualLangId = lang.id;
                              _recomputeMetadataImmediate();
                            });
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSeconds(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // وضع القراءة والتصفح فائق السرعة عبر ListView.builder + SelectionArea (120fps على 5000+ سطر)
  Widget _buildVirtualizedReadingArea(
    OnyxPalette pal,
    TextStyle contentStyle,
    bool isCode,
    CodeLanguageInfo? activeLang,
  ) {
    final text = _contentController.text;
    if (text.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pal.isDark ? const Color(0xFF0C0D12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pal.glassBorder),
        ),
        child: Text(
          'لا يوجد محتوى للقراءة بعد',
          style: contentStyle.copyWith(color: pal.textMuted),
        ),
      );
    }

    // تقسيم النص إلى كتل من 24 سطر للتصفح والتحديد الفوري بدون تعليق
    final allLines = text.split('\n');
    const int chunkSize = 24;
    final int chunkCount = (allLines.length / chunkSize).ceil();
    final double codeFontSize = _contentFontSize.clamp(12.0, 20.0);
    final TextStyle codeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: codeFontSize,
      height: 1.5,
      color: pal.textPrimary,
    );
    final Color linkColor =
        pal.isDark ? const Color(0xFF7CC4FF) : const Color(0xFF1D4ED8);

    return Container(
      decoration: BoxDecoration(
        color: pal.isDark ? const Color(0xFF0C0D12) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: SelectionArea(
        child: Directionality(
          textDirection: isCode ? TextDirection.ltr : TextDirection.rtl,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            itemCount: chunkCount,
            itemBuilder: (context, chunkIdx) {
              final int startLine = chunkIdx * chunkSize;
              final int endLine =
                  math.min(startLine + chunkSize, allLines.length);
              final String chunkText =
                  allLines.sublist(startLine, endLine).join('\n');

              if (isCode) {
                final spans = FastCodeTokenizer.tokenizeChunk(
                  chunkText,
                  languageId: activeLang?.id ?? 'dart',
                  isDarkTheme: pal.isDark,
                  baseStyle: codeStyle,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: _cachedLineCount >= 1000 ? 46 : 38,
                        child: Text(
                          List.generate(
                            endLine - startLine,
                            (i) => '${startLine + i + 1}',
                          ).join('\n'),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: codeFontSize,
                            height: 1.5,
                            color: pal.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text.rich(
                            TextSpan(style: codeStyle, children: spans),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // نص عادي مع روابط قابلة للنقر مباشرة
              final links = LinkDetector.extractLinks(chunkText, unique: false);
              if (links.isEmpty) {
                return Text(chunkText, style: contentStyle);
              }

              final List<InlineSpan> spans = [];
              int pos = 0;
              for (final link in links) {
                if (link.start > pos) {
                  spans.add(
                    TextSpan(
                      text: chunkText.substring(pos, link.start),
                      style: contentStyle,
                    ),
                  );
                }
                final rec = TapGestureRecognizer()
                  ..onTap = () => _launchLink(link.normalizedUrl);
                _linkRecognizers.add(rec);
                spans.add(
                  TextSpan(
                    text: chunkText.substring(link.start, link.end),
                    recognizer: rec,
                    style: contentStyle.copyWith(
                      color: linkColor,
                      decoration: TextDecoration.underline,
                      decorationColor: linkColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
                pos = link.end;
              }
              if (pos < chunkText.length) {
                spans.add(
                  TextSpan(text: chunkText.substring(pos), style: contentStyle),
                );
              }
              return Text.rich(TextSpan(style: contentStyle, children: spans));
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCoderQuickToolbar(OnyxPalette pal) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: pal.isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.04),
        border: Border(bottom: BorderSide(color: pal.divider)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['Tab', '{ }', '( )', '[ ]', '=>', ';', '</>', '" "']
              .map(
                (sym) => GestureDetector(
                  onTap: () {
                    final val = sym == 'Tab' ? '  ' : sym.replaceAll(' ', '');
                    _insertTextAtCursor(val);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: pal.chipBg,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: pal.glassBorder),
                    ),
                    child: Text(
                      sym,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: pal.textPrimary,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildFullScreenEditor(
    OnyxPalette pal,
    TextStyle contentStyle,
    bool isCode,
  ) {
    final double codeFontSize = _contentFontSize.clamp(12.0, 20.0);
    final TextStyle codeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: codeFontSize,
      height: 1.5,
      color: pal.textPrimary,
    );
    final StrutStyle codeStrut = StrutStyle(
      fontFamily: 'monospace',
      fontSize: codeFontSize,
      height: 1.5,
      forceStrutHeight: true,
    );

    if (!isCode) {
      return Container(
        decoration: BoxDecoration(
          color: pal.isDark ? const Color(0xFF0D0E13) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pal.glassBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: TextField(
          controller: _contentController,
          scrollController: _contentScrollController,
          expands: true,
          maxLines: null,
          minLines: null,
          textAlignVertical: TextAlignVertical.top,
          autocorrect: _contentController.text.length < 8000,
          enableSuggestions: _contentController.text.length < 8000,
          style: contentStyle,
          onChanged: _onContentChanged,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(14),
            hintText:
                'اكتب ملاحظتك هنا أو الصق أي رابط فيديو / تواصل أو كود برمجي...',
            hintMaxLines: 2,
            hintStyle: TextStyle(color: pal.textMuted),
            border: InputBorder.none,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: pal.isDark ? const Color(0xFF0B0C10) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildCoderQuickToolbar(pal),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: _wrapCodeLines
                  ? TextField(
                      controller: _contentController,
                      scrollController: _contentScrollController,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      textAlign: TextAlign.left,
                      textAlignVertical: TextAlignVertical.top,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: codeStyle,
                      strutStyle: codeStrut,
                      onChanged: _onContentChanged,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(12),
                        hintText: '// اكتب أو الصق الكود البرمجي هنا...',
                        hintStyle: TextStyle(
                          color: pal.textMuted,
                          fontFamily: 'monospace',
                        ),
                        border: InputBorder.none,
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final double gutterWidth = _cachedLineCount >= 1000
                            ? 52.0
                            : (_cachedLineCount >= 100 ? 44.0 : 36.0);
                        final double editorWidth = math.max(
                          constraints.maxWidth - gutterWidth,
                          _cachedMaxLineCols * (codeFontSize * 0.65) + 48,
                        );

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // رسم أرقام الأسطر الظاهرة فقط عبر CustomPaint بسرعة 120fps
                            SizedBox(
                              width: gutterWidth,
                              child: AnimatedBuilder(
                                animation: _contentScrollController,
                                builder: (context, _) => CustomPaint(
                                  painter: _LineGutterPainter(
                                    scrollController: _contentScrollController,
                                    lineCount: _cachedLineCount,
                                    fontSize: codeFontSize,
                                    lineHeightRatio: 1.5,
                                    topPadding: 10.0,
                                    textColor: pal.textMuted,
                                    bgColor: pal.isDark
                                        ? const Color(0xFF08090C)
                                        : const Color(0xFFF1F3F7),
                                    dividerColor: pal.divider,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: editorWidth,
                                  height: constraints.maxHeight,
                                  child: TextField(
                                    controller: _contentController,
                                    scrollController: _contentScrollController,
                                    expands: true,
                                    maxLines: null,
                                    minLines: null,
                                    textAlign: TextAlign.left,
                                    textAlignVertical: TextAlignVertical.top,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    style: codeStyle,
                                    strutStyle: codeStrut,
                                    onChanged: _onContentChanged,
                                    decoration: InputDecoration(
                                      contentPadding:
                                          const EdgeInsets.fromLTRB(
                                        10,
                                        10,
                                        16,
                                        24,
                                      ),
                                      hintText:
                                          '// اكتب أو الصق الكود البرمجي هنا...',
                                      hintStyle: TextStyle(
                                        color: pal.textMuted,
                                        fontFamily: 'monospace',
                                      ),
                                      border: InputBorder.none,
                                    ),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, _, __) {
        final pal = OnyxPalette.of(OnyxSettings.isDark);
        _contentController.isDarkTheme = pal.isDark;

        final Color titleColor =
            resolveAdaptiveNoteColor(_customTitleColor, pal);
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
            height: 1.6,
          ),
        );

        final int doneCount =
            _checklist.where((c) => c['done'] == true).length;
        final CodeLanguageInfo? activeLang = _activeLanguage;
        final bool isCode = _isCodeActive;
        final int extrasCount = _imagePaths.length +
            _audioRecords.length +
            _checklist.length +
            _cachedLinks.length;

        return PopScope(
          canPop: false,
          onPopInvoked: (bool didPop) async {
            if (didPop) return;
            await _handleBackPressed();
          },
          child: Scaffold(
            backgroundColor: pal.scaffoldBg,
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              toolbarHeight: 48,
              backgroundColor: Colors.transparent,
              iconTheme: IconThemeData(color: pal.textPrimary),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _handleBackPressed,
              ),
              actions: [
                if (extrasCount > 0)
                  IconButton(
                    tooltip: 'المرفقات والروابط ($extrasCount)',
                    icon: Badge(
                      label: Text('$extrasCount'),
                      backgroundColor: pal.accent,
                      textColor: pal.onAccent,
                      child: Icon(
                        _showExtrasPanel
                            ? Icons.expand_less
                            : Icons.attach_file,
                        size: 20,
                        color: pal.textPrimary,
                      ),
                    ),
                    onPressed: () =>
                        setState(() => _showExtrasPanel = !_showExtrasPanel),
                  ),
                IconButton(
                  tooltip:
                      _isReadingMode ? 'وضع التحرير' : 'وضع القراءة والتحديد السريع',
                  icon: Icon(
                    _isReadingMode
                        ? Icons.edit_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: _isReadingMode ? pal.accent : pal.textPrimary,
                  ),
                  onPressed: () {
                    _disposeLinkRecognizers();
                    setState(() => _isReadingMode = !_isReadingMode);
                  },
                ),
                IconButton(
                  tooltip: 'تراجع',
                  icon: Icon(
                    Icons.undo,
                    size: 20,
                    color: _undoStack.isEmpty ? pal.textMuted : pal.textPrimary,
                  ),
                  onPressed: _undoStack.isEmpty ? null : _undo,
                ),
                IconButton(
                  tooltip: 'إعادة',
                  icon: Icon(
                    Icons.redo,
                    size: 20,
                    color: _redoStack.isEmpty ? pal.textMuted : pal.textPrimary,
                  ),
                  onPressed: _redoStack.isEmpty ? null : _redo,
                ),
                IconButton(
                  tooltip: _isLocked ? 'مقفلة' : 'قفل الملاحظة',
                  icon: Icon(
                    _isLocked ? Icons.lock : Icons.lock_open_outlined,
                    size: 19,
                    color: _isLocked ? pal.textPrimary : pal.textMuted,
                  ),
                  onPressed: () => setState(() => _isLocked = !_isLocked),
                ),
                IconButton(
                  tooltip: 'تثبيت',
                  icon: Icon(
                    _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 19,
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                child: Column(
                  children: [
                    // شريط اللغة المدمج عند تفعيل الكود
                    if (activeLang != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: pal.isDark
                              ? const Color(0xFF14151C)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: pal.glassBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.code, color: pal.textPrimary, size: 17),
                            const SizedBox(width: 6),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _showLanguagePicker(pal),
                                child: Row(
                                  children: [
                                    Text(
                                      activeLang.displayName,
                                      style: TextStyle(
                                        color: pal.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      color: pal.textSecondary,
                                      size: 17,
                                    ),
                                    Text(
                                      '· $_cachedLineCount سطر',
                                      style: TextStyle(
                                        color: pal.textMuted,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(
                                () => _wrapCodeLines = !_wrapCodeLines,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _wrapCodeLines
                                      ? pal.accent
                                      : pal.chipBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'لف',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _wrapCodeLines
                                        ? pal.onAccent
                                        : pal.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip: 'نسخ الكود',
                              icon: Icon(
                                Icons.copy_all,
                                size: 17,
                                color: pal.textPrimary,
                              ),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: _contentController.text),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم نسخ الكود بنجاح'),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip: 'إيقاف وضع الكود',
                              icon: Icon(
                                Icons.close,
                                size: 17,
                                color: pal.textMuted,
                              ),
                              onPressed: () {
                                setState(() {
                                  _codeMode = 'off';
                                  _recomputeMetadataImmediate();
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                    if (_isRecording)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.red.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mic, color: Colors.red, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'جاري التسجيل... ${_formatSeconds(_recordSeconds)}',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _RecordingWaveBars(seed: _recordSeconds),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _toggleRecording,
                              icon: const Icon(
                                Icons.stop,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              label: const Text(
                                'إيقاف',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // رأس مدمج وخفيف للعنوان والوسوم لا يلتهم مساحة الشاشة
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: pal.isDark
                            ? const Color(0xFF101116)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: pal.glassBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _titleController,
                            readOnly: _isReadingMode,
                            style: titleStyle.copyWith(
                              fontSize: math.min(_titleFontSize, 22.0),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              hintText: 'عنوان الملاحظة...',
                              hintStyle: TextStyle(color: pal.textMuted),
                              border: InputBorder.none,
                            ),
                          ),
                          if (_tags.isNotEmpty || !_isReadingMode)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ..._tags.map(
                                    (tag) => Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: pal.chipBg,
                                        borderRadius:
                                            BorderRadius.circular(99),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '#$tag',
                                            style: TextStyle(
                                              color: pal.textSecondary,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          GestureDetector(
                                            onTap: () => setState(
                                              () => _tags.remove(tag),
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              size: 12,
                                              color: pal.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (!_isReadingMode)
                                    SizedBox(
                                      width: 115,
                                      child: TextField(
                                        controller: _tagController,
                                        style: TextStyle(
                                          color: pal.textPrimary,
                                          fontSize: 12,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          hintText: '+ وسم',
                                          hintStyle: TextStyle(
                                            color: pal.textMuted,
                                            fontSize: 11.5,
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
                            ),
                        ],
                      ),
                    ),

                    // لوحة المرفقات والروابط والمهام القابلة للطي حتى لا تضغط مساحة المحرر
                    if (_showExtrasPanel &&
                        (extrasCount > 0 || _showChecklistInput))
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: pal.isDark
                                ? const Color(0xFF111218)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: pal.glassBorder),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_imagePaths.isNotEmpty) ...[
                                  SizedBox(
                                    height: 82,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _imagePaths.length,
                                      itemBuilder: (context, index) {
                                        final imgFile =
                                            File(_imagePaths[index]);
                                        return Stack(
                                          children: [
                                            GestureDetector(
                                              onTap: () => _viewGallery(index),
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                  left: 8,
                                                ),
                                                width: 82,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: pal.glassBorder,
                                                  ),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(11),
                                                  child: imgFile.existsSync()
                                                      ? Image.file(
                                                          imgFile,
                                                          fit: BoxFit.cover,
                                                        )
                                                      : Icon(
                                                          Icons
                                                              .broken_image_outlined,
                                                          color: pal.textMuted,
                                                        ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 2,
                                              right: 2,
                                              child: GestureDetector(
                                                onTap: () => setState(
                                                  () => _imagePaths
                                                      .removeAt(index),
                                                ),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(2),
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.black87,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 13,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                if (_audioRecords.isNotEmpty)
                                  ...List.generate(_audioRecords.length, (i) {
                                    final rec = _audioRecords[i];
                                    final path = rec['path'] ?? '';
                                    final isPlaying =
                                        _currentlyPlayingPath == path;
                                    return Column(
                                      children: [
                                        Row(
                                          children: [
                                            IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              icon: Icon(
                                                isPlaying
                                                    ? Icons.pause_circle_filled
                                                    : Icons.play_circle_fill,
                                                color: isPlaying
                                                    ? pal.danger
                                                    : pal.textPrimary,
                                              ),
                                              onPressed: () =>
                                                  _togglePlayAudio(path),
                                            ),
                                            Expanded(
                                              child: Text(
                                                rec['name'] ?? 'تسجيل صوتي',
                                                style: TextStyle(
                                                  color: pal.textPrimary,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              icon: Icon(
                                                Icons.edit,
                                                size: 17,
                                                color: pal.textMuted,
                                              ),
                                              onPressed: () => _renameAudio(i),
                                            ),
                                            IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              icon: Icon(
                                                Icons.close,
                                                size: 17,
                                                color: pal.danger,
                                              ),
                                              onPressed: () {
                                                if (isPlaying) {
                                                  _audioPlayer.stop();
                                                }
                                                setState(() {
                                                  if (isPlaying) {
                                                    _currentlyPlayingPath =
                                                        null;
                                                  }
                                                  _audioRecords.removeAt(i);
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                        if (isPlaying &&
                                            _playDuration.inMilliseconds > 0)
                                          Slider(
                                            value: _playPosition.inMilliseconds
                                                .clamp(
                                                  0,
                                                  _playDuration.inMilliseconds,
                                                )
                                                .toDouble(),
                                            max: _playDuration.inMilliseconds
                                                .toDouble(),
                                            activeColor: pal.accent,
                                            onChanged: (v) => _audioPlayer.seek(
                                              Duration(milliseconds: v.toInt()),
                                            ),
                                          ),
                                      ],
                                    );
                                  }),
                                if (_showChecklistInput ||
                                    _checklist.isNotEmpty) ...[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'المهام ($doneCount/${_checklist.length})',
                                        style: TextStyle(
                                          color: pal.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      if (doneCount > 0)
                                        GestureDetector(
                                          onTap: () => setState(() {
                                            _checklist.removeWhere(
                                              (c) => c['done'] == true,
                                            );
                                          }),
                                          child: Text(
                                            'حذف المكتمل',
                                            style: TextStyle(
                                              color: pal.danger,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  ...List.generate(_checklist.length, (i) {
                                    final item = _checklist[i];
                                    final done = item['done'] == true;
                                    return Row(
                                      children: [
                                        Checkbox(
                                          visualDensity: VisualDensity.compact,
                                          value: done,
                                          activeColor: pal.accent,
                                          checkColor: pal.onAccent,
                                          onChanged: (v) => setState(
                                            () => _checklist[i]['done'] =
                                                v ?? false,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item['text']?.toString() ?? '',
                                            style: TextStyle(
                                              fontSize: 13,
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
                                          visualDensity: VisualDensity.compact,
                                          icon: Icon(
                                            Icons.close,
                                            size: 15,
                                            color: pal.textMuted,
                                          ),
                                          onPressed: () => setState(
                                            () => _checklist.removeAt(i),
                                          ),
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
                                            fontSize: 13,
                                          ),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            hintText: '+ أضف مهمة...',
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
                                        visualDensity: VisualDensity.compact,
                                        icon: Icon(
                                          Icons.add_circle_outline,
                                          color: pal.textPrimary,
                                          size: 19,
                                        ),
                                        onPressed: () {
                                          final val =
                                              _todoController.text.trim();
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
                                if (_cachedLinks.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'الروابط المكتشفة (${_cachedLinks.length})',
                                    style: TextStyle(
                                      color: pal.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ..._cachedLinks.map(
                                    (link) => InkWell(
                                      onTap: () =>
                                          _launchLink(link.normalizedUrl),
                                      child: Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 5),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: pal.chipBg,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              link.icon,
                                              size: 18,
                                              color: pal.textPrimary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${link.platformName} · ${link.normalizedUrl}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: pal.textPrimary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.open_in_new,
                                              size: 15,
                                              color: pal.textSecondary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                    // المحرر الرئيسي يملأ كامل المساحة المتبقية من الشاشة
                    Expanded(
                      child: _isReadingMode
                          ? _buildVirtualizedReadingArea(
                              pal,
                              contentStyle,
                              isCode,
                              activeLang,
                            )
                          : _buildFullScreenEditor(pal, contentStyle, isCode),
                    ),

                    // شريط الحالة النحيف أسفل المحرر
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_cachedWordCount كلمة · $_cachedLineCount سطر · ${_contentController.text.length} حرف',
                            style:
                                TextStyle(color: pal.textMuted, fontSize: 11),
                          ),
                          if (_cachedLinks.isNotEmpty && !_showExtrasPanel)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _showExtrasPanel = true),
                              child: Text(
                                '${_cachedLinks.length} رابط جاهز للفتح ↗',
                                style: TextStyle(
                                  color: pal.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else if (!isCode && !_isReadingMode)
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _insertTextAtCursor('\n• '),
                                  child: Text(
                                    '• نقطة',
                                    style: TextStyle(
                                      color: pal.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () =>
                                      _insertTextAtCursor('\n──────────\n'),
                                  child: Text(
                                    '— فاصل',
                                    style: TextStyle(
                                      color: pal.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
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
                        icon: Icon(
                          Icons.image_outlined,
                          color: pal.textSecondary,
                        ),
                        onPressed: _pickImages,
                      ),
                      IconButton(
                        tooltip: 'لوحة الرسم الحر',
                        icon: Icon(
                          Icons.brush_outlined,
                          color: pal.textSecondary,
                        ),
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
                        tooltip: 'وضع الكود البرمجي',
                        icon: Icon(
                          Icons.code,
                          color:
                              isCode ? pal.textPrimary : pal.textSecondary,
                        ),
                        onPressed: () {
                          if (!isCode) {
                            setState(() {
                              _codeMode = 'on';
                              _recomputeMetadataImmediate();
                            });
                          } else {
                            _showLanguagePicker(pal);
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'قائمة مهام',
                        icon: Icon(
                          Icons.checklist_rounded,
                          color: _showChecklistInput
                              ? pal.textPrimary
                              : pal.textSecondary,
                        ),
                        onPressed: () => setState(() {
                          _showChecklistInput = !_showChecklistInput;
                          if (_showChecklistInput) _showExtrasPanel = true;
                        }),
                      ),
                      IconButton(
                        tooltip: 'الألوان',
                        icon: Icon(
                          Icons.color_lens_outlined,
                          color: pal.textSecondary,
                        ),
                        onPressed: _pickColor,
                      ),
                      IconButton(
                        tooltip: 'الخط والحجم',
                        icon: Icon(Icons.text_fields, color: pal.textSecondary),
                        onPressed: _pickFont,
                      ),
                      IconButton(
                        tooltip: 'الحاسبة',
                        icon: Icon(
                          Icons.calculate_outlined,
                          color: pal.textSecondary,
                        ),
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
                        icon:
                            Icon(Icons.arrow_drop_down, color: pal.textPrimary),
                        style:
                            TextStyle(color: pal.textPrimary, fontSize: 13.5),
                        items: _categories
                            .map(
                              (v) => DropdownMenuItem<String>(
                                value: v,
                                child: Text(v),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCategory = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// رسام أرقام الأسطر الظاهرة فقط (يرسم ~30 سطراً في أجزاء من الملي ثانية حتى مع 50,000 سطر)
class _LineGutterPainter extends CustomPainter {
  final ScrollController scrollController;
  final int lineCount;
  final double fontSize;
  final double lineHeightRatio;
  final double topPadding;
  final Color textColor;
  final Color bgColor;
  final Color dividerColor;

  const _LineGutterPainter({
    required this.scrollController,
    required this.lineCount,
    required this.fontSize,
    required this.lineHeightRatio,
    required this.topPadding,
    required this.textColor,
    required this.bgColor,
    required this.dividerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bgColor);
    canvas.drawLine(
      Offset(size.width - 0.5, 0),
      Offset(size.width - 0.5, size.height),
      Paint()
        ..color = dividerColor
        ..strokeWidth = 1,
    );

    if (lineCount <= 0) return;

    final double scrollOffset =
        scrollController.hasClients ? scrollController.offset : 0.0;
    final double lineH = fontSize * lineHeightRatio;

    final int first =
        ((scrollOffset - topPadding) / lineH).floor().clamp(0, lineCount - 1);
    final int last = ((scrollOffset + size.height - topPadding) / lineH)
        .ceil()
        .clamp(0, lineCount - 1);

    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize * 0.85,
      color: textColor,
    );

    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    for (int i = first; i <= last; i++) {
      final double y = topPadding + (i * lineH) - scrollOffset + (lineH - fontSize) * 0.2;
      tp.text = TextSpan(text: '${i + 1}', style: style);
      tp.layout(minWidth: size.width - 8, maxWidth: size.width - 8);
      tp.paint(canvas, Offset(2, y));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LineGutterPainter oldDelegate) => true;
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
