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

    // فحص عينة سريعة فقط (أول 6000 حرف) لضمان سرعة O(1) حتى في 50,000 سطر
    final String sample =
        trimmed.length > 6000 ? trimmed.substring(0, 6000) : trimmed;

    final int arabicChars =
        RegExp(r'[\u0600-\u06FF]').allMatches(sample).length;
    final bool hasGuideWords =
        RegExp(r'(الخطوة|ملف|ملاحظة|قم ب|استبدل|أنشئ)').hasMatch(sample);

    // إذا كان النص شرحاً عربياً مختلطاً، نبقيه كملاحظة عادية واضحة إلا إذا فعّل المستخدم وضع الكود يدوياً
    if (arabicChars > sample.length * 0.14 ||
        (hasGuideWords && arabicChars > 25)) {
      return null;
    }

    final textWithoutLinks =
        sample.replaceAll(LinkDetector.urlRegex, '').trim();
    if (textWithoutLinks.length < 8) return null;

    if ((sample.startsWith('{') && sample.endsWith('}')) ||
        (sample.startsWith('[') && sample.endsWith(']'))) {
      if (RegExp(r'"[^"]+"\s*:').hasMatch(sample)) {
        return getLanguageById('json');
      }
    }

    if (RegExp(
      r'<!DOCTYPE\s+html|<html[\s>]|<div[\s>]|<script[\s>]|<body[\s>]',
      caseSensitive: false,
    ).hasMatch(sample)) {
      return getLanguageById('html');
    }
    if (RegExp(r'<\?xml|xmlns:|<manifest[\s>]|<application[\s>]')
        .hasMatch(sample)) {
      return getLanguageById('xml');
    }

    if (sample.contains('<?php') ||
        (RegExp(r'\$[a-zA-Z_]\w*').hasMatch(sample) &&
            sample.contains('->'))) {
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

class FastCodeTokenizer {
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

  static bool _isAlpha(int c) =>
      (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95;
  static bool _isDigit(int c) => c >= 48 && c <= 57;
  static bool _isAlnum(int c) => _isAlpha(c) || _isDigit(c);
  static bool _isHexOrNum(int c) =>
      _isDigit(c) ||
      c == 46 ||
      c == 120 ||
      c == 88 ||
      c == 95 ||
      (c >= 97 && c <= 102) ||
      (c >= 65 && c <= 70);
  static bool _isUpper(int c) => c >= 65 && c <= 90;
  static bool _isOp(int c) =>
      c == 123 ||
      c == 125 ||
      c == 40 ||
      c == 41 ||
      c == 91 ||
      c == 93 ||
      c == 61 ||
      c == 62 ||
      c == 60 ||
      c == 43 ||
      c == 45 ||
      c == 42 ||
      c == 47 ||
      c == 38 ||
      c == 124 ||
      c == 33 ||
      c == 58 ||
      c == 59 ||
      c == 46 ||
      c == 44 ||
      c == 63;

  static List<InlineSpan> tokenizeChunk(
    String text, {
    required String languageId,
    required bool isDarkTheme,
    required TextStyle baseStyle,
  }) {
    if (text.isEmpty) return const [];

    final Color kwColor =
        isDarkTheme ? const Color(0xFFC792EA) : const Color(0xFF7C3AED);
    final Color typeColor =
        isDarkTheme ? const Color(0xFF82AAFF) : const Color(0xFF1D4ED8);
    final Color strColor =
        isDarkTheme ? const Color(0xFFC3E88D) : const Color(0xFF15803D);
    final Color commentColor =
        isDarkTheme ? const Color(0xFF737B8C) : const Color(0xFF6B7280);
    final Color numColor =
        isDarkTheme ? const Color(0xFFF78C6C) : const Color(0xFFC2410C);
    final Color tagColor =
        isDarkTheme ? const Color(0xFFFFCB6B) : const Color(0xFFB45309);
    final Color opColor =
        isDarkTheme ? const Color(0xFF89DDFF) : const Color(0xFF0369A1);

    final TextStyle kwStyle =
        baseStyle.copyWith(color: kwColor, fontWeight: FontWeight.bold);
    final TextStyle typeStyle = baseStyle.copyWith(color: typeColor);
    final TextStyle strStyle = baseStyle.copyWith(color: strColor);
    final TextStyle commentStyle =
        baseStyle.copyWith(color: commentColor, fontStyle: FontStyle.italic);
    final TextStyle numStyle = baseStyle.copyWith(color: numColor);
    final TextStyle tagStyle =
        baseStyle.copyWith(color: tagColor, fontWeight: FontWeight.w600);
    final TextStyle opStyle = baseStyle.copyWith(color: opColor);

    final bool hashCommentLang =
        languageId == 'python' || languageId == 'yaml' || languageId == 'bash';
    final bool isMarkup = languageId == 'html' || languageId == 'xml';

    final List<InlineSpan> spans = [];
    final int len = text.length;
    int i = 0;
    final StringBuffer plainBuf = StringBuffer();

    void flushPlain() {
      if (plainBuf.isNotEmpty) {
        spans.add(TextSpan(text: plainBuf.toString(), style: baseStyle));
        plainBuf.clear();
      }
    }

    while (i < len) {
      final int c = text.codeUnitAt(i);

      // // أو -- في SQL أو # في Python/YAML/Bash
      if ((c == 47 && i + 1 < len && text.codeUnitAt(i + 1) == 47) ||
          (c == 45 &&
              i + 1 < len &&
              text.codeUnitAt(i + 1) == 45 &&
              languageId == 'sql') ||
          (c == 35 && hashCommentLang)) {
        flushPlain();
        final int nl = text.indexOf('\n', i);
        final int end = nl == -1 ? len : nl;
        spans.add(TextSpan(text: text.substring(i, end), style: commentStyle));
        i = end;
        continue;
      }

      // /* ... */
      if (c == 47 && i + 1 < len && text.codeUnitAt(i + 1) == 42) {
        flushPlain();
        final int close = text.indexOf('*/', i + 2);
        final int end = close == -1 ? len : close + 2;
        spans.add(TextSpan(text: text.substring(i, end), style: commentStyle));
        i = end;
        continue;
      }

      // النصوص " ' `
      if (c == 34 || c == 39 || c == 96) {
        flushPlain();
        int j = i + 1;
        while (j < len) {
          final int cj = text.codeUnitAt(j);
          if (cj == 92 && j + 1 < len) {
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
        spans.add(TextSpan(text: text.substring(i, j), style: strStyle));
        i = j;
        continue;
      }

      // @annotation أو #include
      if (c == 64 || (c == 35 && !hashCommentLang)) {
        flushPlain();
        int j = i + 1;
        while (j < len && _isAlnum(text.codeUnitAt(j))) {
          j++;
        }
        spans.add(TextSpan(text: text.substring(i, j), style: tagStyle));
        i = j;
        continue;
      }

      // وسوم HTML / XML
      if (isMarkup && c == 60 && i + 1 < len) {
        final int next = text.codeUnitAt(i + 1);
        if (_isAlpha(next) || next == 47 || next == 33 || next == 63) {
          flushPlain();
          int j = i + 1;
          while (j < len) {
            final int cj = text.codeUnitAt(j);
            if (_isAlnum(cj) ||
                cj == 47 ||
                cj == 45 ||
                cj == 58 ||
                cj == 33 ||
                cj == 63) {
              j++;
            } else {
              break;
            }
          }
          spans.add(TextSpan(text: text.substring(i, j), style: tagStyle));
          i = j;
          continue;
        }
      }

      // الأرقام
      if (_isDigit(c)) {
        flushPlain();
        int j = i + 1;
        while (j < len && _isHexOrNum(text.codeUnitAt(j))) {
          j++;
        }
        spans.add(TextSpan(text: text.substring(i, j), style: numStyle));
        i = j;
        continue;
      }

      // المعرّفات والكلمات المفتاحية (تدمج الكلمات العادية داخل plainBuf لتقليل عدد العقد)
      if (_isAlpha(c)) {
        int j = i + 1;
        while (j < len && _isAlnum(text.codeUnitAt(j))) {
          j++;
        }
        final word = text.substring(i, j);
        if (_keywords.contains(word)) {
          flushPlain();
          spans.add(TextSpan(text: word, style: kwStyle));
        } else if (_isUpper(word.codeUnitAt(0)) && word.codeUnitAt(0) != 95) {
          flushPlain();
          spans.add(TextSpan(text: word, style: typeStyle));
        } else {
          plainBuf.write(word);
        }
        i = j;
        continue;
      }

      // الرموز المتتابعة تُدمج في Span واحد
      if (_isOp(c)) {
        flushPlain();
        int j = i + 1;
        while (j < len && _isOp(text.codeUnitAt(j))) {
          // توقف إذا بدأ تعليق // أو /*
          if (text.codeUnitAt(j) == 47 &&
              j + 1 < len &&
              (text.codeUnitAt(j + 1) == 47 ||
                  text.codeUnitAt(j + 1) == 42)) {
            break;
          }
          j++;
        }
        spans.add(TextSpan(text: text.substring(i, j), style: opStyle));
        i = j;
        continue;
      }

      // دمج المسافات والنص العربي والأحرف العادية في عقدة واحدة كبيرة
      plainBuf.writeCharCode(c);
      i++;
    }

    flushPlain();
    return spans;
  }
}

class CodeSyntaxTextController extends TextEditingController {
  bool syntaxEnabled;
  bool isDarkTheme;
  String languageId;

  // ذاكرة تخزين مؤقت تمنع إعادة التلوين عند تحريك المؤشر أو سحب التحديد
  String _cachedText = '';
  bool _cachedSyntax = false;
  bool _cachedDark = true;
  String _cachedLang = '';
  int _cachedWinStart = 0;
  int _cachedWinEnd = 0;
  TextStyle? _cachedStyle;
  TextSpan? _cachedSpan;

  static const int _fullHighlightLimit = 18000;
  static const int _windowHalfRadius = 6000;

  CodeSyntaxTextController({
    super.text,
    this.syntaxEnabled = false,
    this.isDarkTheme = true,
    this.languageId = 'dart',
  });

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final len = text.length;
    if (len == 0) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final base = style ?? const TextStyle(fontSize: 14);
    final int cursor = value.selection.isValid
        ? value.selection.baseOffset.clamp(0, len)
        : 0;

    final bool hasActiveComposing = withComposing &&
        value.composing.isValid &&
        !value.composing.isCollapsed;

    // فحص الذاكرة المؤقتة (O(1) عند التمرير وسحب التحديد!)
    if (!hasActiveComposing &&
        _cachedSpan != null &&
        _cachedText == text &&
        _cachedSyntax == syntaxEnabled &&
        _cachedDark == isDarkTheme &&
        _cachedLang == languageId &&
        _cachedStyle == base) {
      if (len <= _fullHighlightLimit ||
          (cursor >= _cachedWinStart && cursor <= _cachedWinEnd)) {
        return _cachedSpan!;
      }
    }

    // في النص العادي: تمييز الروابط فقط (إن لم يكن النص عملاقاً جداً فوق 40 ألف حرف لتسريع التحديد)
    if (!syntaxEnabled) {
      if (len > 40000) {
        return super.buildTextSpan(
          context: context,
          style: style,
          withComposing: withComposing,
        );
      }

      final links = LinkDetector.extractLinks(text, unique: false);
      if (links.isEmpty) {
        return super.buildTextSpan(
          context: context,
          style: style,
          withComposing: withComposing,
        );
      }

      final Color linkColor =
          isDarkTheme ? const Color(0xFF7CC4FF) : const Color(0xFF1D4ED8);
      final List<InlineSpan> spans = [];
      int pos = 0;

      for (final link in links) {
        if (link.start > pos) {
          spans.add(
            TextSpan(text: text.substring(pos, link.start), style: base),
          );
        }
        spans.add(
          TextSpan(
            text: text.substring(link.start, link.end),
            style: base.copyWith(
              color: linkColor,
              decoration: TextDecoration.underline,
              decorationColor: linkColor,
            ),
          ),
        );
        pos = link.end;
      }
      if (pos < len) {
        spans.add(TextSpan(text: text.substring(pos), style: base));
      }

      final built = TextSpan(style: base, children: spans);
      if (!hasActiveComposing) {
        _cachedText = text;
        _cachedSyntax = syntaxEnabled;
        _cachedDark = isDarkTheme;
        _cachedLang = languageId;
        _cachedWinStart = 0;
        _cachedWinEnd = len;
        _cachedStyle = base;
        _cachedSpan = built;
      }
      return built;
    }

    // في وضع الكود البرمجي: تلوين كامل للملفات حتى 18,000 حرف، ونافذة ذكية للملفات الضخمة (مثل 5000+ سطر)
    int winStart = 0;
    int winEnd = len;
    if (len > _fullHighlightLimit) {
      winStart = (cursor - _windowHalfRadius).clamp(0, len);
      winEnd = (cursor + _windowHalfRadius).clamp(0, len);
      if (winStart > 0) {
        final nl = text.lastIndexOf('\n', winStart);
        winStart = nl == -1 ? 0 : nl + 1;
      }
      if (winEnd < len) {
        final nl = text.indexOf('\n', winEnd);
        winEnd = nl == -1 ? len : nl;
      }
    }

    final List<InlineSpan> children = [];
    if (winStart > 0) {
      children.add(TextSpan(text: text.substring(0, winStart), style: base));
    }

    children.addAll(
      FastCodeTokenizer.tokenizeChunk(
        text.substring(winStart, winEnd),
        languageId: languageId,
        isDarkTheme: isDarkTheme,
        baseStyle: base,
      ),
    );

    if (winEnd < len) {
      children.add(TextSpan(text: text.substring(winEnd), style: base));
    }

    final built = TextSpan(style: base, children: children);
    if (!hasActiveComposing) {
      _cachedText = text;
      _cachedSyntax = syntaxEnabled;
      _cachedDark = isDarkTheme;
      _cachedLang = languageId;
      _cachedWinStart = winStart;
      _cachedWinEnd = winEnd;
      _cachedStyle = base;
      _cachedSpan = built;
    }
    return built;
  }
}
