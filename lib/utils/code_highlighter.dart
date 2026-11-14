import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'link_detector.dart';

class CodeLanguageInfo {
  final String id;
  final String displayName;

  const CodeLanguageInfo(this.id, this.displayName);
}

const List<CodeLanguageInfo> kSupportedCodeLanguages = [
  CodeLanguageInfo('dart', 'Dart / Flutter'),
  CodeLanguageInfo('python', 'Python'),
  CodeLanguageInfo('javascript', 'JavaScript'),
  CodeLanguageInfo('typescript', 'TypeScript'),
  CodeLanguageInfo('html', 'HTML'),
  CodeLanguageInfo('css', 'CSS'),
  CodeLanguageInfo('sql', 'SQL'),
  CodeLanguageInfo('json', 'JSON'),
  CodeLanguageInfo('yaml', 'YAML'),
  CodeLanguageInfo('kotlin', 'Kotlin'),
  CodeLanguageInfo('java', 'Java'),
  CodeLanguageInfo('cpp', 'C++'),
  CodeLanguageInfo('c', 'C'),
  CodeLanguageInfo('csharp', 'C#'),
  CodeLanguageInfo('php', 'PHP'),
  CodeLanguageInfo('swift', 'Swift'),
  CodeLanguageInfo('go', 'Go'),
  CodeLanguageInfo('rust', 'Rust'),
  CodeLanguageInfo('bash', 'Bash / Shell'),
  CodeLanguageInfo('xml', 'XML'),
  CodeLanguageInfo('markdown', 'Markdown'),
];

CodeLanguageInfo getLanguageById(String id) {
  for (final lang in kSupportedCodeLanguages) {
    if (lang.id == id) return lang;
  }
  return const CodeLanguageInfo('dart', 'Code');
}

class CodeDetector {
  static CodeLanguageInfo? detect(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length < 10) return null;

    // تحليل أول 3500 حرف فقط للتعرف الفوري حتى على الملفات الضخمة
    final text = trimmed.length > 3500 ? trimmed.substring(0, 3500) : trimmed;

    final textWithoutLinks = text.replaceAll(LinkDetector.urlRegex, '').trim();
    if (textWithoutLinks.length < 8) return null;

