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
  final ScrollController _outerScrollController = ScrollController();
  final ScrollController _codeHorizScrollController = ScrollController();
  final ScrollController _contentScrollController = ScrollController();
  final GlobalKey _editorAreaKey = GlobalKey();
  final List<TapGestureRecognizer> _linkRecognizers = [];

  final TextEditingController _findController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  final FocusNode _findFocusNode = FocusNode();
  bool _showFindBar = false;
  bool _showReplaceRow = false;
  bool _caseSensitive = false;
  bool _matchesCapped = false;
  List<TextRange> _searchMatches = [];
  int _activeMatchIndex = -1;

  List<int> _lineStarts = [0];
  int _longestLineIndex = 0;
  int _cachedWords = 0;
  List<DetectedLink> _cachedLinks = const [];
  Timer? _heavyAnalysisTimer;
  Timer? _findDebounceTimer;
  Timer? _scrollWindowTimer;

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
  bool _isReadingMode = false;

  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  String _lastCommittedText = '';
  bool _applyingHistory = false;

  late final String _initTitle;
  late final String _initContent;
  late final String _initCategory;
  late final int? _initTitleColor;
  late final int? _initContentColor;
  late final String _initFont;
  late final double _initContentSize;
  late final bool _initPinned;
  late final bool _initLocked;
  late final String _initCodeMode;
  late final String _initLangId;
  late final int _initImagesLen;
  late final int _initAudiosLen;
  late final int _initTagsLen;
  late final int _initCheckLen;

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
    _lastCommittedText = initialContent;

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

    _initTitle = _titleController.text;
    _initContent = _contentController.text;
    _initCategory = _selectedCategory;
    _initTitleColor = _customTitleColor;
    _initContentColor = _customContentColor;
    _initFont = _fontFamily;
    _initContentSize = _contentFontSize;
    _initPinned = _isPinned;
    _initLocked = _isLocked;
    _initCodeMode = _codeMode;
    _initLangId = _manualLangId;
    _initImagesLen = _imagePaths.length;
    _initAudiosLen = _audioRecords.length;
    _initTagsLen = _tags.length;
    _initCheckLen = _checklist.length;

    _rebuildFastMetrics(initialContent);
    _refreshLinksImmediate(initialContent);
    _refreshCodeDetection();
    _contentController.updateHighlightWindow(0, 16000, notify: false);

    _outerScrollController.addListener(_onOuterScroll);

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
    _heavyAnalysisTimer?.cancel();
    _findDebounceTimer?.cancel();
    _scrollWindowTimer?.cancel();
    _recordTimer?.cancel();
    _completeSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _outerScrollController.removeListener(_onOuterScroll);
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _todoController.dispose();
    _findController.dispose();
    _replaceController.dispose();
    _findFocusNode.dispose();
    _outerScrollController.dispose();
    _codeHorizScrollController.dispose();
    _contentScrollController.dispose();
    super.dispose();
  }

  void _rebuildFastMetrics(String text) {
    final int len = text.length;
    final List<int> starts = [0];
    int longestIdx = 0;
    int longestLen = 0;
    int words = 0;
    bool inWord = false;
    int lineStart = 0;

    for (int i = 0; i < len; i++) {
      final int c = text.codeUnitAt(i);
      if (c == 10) {
        final lineLen = i - lineStart;
        if (lineLen > longestLen) {
          longestLen = lineLen;
          longestIdx = starts.length - 1;
        }
        lineStart = i + 1;
        starts.add(lineStart);
        inWord = false;
      } else if (c == 32 || c == 9 || c == 13) {
        inWord = false;
      } else {
        if (!inWord) {
          words++;
          inWord = true;
        }
      }
    }
    final lastLineLen = len - lineStart;
    if (lastLineLen > longestLen) {
      longestIdx = starts.length - 1;
    }

    _lineStarts = starts;
    _longestLineIndex = longestIdx;
    _cachedWords = words;
  }

  void _refreshLinksImmediate(String text) {
    final sample = text.length > 16000 ? text.substring(0, 16000) : text;
    _cachedLinks = LinkDetector.extractLinks(sample);
  }

  void _scheduleHeavyAnalysis(String text) {
    _heavyAnalysisTimer?.cancel();
    if (text.length <= 12000) {
      _refreshLinksImmediate(text);
      return;
    }
    _heavyAnalysisTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _refreshLinksImmediate(_contentController.text));
    });
  }

  void _onOuterScroll() {
    if (_contentController.text.length <= 24000) return;
    _scrollWindowTimer?.cancel();
    _scrollWindowTimer = Timer(const Duration(milliseconds: 90), () {
      if (!mounted || !_outerScrollController.hasClients) return;
      final pos = _outerScrollController.position;
      if (pos.maxScrollExtent <= 0) return;
      final double frac =
          ((pos.pixels + pos.viewportDimension * 0.4) /
                  (pos.maxScrollExtent + pos.viewportDimension))
              .clamp(0.0, 1.0);
      final int estLine = (frac * math.max(0, _lineStarts.length - 1))
          .round()
          .clamp(0, _lineStarts.length - 1);
      final int centerChar = _lineStarts[estLine];
      _ensureHighlightWindowContains(centerChar, notify: true);
    });
  }

  void _ensureHighlightWindowContains(int centerChar, {bool notify = true}) {
    final len = _contentController.text.length;
    if (len <= 24000) return;
    final int curS = _contentController.highlightWindowStart;
    final int curE = _contentController.highlightWindowEnd;
    if (centerChar >= curS + 1800 && centerChar <= curE - 1800) return;

    final int newS = math.max(0, centerChar - 6500);
    final int newE = math.min(len, centerChar + 6500);
    _contentController.updateHighlightWindow(newS, newE, notify: notify);
  }

  int _lineIndexOfOffset(int offset) {
    final int count = _lineStarts.length;
    if (count <= 1) return 0;
    int lo = 0;
    int hi = count - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_lineStarts[mid] <= offset) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return hi.clamp(0, count - 1);
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

  void _refreshCodeDetection() {
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

  void _onContentChanged(String newVal) {
    if (!_applyingHistory && newVal != _lastCommittedText) {
      _undoStack.add(_lastCommittedText);
      final int maxUndo = newVal.length > 40000 ? 15 : 40;
      while (_undoStack.length > maxUndo) {
        _undoStack.removeAt(0);
      }
      _redoStack.clear();
      _lastCommittedText = newVal;
    }

    _rebuildFastMetrics(newVal);
    _refreshCodeDetection();
    _scheduleHeavyAnalysis(newVal);

    if (newVal.length > 24000 &&
        _contentController.selection.isValid &&
        _contentController.selection.start >= 0) {
      _ensureHighlightWindowContains(
        _contentController.selection.start,
        notify: false,
      );
    }

    if (_showFindBar) {
      _recomputeSearchMatches(jumpToFirst: false);
    } else {
      setState(() {});
    }
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _applyingHistory = true;
    _redoStack.add(_contentController.text);
    final prev = _undoStack.removeLast();
    _lastCommittedText = prev;
    _contentController.value = TextEditingValue(
      text: prev,
      selection: TextSelection.collapsed(offset: prev.length),
    );
    _applyingHistory = false;
    _rebuildFastMetrics(prev);
    _refreshLinksImmediate(prev);
    _refreshCodeDetection();
    if (_showFindBar) {
      _recomputeSearchMatches(jumpToFirst: false);
    } else {
      setState(() {});
    }
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _applyingHistory = true;
    _undoStack.add(_contentController.text);
    final next = _redoStack.removeLast();
    _lastCommittedText = next;
    _contentController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _applyingHistory = false;
    _rebuildFastMetrics(next);
    _refreshLinksImmediate(next);
    _refreshCodeDetection();
    if (_showFindBar) {
      _recomputeSearchMatches(jumpToFirst: false);
    } else {
      setState(() {});
    }
  }

  void _toggleFindBar({bool focusInput = true}) {
    setState(() {
      _showFindBar = !_showFindBar;
      if (!_showFindBar) {
        _searchMatches = [];
        _matchesCapped = false;
        _activeMatchIndex = -1;
        _contentController.searchMatches = const [];
        _contentController.activeMatchIndex = -1;
      } else {
        _recomputeSearchMatches(jumpToFirst: false);
      }
    });
    if (_showFindBar && focusInput) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _findFocusNode.requestFocus(),
      );
    }
  }

  void _onFindTextChanged(String _) {
    _findDebounceTimer?.cancel();
    final int delay = _contentController.text.length > 20000 ? 150 : 40;
    _findDebounceTimer = Timer(Duration(milliseconds: delay), () {
      if (mounted) _recomputeSearchMatches(jumpToFirst: true);
    });
  }

  int? _parseLineJumpQuery(String q) {
    final clean = q.trim();
    if (clean.startsWith(':') && clean.length > 1) {
      return int.tryParse(clean.substring(1).trim());
    }
    if (clean.startsWith('#') && clean.length > 1 && _isCodeActive) {
      return int.tryParse(clean.substring(1).trim());
    }
    return null;
  }

  void _recomputeSearchMatches({
    bool jumpToFirst = true,
    int? keepOffsetNear,
  }) {
    final rawQuery = _findController.text;
    final text = _contentController.text;

    if (rawQuery.isEmpty) {
      setState(() {
        _searchMatches = [];
        _matchesCapped = false;
        _activeMatchIndex = -1;
        _contentController.searchMatches = const [];
        _contentController.activeMatchIndex = -1;
      });
      return;
    }

    final int? jumpLine = _parseLineJumpQuery(rawQuery);
    if (jumpLine != null) {
      setState(() {
        _searchMatches = [];
        _matchesCapped = false;
        _activeMatchIndex = -1;
        _contentController.searchMatches = const [];
        _contentController.activeMatchIndex = -1;
      });
      if (jumpToFirst) {
        _jumpToLineNumber(jumpLine);
      }
      return;
    }

    final String haystack = _caseSensitive ? text : text.toLowerCase();
    final String needle = _caseSensitive ? rawQuery : rawQuery.toLowerCase();
    final List<TextRange> found = [];
    bool capped = false;
    const int maxMatches = 2500;

    int start = 0;
    while (start <= haystack.length - needle.length) {
      final idx = haystack.indexOf(needle, start);
      if (idx == -1) break;
      found.add(TextRange(start: idx, end: idx + needle.length));
      if (found.length >= maxMatches) {
        capped = true;
        break;
      }
      start = idx + math.max(1, needle.length);
    }

    int nextIdx = found.isEmpty ? -1 : 0;
    if (found.isNotEmpty && keepOffsetNear != null) {
      for (int k = 0; k < found.length; k++) {
        if (found[k].start >= keepOffsetNear) {
          nextIdx = k;
          break;
        }
      }
    }

    if (nextIdx >= 0) {
      _ensureHighlightWindowContains(found[nextIdx].start, notify: false);
    }

    setState(() {
      _searchMatches = found;
      _matchesCapped = capped;
      _activeMatchIndex = nextIdx;
      _contentController.searchMatches = found;
      _contentController.activeMatchIndex = nextIdx;
    });

    if (jumpToFirst && nextIdx >= 0) {
      _scrollToTextOffset(found[nextIdx].start);
    }
  }

  void _stepMatch(int delta) {
    final int? jumpLine = _parseLineJumpQuery(_findController.text);
    if (jumpLine != null) {
      _jumpToLineNumber(jumpLine);
      return;
    }
    if (_searchMatches.isEmpty) return;
    final int count = _searchMatches.length;
    final int target = (_activeMatchIndex + delta + count) % count;
    final int targetOffset = _searchMatches[target].start;

    _ensureHighlightWindowContains(targetOffset, notify: false);

    setState(() {
      _activeMatchIndex = target;
      _contentController.activeMatchIndex = target;
    });
    _scrollToTextOffset(targetOffset);
  }

  void _replaceCurrentMatch() {
    if (_searchMatches.isEmpty ||
        _activeMatchIndex < 0 ||
        _activeMatchIndex >= _searchMatches.length) {
      return;
    }
    final range = _searchMatches[_activeMatchIndex];
    final replacement = _replaceController.text;
    final currentText = _contentController.text;
    if (range.end > currentText.length) return;

    final newText = currentText.replaceRange(range.start, range.end, replacement);
    _undoStack.add(_lastCommittedText);
    final int maxUndo = newText.length > 40000 ? 15 : 40;
    while (_undoStack.length > maxUndo) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    _lastCommittedText = newText;

    _applyingHistory = true;
    _contentController.value = TextEditingValue(
      text: newText,
      selection:
          TextSelection.collapsed(offset: range.start + replacement.length),
    );
    _applyingHistory = false;

    _rebuildFastMetrics(newText);
    _refreshCodeDetection();
    _scheduleHeavyAnalysis(newText);
    _recomputeSearchMatches(
      jumpToFirst: true,
      keepOffsetNear: range.start + replacement.length,
    );
  }

  void _replaceAllMatches() {
    final rawQuery = _findController.text;
    if (rawQuery.isEmpty) return;

    final currentText = _contentController.text;
    final replacement = _replaceController.text;
    final String haystack =
        _caseSensitive ? currentText : currentText.toLowerCase();
    final String needle = _caseSensitive ? rawQuery : rawQuery.toLowerCase();

    final StringBuffer buf = StringBuffer();
    int pos = 0;
    int replacedCount = 0;

    while (pos <= haystack.length - needle.length) {
      final idx = haystack.indexOf(needle, pos);
      if (idx == -1) break;
      if (idx > pos) buf.write(currentText.substring(pos, idx));
      buf.write(replacement);
      pos = idx + needle.length;
      replacedCount++;
    }
    if (replacedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد نتائج مطابقة للاستبدال')),
      );
      return;
    }
    if (pos < currentText.length) {
      buf.write(currentText.substring(pos));
    }

    final newText = buf.toString();
    _undoStack.add(_lastCommittedText);
    final int maxUndo = newText.length > 40000 ? 15 : 40;
    while (_undoStack.length > maxUndo) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    _lastCommittedText = newText;

    _applyingHistory = true;
    _contentController.value = TextEditingValue(
      text: newText,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _applyingHistory = false;

    _rebuildFastMetrics(newText);
    _refreshCodeDetection();
    _scheduleHeavyAnalysis(newText);
    _recomputeSearchMatches(jumpToFirst: false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم استبدال $replacedCount نتيجة بنجاح')),
    );
  }

  void _jumpToLineNumber(int lineNum) {
    final int safeIdx =
        (lineNum - 1).clamp(0, math.max(0, _lineStarts.length - 1));
    final int offset = _lineStarts[safeIdx];
    _ensureHighlightWindowContains(offset, notify: true);
    _scrollToTextOffset(offset);
  }

  void _scrollToTextOffset(int charOffset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _editorAreaKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !_outerScrollController.hasClients) return;

      final scrollCtx =
          _outerScrollController.position.context.notificationContext;
      final viewportBox = scrollCtx?.findRenderObject() as RenderBox?;
      final double dyInViewport = viewportBox != null
          ? box.localToGlobal(Offset.zero, ancestor: viewportBox).dy
          : box.localToGlobal(Offset.zero).dy - 140.0;
      final double cardTopInScroll = _outerScrollController.offset + dyInViewport;
      final double viewportH = _outerScrollController.position.viewportDimension;
      final text = _contentController.text;
      final safeOffset = charOffset.clamp(0, text.length);

      if (_isCodeActive) {
        final int lineIdx = _lineIndexOfOffset(safeOffset);
        final int lineStart = _lineStarts[lineIdx];
        final String linePrefix = text.substring(lineStart, safeOffset);

        final double codeFontSize = _contentFontSize.clamp(12.0, 20.0);
        final codeStyle = TextStyle(
          fontFamily: 'monospace',
          fontSize: codeFontSize,
          height: 1.55,
        );
        final codeStrut = StrutStyle(
          fontFamily: 'monospace',
          fontSize: codeFontSize,
          height: 1.55,
          forceStrutHeight: true,
        );
        final scaler = MediaQuery.textScalerOf(context);
        final double lineH =
            _measureExactLineHeight(codeStyle, codeStrut, scaler);

        final double targetY =
            (cardTopInScroll + 46.0 + (lineIdx * lineH) - (viewportH * 0.35))
                .clamp(0.0, _outerScrollController.position.maxScrollExtent);

        _outerScrollController.animateTo(
          targetY,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );

        if (_codeHorizScrollController.hasClients) {
          final tp = TextPainter(
            text: TextSpan(text: linePrefix, style: codeStyle),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
          )..layout();
          final double targetX = (tp.width - 70.0).clamp(
            0.0,
            _codeHorizScrollController.position.maxScrollExtent,
          );
          _codeHorizScrollController.animateTo(
            targetX,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          );
        }
      } else {
        final double availW = math.max(120.0, box.size.width - 32.0);
        final pal = OnyxPalette.of(OnyxSettings.isDark);
        final contentStyle = applyArabicFont(
          _fontFamily,
          TextStyle(
            fontSize: _contentFontSize,
            color: pal.textPrimary,
            height: 1.65,
          ),
        );
        final tp = TextPainter(
          text: TextSpan(text: text, style: contentStyle),
          textDirection: TextDirection.rtl,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: availW);
        final caretOffset =
            tp.getOffsetForCaret(TextPosition(offset: safeOffset), Rect.zero);
        final double targetY =
            (cardTopInScroll + 16.0 + caretOffset.dy - (viewportH * 0.35))
                .clamp(0.0, _outerScrollController.position.maxScrollExtent);
        _outerScrollController.animateTo(
          targetY,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  double _measureExactLineHeight(
    TextStyle style,
    StrutStyle strut,
    TextScaler scaler,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: '0\n0\n0\n0\n0', style: style),
      strutStyle: strut,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    return tp.height / 5.0;
  }

  double _measureGutterWidth(
    int lineCount,
    TextStyle style,
    TextScaler scaler,
  ) {
    final digits = math.max(2, lineCount.toString().length);
    final tp = TextPainter(
      text: TextSpan(text: '8' * digits, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    return tp.width + 22.0;
  }

  double _measureLongestLineFromCache(
    String text,
    TextStyle style,
    TextScaler scaler,
    double minWidth,
  ) {
    if (_lineStarts.isEmpty) return minWidth;
    final int idx = _longestLineIndex.clamp(0, _lineStarts.length - 1);
    final int start = _lineStarts[idx];
    final int end =
        idx + 1 < _lineStarts.length ? _lineStarts[idx + 1] - 1 : text.length;
    if (end <= start) return minWidth;
    final sample = text.substring(start, end);
    final tp = TextPainter(
      text: TextSpan(text: sample, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    return math.max(minWidth, tp.width + 80.0);
  }

  bool get _hasUnsavedChanges {
    return _titleController.text != _initTitle ||
        _contentController.text != _initContent ||
        _selectedCategory != _initCategory ||
        _customTitleColor != _initTitleColor ||
        _customContentColor != _initContentColor ||
        _fontFamily != _initFont ||
        _contentFontSize != _initContentSize ||
        _isPinned != _initPinned ||
        _isLocked != _initLocked ||
        _codeMode != _initCodeMode ||
        _manualLangId != _initLangId ||
        _imagePaths.length != _initImagesLen ||
        _audioRecords.length != _initAudiosLen ||
        _tags.length != _initTagsLen ||
        _checklist.length != _initCheckLen;
  }

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
      body: _contentController.text,
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
    final String newText;
    final int newOffset;
    if (selection.start == -1) {
      newText = text + snippet;
      newOffset = newText.length;
    } else {
      newText = text.replaceRange(selection.start, selection.end, snippet);
      newOffset = selection.start + snippet.length;
    }
    _undoStack.add(_lastCommittedText);
    _lastCommittedText = newText;
    _applyingHistory = true;
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    _applyingHistory = false;
    _rebuildFastMetrics(newText);
    _refreshCodeDetection();
    _scheduleHeavyAnalysis(newText);
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
                    leading: Icon(
                      Icons.find_in_page_outlined,
                      color: pal.textPrimary,
                    ),
                    title: Text(
                      'البحث والاستبدال داخل الملاحظة',
                      style: TextStyle(color: pal.textPrimary),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (!_showFindBar) {
                        _toggleFindBar();
                      } else {
                        _findFocusNode.requestFocus();
                      }
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
                            _refreshCodeDetection();
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
                              _refreshCodeDetection();
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

  Widget _topActionBtn({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    double size = 20,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Icon(icon, size: size, color: color),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFindAndReplaceBar(OnyxPalette pal) {
    final int? lineJumpTarget = _parseLineJumpQuery(_findController.text);
    final int total = _searchMatches.length;
    final String totalStr = _matchesCapped ? '$total+' : '$total';
    final String countText = lineJumpTarget != null
        ? 'سطر $lineJumpTarget'
        : total == 0
            ? '0 / 0'
            : '${_activeMatchIndex + 1} / $totalStr';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Onyx3DGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        borderRadius: 18,
        isHighlighted: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      setState(() => _showReplaceRow = !_showReplaceRow),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      _showReplaceRow
                          ? Icons.keyboard_arrow_down
                          : Icons.find_replace_rounded,
                      color: pal.textPrimary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _findController,
                    focusNode: _findFocusNode,
                    style: TextStyle(color: pal.textPrimary, fontSize: 13.5),
                    onChanged: _onFindTextChanged,
                    onSubmitted: (_) {
                      _findDebounceTimer?.cancel();
                      if (_searchMatches.isEmpty) {
                        _recomputeSearchMatches(jumpToFirst: true);
                      } else {
                        _stepMatch(1);
                      }
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      hintText: 'بحث عن كلمة، سطر، أو :رقم السطر',
                      hintStyle: TextStyle(color: pal.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: pal.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: pal.glassBorder),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: pal.chipBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    countText,
                    style: TextStyle(
                      color: total > 0 || lineJumpTarget != null
                          ? pal.textPrimary
                          : pal.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _caseSensitive = !_caseSensitive);
                    _recomputeSearchMatches(jumpToFirst: true);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: _caseSensitive ? pal.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: pal.glassBorder),
                    ),
                    child: Text(
                      'Aa',
                      style: TextStyle(
                        color: _caseSensitive ? pal.onAccent : pal.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  padding: EdgeInsets.zero,
                  tooltip: 'النتيجة السابقة',
                  icon: Icon(
                    Icons.keyboard_arrow_up,
                    color: total > 0 ? pal.textPrimary : pal.textMuted,
                    size: 22,
                  ),
                  onPressed: total > 0 ? () => _stepMatch(-1) : null,
                ),
                IconButton(
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  padding: EdgeInsets.zero,
                  tooltip: 'النتيجة التالية',
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: total > 0 || lineJumpTarget != null
                        ? pal.textPrimary
                        : pal.textMuted,
                    size: 22,
                  ),
                  onPressed: total > 0 || lineJumpTarget != null
                      ? () => _stepMatch(1)
                      : null,
                ),
                IconButton(
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  tooltip: 'إغلاق البحث',
                  icon: Icon(Icons.close, color: pal.textMuted, size: 18),
                  onPressed: _toggleFindBar,
                ),
              ],
            ),
            if (_showReplaceRow) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replaceController,
                      maxLines: null,
                      style: TextStyle(color: pal.textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        hintText: 'استبدال بالكلمة أو السطر الجديد...',
                        hintStyle:
                            TextStyle(color: pal.textMuted, fontSize: 12),
                        filled: true,
                        fillColor: pal.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: pal.glassBorder),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: pal.chipBg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    onPressed: total > 0 ? _replaceCurrentMatch : null,
                    child: Text(
                      'استبدال',
                      style: TextStyle(
                        color: total > 0 ? pal.textPrimary : pal.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: pal.accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    onPressed: _findController.text.isNotEmpty
                        ? _replaceAllMatches
                        : null,
                    child: Text(
                      'الكل',
                      style: TextStyle(
                        color: pal.onAccent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReadableNoteArea(OnyxPalette pal, TextStyle contentStyle) {
    _disposeLinkRecognizers();
    final text = _contentController.text;
    final links = _cachedLinks;
    final Color linkColor =
        pal.isDark ? const Color(0xFF7CC4FF) : const Color(0xFF1D4ED8);

    final List<InlineSpan> spans = [];
    int pos = 0;

    if (text.length <= 20000) {
      for (final link in LinkDetector.extractLinks(text, unique: false)) {
        if (link.start > pos) {
          spans.add(
            TextSpan(
              text: text.substring(pos, link.start),
              style: contentStyle,
            ),
          );
        }
        final recognizer = TapGestureRecognizer()
          ..onTap = () => _launchLink(link.normalizedUrl);
        _linkRecognizers.add(recognizer);

        spans.add(
          TextSpan(
            text: text.substring(link.start, link.end),
            recognizer: recognizer,
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
    } else if (links.isNotEmpty) {
      for (final link in links) {
        if (link.start > pos && link.end <= text.length) {
          spans.add(
            TextSpan(
              text: text.substring(pos, link.start),
              style: contentStyle,
            ),
          );
          final recognizer = TapGestureRecognizer()
            ..onTap = () => _launchLink(link.normalizedUrl);
          _linkRecognizers.add(recognizer);
          spans.add(
            TextSpan(
              text: text.substring(link.start, link.end),
              recognizer: recognizer,
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
      }
    }

    if (pos < text.length) {
      spans.add(TextSpan(text: text.substring(pos), style: contentStyle));
    }

    return Onyx3DGlassCard(
      key: _editorAreaKey,
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 220),
        child: SelectableText.rich(
          TextSpan(
            style: contentStyle,
            children: spans.isEmpty
                ? [TextSpan(text: text.isEmpty ? 'ملاحظة فارغة' : text)]
                : spans,
          ),
        ),
      ),
    );
  }

  Widget _buildDetectedLinksSection(
    OnyxPalette pal,
    List<DetectedLink> links,
  ) {
    if (links.isEmpty) return const SizedBox.shrink();

    return Onyx3DGlassCard(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      borderRadius: 20,
      isHighlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, size: 17, color: pal.textPrimary),
              const SizedBox(width: 6),
              Text(
                'الروابط والمقاطع المكتشفة (${links.length})',
                style: TextStyle(
                  color: pal.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...links.map(
            (link) => InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _launchLink(link.normalizedUrl),
              child: Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: pal.chipBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: pal.glassBorder),
                ),
                child: Row(
                  children: [
                    Icon(link.icon, color: pal.textPrimary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${link.platformName} · ${link.categoryLabel}',
                            style: TextStyle(
                              color: pal.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            link.normalizedUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              color: pal.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'نسخ الرابط',
                      icon: Icon(Icons.copy, size: 17, color: pal.textSecondary),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: link.normalizedUrl),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ الرابط')),
                        );
                      },
                    ),
                    Icon(Icons.open_in_new, size: 17, color: pal.textPrimary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeEditorArea(OnyxPalette pal) {
    final int lineCount = math.max(1, _lineStarts.length);
    final double codeFontSize = _contentFontSize.clamp(12.0, 20.0);
    final scaler = MediaQuery.textScalerOf(context);

    final TextStyle codeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: codeFontSize,
      height: 1.55,
      color: pal.textPrimary,
    );
    final StrutStyle codeStrut = StrutStyle(
      fontFamily: 'monospace',
      fontSize: codeFontSize,
      height: 1.55,
      forceStrutHeight: true,
    );

    final double exactLineHeight =
        _measureExactLineHeight(codeStyle, codeStrut, scaler);
    final double gutterWidth = _measureGutterWidth(lineCount, codeStyle, scaler);
    final double totalCodeHeight =
        math.max(240.0, lineCount * exactLineHeight + 24.0);

    int activeLine = -1;
    if (_activeMatchIndex >= 0 && _activeMatchIndex < _searchMatches.length) {
      activeLine = _lineIndexOfOffset(_searchMatches[_activeMatchIndex].start);
    } else if (_contentController.selection.isValid &&
        _contentController.selection.start >= 0) {
      activeLine = _lineIndexOfOffset(_contentController.selection.start);
    }

    return Container(
      key: _editorAreaKey,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [pal.cardTop, pal.cardBottom],
        ),
        border: Border.all(color: pal.glassStrongBorder, width: 1.15),
        boxShadow: [
          BoxShadow(
            color: pal.shadowDeep,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: pal.isDark
                  ? Colors.white.withOpacity(0.05)
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
                          final val =
                              sym == 'Tab' ? '  ' : sym.replaceAll(' ', '');
                          _insertTextAtCursor(val);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: pal.chipBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: pal.glassBorder),
                          ),
                          child: Text(
                            sym,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
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
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double minAvailW =
                    math.max(160.0, constraints.maxWidth - gutterWidth - 8);
                final double editorWidth = _measureLongestLineFromCache(
                  _contentController.text,
                  codeStyle,
                  scaler,
                  minAvailW,
                );

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: gutterWidth,
                      height: totalCodeHeight,
                      decoration: BoxDecoration(
                        color: pal.isDark
                            ? Colors.black.withOpacity(0.32)
                            : Colors.black.withOpacity(0.04),
                        border: Border(right: BorderSide(color: pal.divider)),
                      ),
                      child: AnimatedBuilder(
                        animation: _outerScrollController,
                        builder: (context, _) {
                          return CustomPaint(
                            size: Size(gutterWidth, totalCodeHeight),
                            painter: _ViewportLineNumbersPainter(
                              lineCount: lineCount,
                              lineHeight: exactLineHeight,
                              activeLine: activeLine,
                              style: codeStyle,
                              textScaler: scaler,
                              normalColor: pal.textMuted,
                              activeColor: pal.textPrimary,
                              editorAreaKey: _editorAreaKey,
                              screenHeight: MediaQuery.of(context).size.height,
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _codeHorizScrollController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: editorWidth,
                          child: ConstrainedBox(
                            constraints:
                                BoxConstraints(minHeight: totalCodeHeight),
                            child: TextField(
                              controller: _contentController,
                              scrollController: _contentScrollController,
                              maxLines: null,
                              style: codeStyle,
                              strutStyle: codeStrut,
                              onChanged: _onContentChanged,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.all(12),
                                hintText: '// اكتب أو الصق الكود البرمجي هنا...',
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
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<double> _computeMatchFractions() {
    final totalLen = _contentController.text.length;
    if (totalLen == 0 || _searchMatches.isEmpty) return const [];
    final int step = math.max(1, (_searchMatches.length / 100).ceil());
    final List<double> res = [];
    for (int i = 0; i < _searchMatches.length; i += step) {
      res.add((_searchMatches[i].start / totalLen).clamp(0.0, 1.0));
    }
    return res;
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
            height: 1.65,
          ),
        );

        final int words = _cachedWords;
        final int linesCount =
            _contentController.text.isEmpty ? 0 : _lineStarts.length;
        final int doneCount =
            _checklist.where((c) => c['done'] == true).length;
        final CodeLanguageInfo? activeLang = _activeLanguage;
        final List<DetectedLink> detectedLinks = _cachedLinks;

        return PopScope(
          canPop: false,
          onPopInvoked: (bool didPop) async {
            if (didPop) return;
            await _handleBackPressed();
          },
          child: Scaffold(
            backgroundColor: pal.scaffoldBg,
            resizeToAvoidBottomInset: true,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: kToolbarHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      children: [
                        _topActionBtn(
                          tooltip: 'رجوع',
                          icon: Icons.arrow_back,
                          color: pal.textPrimary,
                          size: 22,
                          onTap: _handleBackPressed,
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _topActionBtn(
                                tooltip: 'البحث والاستبدال',
                                icon: _showFindBar
                                    ? Icons.search_off
                                    : Icons.search,
                                color: _showFindBar
                                    ? pal.accent
                                    : pal.textPrimary,
                                onTap: _toggleFindBar,
                              ),
                              _topActionBtn(
                                tooltip: _isReadingMode
                                    ? 'وضع التحرير'
                                    : 'وضع القراءة والروابط',
                                icon: _isReadingMode
                                    ? Icons.edit_outlined
                                    : Icons.visibility_outlined,
                                color: pal.textPrimary,
                                onTap: () => setState(
                                  () => _isReadingMode = !_isReadingMode,
                                ),
                              ),
                              _topActionBtn(
                                tooltip: 'تراجع',
                                icon: Icons.undo,
                                color: _undoStack.isEmpty
                                    ? pal.textMuted
                                    : pal.textPrimary,
                                onTap: _undoStack.isEmpty ? null : _undo,
                              ),
                              _topActionBtn(
                                tooltip: 'إعادة',
                                icon: Icons.redo,
                                color: _redoStack.isEmpty
                                    ? pal.textMuted
                                    : pal.textPrimary,
                                onTap: _redoStack.isEmpty ? null : _redo,
                              ),
                              _topActionBtn(
                                tooltip: _isLocked ? 'مقفلة' : 'قفل الملاحظة',
                                icon: _isLocked
                                    ? Icons.lock
                                    : Icons.lock_open_outlined,
                                color: _isLocked
                                    ? pal.textPrimary
                                    : pal.textMuted,
                                size: 19,
                                onTap: () =>
                                    setState(() => _isLocked = !_isLocked),
                              ),
                              _topActionBtn(
                                tooltip: 'تثبيت',
                                icon: _isPinned
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                                color:
                                    _isPinned ? Colors.amber : pal.textPrimary,
                                size: 19,
                                onTap: () =>
                                    setState(() => _isPinned = !_isPinned),
                              ),
                              _topActionBtn(
                                tooltip: 'حفظ',
                                icon: Icons.check,
                                color: pal.textPrimary,
                                size: 22,
                                onTap: _saveNote,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            body: OnyxBackdrop(
              palette: pal,
              child: Column(
                children: [
                  if (_showFindBar) _buildFindAndReplaceBar(pal),
                  Expanded(
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          controller: _outerScrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 24, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (activeLang != null)
                                Onyx3DGlassCard(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                  borderRadius: 16,
                                  isHighlighted: true,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.code,
                                        color: pal.textPrimary,
                                        size: 19,
                                      ),
                                      const SizedBox(width: 8),
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
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.arrow_drop_down,
                                                color: pal.textSecondary,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '· $linesCount سطر',
                                                style: TextStyle(
                                                  color: pal.textMuted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        tooltip: 'نسخ الكود',
                                        icon: Icon(
                                          Icons.copy_all,
                                          size: 18,
                                          color: pal.textPrimary,
                                        ),
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(
                                              text: _contentController.text,
                                            ),
                                          );
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content:
                                                  Text('تم نسخ الكود بنجاح'),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        tooltip: 'إيقاف عرض الكود',
                                        icon: Icon(
                                          Icons.close,
                                          size: 18,
                                          color: pal.textMuted,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _codeMode = 'off';
                                            _refreshCodeDetection();
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),

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
                                      const Icon(
                                        Icons.mic,
                                        color: Colors.red,
                                        size: 26,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                            _RecordingWaveBars(
                                              seed: _recordSeconds,
                                            ),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
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
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                borderRadius: 24,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: _titleController,
                                      readOnly: _isReadingMode,
                                      style: titleStyle,
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        hintText: 'عنوان الملاحظة...',
                                        hintStyle:
                                            TextStyle(color: pal.textMuted),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                    Divider(color: pal.divider),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        ..._tags.map(
                                          (tag) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: pal.chipBg,
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                              border: Border.all(
                                                color: pal.glassBorder,
                                              ),
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
                                                  onTap: () => setState(
                                                    () => _tags.remove(tag),
                                                  ),
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
                                        if (!_isReadingMode)
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
                                                final clean = val
                                                    .trim()
                                                    .replaceAll('#', '');
                                                if (clean.isNotEmpty &&
                                                    !_tags.contains(clean)) {
                                                  setState(
                                                    () => _tags.add(clean),
                                                  );
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
                                        final imgFile =
                                            File(_imagePaths[index]);
                                        return Stack(
                                          children: [
                                            GestureDetector(
                                              onTap: () => _viewGallery(index),
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                  left: 10,
                                                ),
                                                width: 108,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: pal.glassBorder,
                                                  ),
                                                  color: pal.chipBg,
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
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
                                              top: 4,
                                              right: 4,
                                              child: GestureDetector(
                                                onTap: () => setState(
                                                  () => _imagePaths
                                                      .removeAt(index),
                                                ),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(3),
                                                  decoration:
                                                      const BoxDecoration(
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
                                              onPressed: () =>
                                                  _togglePlayAudio(path),
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
                                              onPressed: () =>
                                                  _renameAudio(index),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.close,
                                                color: pal.danger,
                                                size: 19,
                                              ),
                                              onPressed: () {
                                                if (isPlayingThis) {
                                                  _audioPlayer.stop();
                                                }
                                                setState(() {
                                                  if (isPlayingThis) {
                                                    _currentlyPlayingPath =
                                                        null;
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
                                    ),
                                  );
                                }),

                              if (_showChecklistInput || _checklist.isNotEmpty)
                                Onyx3DGlassCard(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  borderRadius: 18,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'قائمة المهام ($doneCount/${_checklist.length})',
                                            style: TextStyle(
                                              color: pal.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              if (doneCount > 0)
                                                GestureDetector(
                                                  onTap: () => setState(() {
                                                    _checklist.removeWhere(
                                                      (c) => c['done'] == true,
                                                    );
                                                  }),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      left: 10,
                                                    ),
                                                    child: Text(
                                                      'حذف المكتمل',
                                                      style: TextStyle(
                                                        color: pal.danger,
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
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
                                                () => _checklist[i]['done'] =
                                                    v ?? false,
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
                                                      ? TextDecoration
                                                          .lineThrough
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
                                                fontSize: 13.5,
                                              ),
                                              decoration: InputDecoration(
                                                isDense: true,
                                                hintText:
                                                    '+ أضف مهمة جديدة...',
                                                hintStyle: TextStyle(
                                                  color: pal.textMuted,
                                                ),
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
                                  ),
                                ),

                              if (_isCodeActive)
                                _buildCodeEditorArea(pal)
                              else if (_isReadingMode)
                                _buildReadableNoteArea(pal, contentStyle)
                              else
                                Onyx3DGlassCard(
                                  key: _editorAreaKey,
                                  padding: const EdgeInsets.all(16),
                                  borderRadius: 24,
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(minHeight: 220),
                                    child: TextField(
                                      controller: _contentController,
                                      scrollController:
                                          _contentScrollController,
                                      maxLines: null,
                                      style: contentStyle,
                                      onChanged: _onContentChanged,
                                      decoration: InputDecoration(
                                        hintText:
                                            'اكتب ملاحظتك هنا أو الصق أي رابط فيديو / تواصل أو كود برمجي...',
                                        hintMaxLines: 2,
                                        hintStyle:
                                            TextStyle(color: pal.textMuted),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ),

                              _buildDetectedLinksSection(pal, detectedLinks),

                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$words كلمة · $linesCount سطر · ${_contentController.text.length} حرف',
                                    style: TextStyle(
                                      color: pal.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            _insertTextAtCursor('\n• '),
                                        child: Text(
                                          '• نقطة',
                                          style: TextStyle(
                                            color: pal.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => _insertTextAtCursor(
                                          '\n──────────\n',
                                        ),
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

                        _LuxuryFastScroller(
                          controller: _outerScrollController,
                          palette: pal,
                          isCodeActive: _isCodeActive,
                          totalLines: linesCount,
                          matchFractions: _computeMatchFractions(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
                          color:
                              _isRecording ? Colors.red : pal.textSecondary,
                          size: _isRecording ? 28 : 24,
                        ),
                        onPressed: _toggleRecording,
                      ),
                      IconButton(
                        tooltip: 'وضع الكود البرمجي',
                        icon: Icon(
                          Icons.code,
                          color: _isCodeActive
                              ? pal.textPrimary
                              : pal.textSecondary,
                        ),
                        onPressed: () {
                          if (!_isCodeActive) {
                            setState(() {
                              _codeMode = 'on';
                              _refreshCodeDetection();
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
                        onPressed: () => setState(
                          () => _showChecklistInput = !_showChecklistInput,
                        ),
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

class _ViewportLineNumbersPainter extends CustomPainter {
  final int lineCount;
  final double lineHeight;
  final int activeLine;
  final TextStyle style;
  final TextScaler textScaler;
  final Color normalColor;
  final Color activeColor;
  final GlobalKey editorAreaKey;
  final double screenHeight;

  const _ViewportLineNumbersPainter({
    required this.lineCount,
    required this.lineHeight,
    required this.activeLine,
    required this.style,
    required this.textScaler,
    required this.normalColor,
    required this.activeColor,
    required this.editorAreaKey,
    required this.screenHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (lineCount <= 0 || lineHeight <= 0) return;

    int firstLine = 0;
    int lastLine = math.min(lineCount - 1, 70);

    final box = editorAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final double cardTopOnScreen = box.localToGlobal(Offset.zero).dy;
      final double gutterTopOnScreen = cardTopOnScreen + 46.0;
      final double visStartY = math.max(0.0, -gutterTopOnScreen - 80.0);
      final double visEndY =
          math.min(size.height, screenHeight - gutterTopOnScreen + 80.0);

      firstLine = math.max(0, (visStartY / lineHeight).floor() - 1);
      lastLine = math.min(lineCount - 1, (visEndY / lineHeight).ceil() + 1);
    } else if (lineCount <= 120) {
      lastLine = lineCount - 1;
    }

    for (int i = firstLine; i <= lastLine; i++) {
      final bool isActive = i == activeLine;
      final double y = 12.0 + (i * lineHeight);

      if (isActive) {
        canvas.drawRect(
          Rect.fromLTWH(0, y, size.width, lineHeight),
          Paint()..color = activeColor.withOpacity(0.10),
        );
      }

      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: style.copyWith(
            color: isActive ? activeColor : normalColor,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();

      tp.paint(canvas, Offset(size.width - tp.width - 8.0, y));
    }
  }

  @override
  bool shouldRepaint(covariant _ViewportLineNumbersPainter oldDelegate) => true;
}

class _LuxuryFastScroller extends StatefulWidget {
  final ScrollController controller;
  final OnyxPalette palette;
  final bool isCodeActive;
  final int totalLines;
  final List<double> matchFractions;

  const _LuxuryFastScroller({
    required this.controller,
    required this.palette,
    required this.isCodeActive,
    required this.totalLines,
    required this.matchFractions,
  });

  @override
  State<_LuxuryFastScroller> createState() => _LuxuryFastScrollerState();
}

class _LuxuryFastScrollerState extends State<_LuxuryFastScroller> {
  bool _dragging = false;
  double _dragFraction = 0.0;

  void _jumpToFraction(double fraction) {
    if (!widget.controller.hasClients) return;
    final maxExtent = widget.controller.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    final clamped = fraction.clamp(0.0, 1.0);
    widget.controller.jumpTo(clamped * maxExtent);
    setState(() => _dragFraction = clamped);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (!widget.controller.hasClients) return const SizedBox.shrink();
        final pos = widget.controller.position;
        if (!pos.hasContentDimensions || pos.maxScrollExtent <= 40) {
          return const SizedBox.shrink();
        }

        final double fraction = _dragging
            ? _dragFraction
            : (pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0);
        final int currentLine =
            (1 + (fraction * math.max(0, widget.totalLines - 1))).round();
        final String hudLabel = widget.isCodeActive
            ? 'سطر $currentLine / ${widget.totalLines}'
            : '${(fraction * 100).round()}%';

        return PositionedDirectional(
          end: 2,
          top: 8,
          bottom: 8,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double trackH = math.max(80.0, constraints.maxHeight);
              const double thumbH = 48.0;
              final double usableH = math.max(1.0, trackH - thumbH);
              final double thumbTop = fraction * usableH;

              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_dragging)
                    Transform.translate(
                      offset: Offset(
                        0,
                        (thumbTop + 4).clamp(0.0, math.max(0.0, trackH - 34)),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(left: 6, right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.palette.accent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: widget.palette.shadowDeep,
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          hudLabel,
                          style: TextStyle(
                            color: widget.palette.onAccent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (details) {
                      setState(() => _dragging = true);
                      _jumpToFraction(
                        (details.localPosition.dy - thumbH / 2) / usableH,
                      );
                    },
                    onVerticalDragUpdate: (details) {
                      _jumpToFraction(
                        (details.localPosition.dy - thumbH / 2) / usableH,
                      );
                    },
                    onVerticalDragEnd: (_) =>
                        setState(() => _dragging = false),
                    onTapDown: (details) {
                      _jumpToFraction(
                        (details.localPosition.dy - thumbH / 2) / usableH,
                      );
                    },
                    child: SizedBox(
                      width: 24,
                      height: trackH,
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          Container(
                            width: 4,
                            height: trackH,
                            decoration: BoxDecoration(
                              color: widget.palette.textMuted.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          ...widget.matchFractions.map(
                                (mf) => Positioned(
                                  top: mf * (trackH - 4),
                                  child: Container(
                                    width: 10,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                          Positioned(
                            top: thumbTop,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 90),
                              width: _dragging ? 12 : 8,
                              height: thumbH,
                              decoration: BoxDecoration(
                                color: _dragging
                                    ? widget.palette.accent
                                    : widget.palette.textSecondary
                                        .withOpacity(0.65),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: widget.palette.glassHighlight,
                                  width: 0.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.palette.shadowDeep
                                        .withOpacity(0.45),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
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