    final int arabicChars =
        RegExp(r'[\u0600-\u06FF]').allMatches(textWithoutLinks).length;
    final bool hasCodePunctuation =
        RegExp(r'[{};=<>\[\]()]|def\s|SELECT\s|import\s|#!/')
            .hasMatch(textWithoutLinks);
    if (!hasCodePunctuation && arabicChars > textWithoutLinks.length * 0.35) {
      return null;
    }

    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      if (RegExp(r'"[^"]+"\s*:').hasMatch(text)) {
        return getLanguageById('json');
      }
    }

    if (RegExp(
      r'<!DOCTYPE\s+html|<html[\s>]|<div[\s>]|<script[\s>]|<body[\s>]',
      caseSensitive: false,
    ).hasMatch(text)) {
      return getLanguageById('html');
    }
    if (RegExp(r'<\?xml|xmlns:|<manifest[\s>]|<application[\s>]')
        .hasMatch(text)) {
      return getLanguageById('xml');
    }

    if (text.contains('<?php') ||
        (RegExp(r'\$[a-zA-Z_]\w*').hasMatch(text) && text.contains('->'))) {
      return getLanguageById('php');
    }

    final Map<String, int> scores = {
      for (final l in kSupportedCodeLanguages) l.id: 0,
    };

    void add(String id, RegExp pattern, int weight) {
      if (pattern.hasMatch(textWithoutLinks)) {
        scores[id] = (scores[id] ?? 0) + weight;
      }
    }

    add('dart', RegExp(r"import\s+'package:flutter/|import\s+'dart:"), 6);
    add(
      'dart',
      RegExp(
        r'\b(Widget|StatelessWidget|StatefulWidget|BuildContext|setState)\b',
      ),
      5,
    );
    add(
      'dart',
      RegExp(r'\b(void|Future|Stream|final|const|late|required)\b'),
      2,
    );
    add('dart', RegExp(r'@override'), 2);

    add('python', RegExp(r'^\s*def\s+\w+\s*\(', multiLine: true), 5);
    add(
      'python',
      RegExp(r'^\s*(from\s+\S+\s+import|import\s+\w+)', multiLine: true),
      3,
    );
    add(
      'python',
      RegExp(r'\b(elif|None|True|False|self\.|__init__|print\()\b'),
      4,
    );
    add('python', RegExp(r'if\s+__name__\s*=='), 6);

    add('typescript', RegExp(r'\b(interface|type|enum)\s+[A-Z]\w*'), 4);
    add(
      'typescript',
      RegExp(r':\s*(string|number|boolean|any|void|Promise<)\b'),
      5,
    );
    add(
      'javascript',
      RegExp(
        r'\b(console\.log|document\.|window\.|addEventListener|module\.exports)\b',
      ),
      5,
    );
    add(
      'javascript',
      RegExp(r'\b(const|let|var|function|async|await|export\s+default)\b'),
      2,
    );
    add('javascript', RegExp(r'=>'), 2);

    add(
      'kotlin',
      RegExp(r'\b(fun\s+\w+|override\s+fun|companion\s+object|data\s+class)\b'),
      5,
    );
    add('kotlin', RegExp(r'\b(val|var)\s+\w+\s*[:=]'), 3);
    add('kotlin', RegExp(r'\bprintln\('), 2);

    add(
      'java',
      RegExp(r'public\s+static\s+void\s+main|System\.out\.println'),
      6,
    );
    add('java', RegExp(r'\b(public|private|protected)\s+class\s+\w+'), 4);

    add(
      'cpp',
      RegExp(r'#include\s*<(iostream|vector|string|algorithm)>|std::|cout\s*<<'),
      6,
    );
    add(
      'c',
      RegExp(r'#include\s*<(stdio|stdlib|string)\.h>|printf\(|scanf\(|malloc\('),
      6,
    );
    add(
      'csharp',
      RegExp(r'using\s+System;|Console\.WriteLine|\bnamespace\s+\w+'),
      5,
    );

    add(
      'swift',
      RegExp(
        r'import\s+(SwiftUI|UIKit|Foundation)|@State\s+var|func\s+\w+\(.*\)\s*->',
      ),
      6,
    );

    add('go', RegExp(r'package\s+main|func\s+main\(\)|fmt\.Print|:='), 6);
    add(
      'rust',
      RegExp(r'\bfn\s+\w+\(|let\s+mut\s+|println!|\bimpl\s+\w+'),
      6,
    );

    add(
      'sql',
      RegExp(
        r'\b(SELECT|INSERT\s+INTO|UPDATE\s+\w+\s+SET|DELETE\s+FROM|CREATE\s+TABLE)\b',
        caseSensitive: false,
      ),
      5,
    );
    add(
      'sql',
      RegExp(
        r'\b(FROM|WHERE|INNER\s+JOIN|LEFT\s+JOIN|ORDER\s+BY|GROUP\s+BY)\b',
        caseSensitive: false,
      ),
      3,
    );

    add(
      'css',
      RegExp(
        r'(display|background-color|border-radius|font-size|margin|padding|@media)\s*:',
      ),
      4,
    );
    add(
      'css',
      RegExp(r'[.#]?[a-zA-Z0-9_-]+\s*\{[^}]*:[^}]*\}', dotAll: true),
      3,
    );

    add(
      'bash',
      RegExp(
        r'^#!/bin/(ba)?sh|\b(sudo|chmod|chown|grep|awk|apt-get|flutter\s+build)\b',
        multiLine: true,
      ),
      5,
    );
    add(
      'bash',
      RegExp(r'^\s*(echo|export|mkdir|cp|rm)\s+', multiLine: true),
      3,
    );

    add(
      'yaml',
      RegExp(
        r'^[a-zA-Z0-9_-]+:\s*$\n^\s{2,}[a-zA-Z0-9_-]+:',
        multiLine: true,
      ),
      5,
    );

    add('markdown', RegExp(r'^(#{1,3}\s+\S+|```)', multiLine: true), 3);

    String bestId = '';
    int bestScore = 0;
    scores.forEach((id, score) {
      if (score > bestScore) {
        bestScore = score;
        bestId = id;
      }
    });

    if (bestScore >= 4) {
      return getLanguageById(bestId);
    }
    return null;
  }
}

class _StyledSegment {
  int start;
  int end;
  final TextStyle style;
  _StyledSegment(this.start, this.end, this.style);
}

class CodeSyntaxTextController extends TextEditingController {
  bool syntaxEnabled;
  bool isDarkTheme;
  String languageId;
  List<TextRange> searchMatches = const [];
  int activeMatchIndex = -1;

  // نافذة التلوين المرئية للملفات الضخمة (> 24000 حرف)
  int highlightWindowStart = 0;
  int highlightWindowEnd = 16000;

  String? _cachedText;
  bool? _cachedSyntax;
  bool? _cachedIsDark;
  String? _cachedLangId;
  TextStyle? _cachedBaseStyle;
  int? _cachedWinStart;
  int? _cachedWinEnd;
  List<_StyledSegment>? _cachedSegments;

  CodeSyntaxTextController({
    super.text,
    this.syntaxEnabled = false,
    this.isDarkTheme = true,
    this.languageId = 'dart',
  });

  void updateHighlightWindow(int start, int end, {bool notify = true}) {
    final len = text.length;
    final s = start.clamp(0, len);
    final e = end.clamp(s, len);
    if (s == highlightWindowStart && e == highlightWindowEnd) return;
    highlightWindowStart = s;
    highlightWindowEnd = e;
    if (notify) notifyListeners();
  }

  static const Set<String> _keywords = {
    'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch',
    'class', 'companion', 'const', 'continue', 'data', 'default', 'def',
    'defer', 'delete', 'do', 'elif', 'else', 'enum', 'except', 'export',
    'extends', 'extension', 'false', 'final', 'finally', 'fn', 'for', 'from',
    'fun', 'func', 'function', 'if', 'impl', 'implements', 'import', 'in',
    'init', 'interface', 'is', 'late', 'let', 'match', 'mut', 'namespace',
    'new', 'nil', 'None', 'null', 'object', 'on', 'override', 'package',
    'pass', 'print', 'println', 'private', 'protected', 'public', 'raise',
    'readonly', 'required', 'return', 'sealed', 'self', 'static', 'struct',
    'super', 'switch', 'this', 'throw', 'throws', 'true', 'True', 'False',
    'try', 'type', 'typedef', 'using', 'val', 'var', 'void', 'while', 'with',
    'yield', 'SELECT', 'FROM', 'WHERE', 'INSERT', 'INTO', 'VALUES', 'UPDATE',
    'SET', 'DELETE', 'CREATE', 'TABLE', 'JOIN', 'ON', 'AND', 'OR', 'NOT',
    'select', 'where', 'insert', 'into', 'values', 'update', 'set',
    'create', 'table', 'join', 'and', 'or', 'not',
  };

  static bool _isDigit(int c) => c >= 48 && c <= 57;
  static bool _isUpper(int c) => c >= 65 && c <= 90;
  static bool _isLower(int c) => c >= 97 && c <= 122;
  static bool _isIdentStart(int c) => _isUpper(c) || _isLower(c) || c == 95;
  static bool _isIdentChar(int c) => _isIdentStart(c) || _isDigit(c);
  static bool _isTagChar(int c) =>
      _isIdentChar(c) || c == 58 || c == 45 || c == 47 || c == 33 || c == 63;
  static bool _isNumChar(int c) =>
      _isDigit(c) ||
      c == 46 ||
      c == 95 ||
      c == 120 ||
      c == 88 ||
      (c >= 65 && c <= 70) ||
      (c >= 97 && c <= 102);

  static bool _isOperator(int c) {
    switch (c) {
      case 123: // {
      case 125: // }
      case 40: // (
      case 41: // )
      case 91: // [
      case 93: // ]
      case 61: // =
      case 62: // >
      case 60: // <
      case 43: // +
      case 45: // -
      case 42: // *
      case 47: // /
      case 38: // &
      case 124: // |
      case 33: // !
      case 58: // :
      case 59: // ;
      case 46: // .
      case 44: // ,
      case 63: // ?
        return true;
      default:
        return false;
    }
  }

  void _pushSeg(List<_StyledSegment> segs, int start, int end, TextStyle style) {
    if (end <= start) return;
    if (segs.isNotEmpty && segs.last.style == style && segs.last.end == start) {
      segs.last.end = end;
    } else {
      segs.add(_StyledSegment(start, end, style));
    }
  }

  List<_StyledSegment> _buildWindowedSegments(
    String src,
    TextStyle base,
    int winStart,
    int winEnd,
  ) {
    if (_cachedSegments != null &&
        _cachedText == src &&
        _cachedSyntax == syntaxEnabled &&
        _cachedIsDark == isDarkTheme &&
        _cachedLangId == languageId &&
        _cachedBaseStyle == base &&
        _cachedWinStart == winStart &&
        _cachedWinEnd == winEnd) {
      return _cachedSegments!;
    }

    final List<_StyledSegment> segs = [];

    if (winStart > 0) {
      _pushSeg(segs, 0, winStart, base);
    }

    if (!syntaxEnabled) {
      // نفحص الروابط فقط في النصوص المعقولة أو داخل النافذة المرئية
      final slice = src.substring(winStart, winEnd);
      final links = LinkDetector.extractLinks(slice, unique: false);
      if (links.isEmpty) {
        _pushSeg(segs, winStart, winEnd, base);
      } else {
        final Color linkColor =
            isDarkTheme ? const Color(0xFF7CC4FF) : const Color(0xFF1D4ED8);
        final linkStyle = base.copyWith(
          color: linkColor,
          decoration: TextDecoration.underline,
          decorationColor: linkColor,
        );
        int pos = 0;
        for (final link in links) {
          if (link.start > pos) {
            _pushSeg(segs, winStart + pos, winStart + link.start, base);
          }
          _pushSeg(segs, winStart + link.start, winStart + link.end, linkStyle);
          pos = link.end;
        }
        if (pos < slice.length) {
          _pushSeg(segs, winStart + pos, winEnd, base);
        }
      }
    } else {
      final TextStyle kwStyle = base.copyWith(
        color: isDarkTheme ? const Color(0xFFC792EA) : const Color(0xFF7C3AED),
        fontWeight: FontWeight.bold,
      );
      final TextStyle typeStyle = base.copyWith(
        color: isDarkTheme ? const Color(0xFF82AAFF) : const Color(0xFF1D4ED8),
      );
      final TextStyle strStyle = base.copyWith(
        color: isDarkTheme ? const Color(0xFFC3E88D) : const Color(0xFF15803D),
      );
      final TextStyle commentStyle = base.copyWith(
        color: isDarkTheme ? const Color(0xFF737B8C) : const Color(0xFF6B7280),
        fontStyle: FontStyle.italic,
      );
      final TextStyle numStyle = base.copyWith(
        color: isDarkTheme ? const Color(0xFFF78C6C) : const Color(0xFFC2410C),
      );
      final TextStyle tagStyle = base.copyWith(
        color: isDarkTheme ? const Color(0xFFFFCB6B) : const Color(0xFFB45309),
        fontWeight: FontWeight.w600,
      );
      final TextStyle opStyle = base.copyWith(
        color: isDarkTheme ? const Color(0xFF89DDFF) : const Color(0xFF0369A1),
      );

      final bool hashCommentLang =
          languageId == 'python' || languageId == 'yaml' || languageId == 'bash';
      final bool tagLang = languageId == 'html' || languageId == 'xml';
      int i = winStart;

      while (i < winEnd) {
        final int c = src.codeUnitAt(i);

        // 1. تعليقات السطر الواحد
        if ((c == 47 && i + 1 < winEnd && src.codeUnitAt(i + 1) == 47) ||
            (c == 45 &&
                i + 1 < winEnd &&
                src.codeUnitAt(i + 1) == 45 &&
                languageId == 'sql') ||
            (c == 35 && hashCommentLang)) {
          final int nl = src.indexOf('\n', i);
          final int end = (nl == -1 || nl > winEnd) ? winEnd : nl;
          _pushSeg(segs, i, end, commentStyle);
          i = end;
          continue;
        }

        // 2. تعليقات متعددة الأسطر /* ... */
        if (c == 47 && i + 1 < winEnd && src.codeUnitAt(i + 1) == 42) {
          final int close = src.indexOf('*/', i + 2);
          final int end =
              (close == -1 || close + 2 > winEnd) ? winEnd : close + 2;
          _pushSeg(segs, i, end, commentStyle);
          i = end;
          continue;
        }

        // 3. النصوص " ' `
        if (c == 34 || c == 39 || c == 96) {
          int j = i + 1;
          while (j < winEnd) {
            final int cj = src.codeUnitAt(j);
            if (cj == 92 && j + 1 < winEnd) {
              j += 2;
              continue;
            }
            if (cj == c) {
              j++;
              break;
            }
            if (cj == 10) break;
            j++;
          }
          _pushSeg(segs, i, j, strStyle);
          i = j;
          continue;
        }

        // 4. @ أو #include
        if (c == 64 || (c == 35 && !hashCommentLang)) {
          int j = i + 1;
          while (j < winEnd && _isIdentChar(src.codeUnitAt(j))) {
            j++;
          }
          _pushSeg(segs, i, j, tagStyle);
          i = j;
          continue;
        }

        // 5. وسوم HTML/XML
        if (c == 60 && tagLang && i + 1 < winEnd) {
          final int next = src.codeUnitAt(i + 1);
          if (_isUpper(next) ||
              _isLower(next) ||
              next == 47 ||
              next == 33 ||
              next == 63) {
            int j = i + 1;
            while (j < winEnd && _isTagChar(src.codeUnitAt(j))) {
              j++;
            }
            _pushSeg(segs, i, j, tagStyle);
            i = j;
            continue;
          }
        }

        // 6. الأرقام
        if (_isDigit(c)) {
          int j = i + 1;
          while (j < winEnd && _isNumChar(src.codeUnitAt(j))) {
            j++;
          }
          _pushSeg(segs, i, j, numStyle);
          i = j;
          continue;
        }

        // 7. الكلمات المفتاحية والأنواع
        if (_isIdentStart(c)) {
          int j = i + 1;
          while (j < winEnd && _isIdentChar(src.codeUnitAt(j))) {
            j++;
          }
          final word = src.substring(i, j);
          if (_keywords.contains(word)) {
            _pushSeg(segs, i, j, kwStyle);
          } else if (_isUpper(c)) {
            _pushSeg(segs, i, j, typeStyle);
          } else {
            _pushSeg(segs, i, j, base);
          }
          i = j;
          continue;
        }

        // 8. الأقواس والعمليات
        if (_isOperator(c)) {
          _pushSeg(segs, i, i + 1, opStyle);
          i++;
          continue;
        }

        // 9. بقية المحارف المتجاورة دفعة واحدة
        int j = i + 1;
        while (j < winEnd) {
          final int cj = src.codeUnitAt(j);
          if (_isIdentStart(cj) ||
              _isDigit(cj) ||
              _isOperator(cj) ||
              cj == 34 ||
              cj == 39 ||
              cj == 96 ||
              cj == 64 ||
              cj == 35) {
            break;
          }
          j++;
        }
        _pushSeg(segs, i, j, base);
        i = j;
      }
    }

    if (winEnd < src.length) {
      _pushSeg(segs, winEnd, src.length, base);
    }

    _cachedText = src;
    _cachedSyntax = syntaxEnabled;
    _cachedIsDark = isDarkTheme;
    _cachedLangId = languageId;
    _cachedBaseStyle = base;
    _cachedWinStart = winStart;
    _cachedWinEnd = winEnd;
    _cachedSegments = segs;
    return segs;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (text.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final int len = text.length;
    final base = style ?? const TextStyle(fontSize: 14);

    // تحديد النافذة المرئية: كامل الملف إن كان <= 24000 حرف، أو النافذة النشطة للملفات الضخمة
    int winStart = 0;
    int winEnd = len;
    if (len > 24000) {
      int s = highlightWindowStart.clamp(0, len);
      int e = highlightWindowEnd.clamp(s, len);
      if (s > 0) {
        final prevNl = text.lastIndexOf('\n', s);
        s = prevNl == -1 ? 0 : prevNl + 1;
      }
      if (e < len) {
        final nextNl = text.indexOf('\n', e);
        e = nextNl == -1 ? len : nextNl;
      }
      winStart = s;
      winEnd = math.max(s, e);
    }

    if (!syntaxEnabled && searchMatches.isEmpty && len > 24000) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final segments = _buildWindowedSegments(text, base, winStart, winEnd);
    if (searchMatches.isEmpty) {
      return TextSpan(
        style: base,
        children: segments
            .map(
              (s) => TextSpan(text: text.substring(s.start, s.end), style: s.style),
            )
            .toList(),
      );
    }

    // تظليل نتائج البحث الموجودة داخل النافذة المرئية فقط للملفات الكبيرة (للحفاظ على سرعة 60fps)
    final Color otherBg =
        isDarkTheme ? const Color(0x55FBBF24) : const Color(0x55F59E0B);
    const Color activeBg = Color(0xFFF59E0B);

    final List<InlineSpan> spans = [];
    int matchPtr = 0;

    // تجاوز سريع للنتائج السابقة للنافذة إذا كان الملف كبيراً
    if (len > 24000 && searchMatches.isNotEmpty) {
      int lo = 0;
      int hi = searchMatches.length - 1;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (searchMatches[mid].end <= winStart) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      matchPtr = lo;
    }

    for (final seg in segments) {
      if (len > 24000 && (seg.end <= winStart || seg.start >= winEnd)) {
        spans.add(
          TextSpan(text: text.substring(seg.start, seg.end), style: seg.style),
        );
        continue;
      }

      int pos = seg.start;
      while (matchPtr < searchMatches.length &&
          searchMatches[matchPtr].end <= pos) {
        matchPtr++;
      }

      int ptr = matchPtr;
      while (ptr < searchMatches.length && searchMatches[ptr].start < seg.end) {
        final m = searchMatches[ptr];
        final int ovStart = m.start > pos ? m.start : pos;
        final int ovEnd = m.end < seg.end ? m.end : seg.end;

        if (ovStart > pos) {
          spans.add(
            TextSpan(text: text.substring(pos, ovStart), style: seg.style),
          );
        }
        if (ovEnd > ovStart) {
          final bool isActive = ptr == activeMatchIndex;
          spans.add(
            TextSpan(
              text: text.substring(ovStart, ovEnd),
              style: seg.style.copyWith(
                backgroundColor: isActive ? activeBg : otherBg,
                color: isActive ? Colors.black : seg.style.color,
                fontWeight: isActive ? FontWeight.bold : seg.style.fontWeight,
              ),
            ),
          );
          pos = ovEnd;
        }
        if (m.end <= seg.end) {
          ptr++;
        } else {
          break;
        }
      }

      if (pos < seg.end) {
        spans.add(TextSpan(text: text.substring(pos, seg.end), style: seg.style));
      }
    }

    return TextSpan(style: base, children: spans);
  }
}
