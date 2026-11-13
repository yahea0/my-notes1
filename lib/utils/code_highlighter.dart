import 'package:flutter/material.dart';

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
    final text = raw.trim();
    if (text.length < 10) return null;

    // تجنب الخلط مع النصوص العربية العادية الخالية من تراكيب البرمجة
    final int arabicChars =
        RegExp(r'[\u0600-\u06FF]').allMatches(text).length;
    final bool hasCodePunctuation =
        RegExp(r'[{};=<>\[\]()]|def\s|SELECT\s|import\s|#!/').hasMatch(text);
    if (!hasCodePunctuation && arabicChars > text.length * 0.35) {
      return null;
    }

    // 1. JSON
    if ((text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']'))) {
      if (RegExp(r'"[^"]+"\s*:').hasMatch(text)) {
        return getLanguageById('json');
      }
    }

    // 2. HTML & XML
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

    // 3. PHP
    if (text.contains('<?php') ||
        (RegExp(r'\$[a-zA-Z_]\w*').hasMatch(text) && text.contains('->'))) {
      return getLanguageById('php');
    }

    final Map<String, int> scores = {
      for (final l in kSupportedCodeLanguages) l.id: 0,
    };

    void add(String id, RegExp pattern, int weight) {
      if (pattern.hasMatch(text)) {
        scores[id] = (scores[id] ?? 0) + weight;
      }
    }

    // Dart / Flutter
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

    // Python
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

    // TypeScript & JavaScript
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

    // Kotlin
    add(
      'kotlin',
      RegExp(r'\b(fun\s+\w+|override\s+fun|companion\s+object|data\s+class)\b'),
      5,
    );
    add('kotlin', RegExp(r'\b(val|var)\s+\w+\s*[:=]'), 3);
    add('kotlin', RegExp(r'\bprintln\('), 2);

    // Java
    add(
      'java',
      RegExp(r'public\s+static\s+void\s+main|System\.out\.println'),
      6,
    );
    add('java', RegExp(r'\b(public|private|protected)\s+class\s+\w+'), 4);

    // C++ / C / C#
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

    // Swift
    add(
      'swift',
      RegExp(
        r'import\s+(SwiftUI|UIKit|Foundation)|@State\s+var|func\s+\w+\(.*\)\s*->',
      ),
      6,
    );

    // Go
    add('go', RegExp(r'package\s+main|func\s+main\(\)|fmt\.Print|:='), 6);

    // Rust
    add(
      'rust',
      RegExp(r'\bfn\s+\w+\(|let\s+mut\s+|println!|\bimpl\s+\w+'),
      6,
    );

    // SQL
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

    // CSS
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

    // Bash / Shell
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

    // YAML
    add(
      'yaml',
      RegExp(
        r'^[a-zA-Z0-9_-]+:\s*$\n^\s{2,}[a-zA-Z0-9_-]+:',
        multiLine: true,
      ),
      5,
    );

    // Markdown
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

class CodeSyntaxTextController extends TextEditingController {
  bool syntaxEnabled;
  bool isDarkTheme;
  String languageId;

  CodeSyntaxTextController({
    super.text,
    this.syntaxEnabled = false,
    this.isDarkTheme = true,
    this.languageId = 'dart',
  });

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

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (!syntaxEnabled || text.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final base = style ?? const TextStyle(fontSize: 14);
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

    final List<InlineSpan> spans = [];
    final int len = text.length;
    int i = 0;

    final bool hashCommentLang =
        languageId == 'python' || languageId == 'yaml' || languageId == 'bash';

    void addSpan(int start, int end, TextStyle spanStyle) {
      if (end <= start) return;
      final sub = text.substring(start, end);
      if (withComposing &&
          value.composing.isValid &&
          !value.composing.isCollapsed &&
          start < value.composing.end &&
          end > value.composing.start) {
        spans.add(
          TextSpan(
            text: sub,
            style: spanStyle.copyWith(decoration: TextDecoration.underline),
          ),
        );
      } else {
        spans.add(TextSpan(text: sub, style: spanStyle));
      }
    }

    while (i < len) {
      final String ch = text[i];

      // 1. تعليقات السطر الواحد
      if ((ch == '/' && i + 1 < len && text[i + 1] == '/') ||
          (ch == '-' &&
              i + 1 < len &&
              text[i + 1] == '-' &&
              languageId == 'sql') ||
          (ch == '#' && hashCommentLang)) {
        final int nl = text.indexOf('\n', i);
        final int end = nl == -1 ? len : nl;
        addSpan(
          i,
          end,
          base.copyWith(color: commentColor, fontStyle: FontStyle.italic),
        );
        i = end;
        continue;
      }

      // 2. تعليقات متعددة الأسطر /* ... */
      if (ch == '/' && i + 1 < len && text[i + 1] == '*') {
        final int close = text.indexOf('*/', i + 2);
        final int end = close == -1 ? len : close + 2;
        addSpan(
          i,
          end,
          base.copyWith(color: commentColor, fontStyle: FontStyle.italic),
        );
        i = end;
        continue;
      }

      // 3. النصوص " ' `
      if (ch == '"' || ch == "'" || ch == '`') {
        int j = i + 1;
        while (j < len) {
          if (text[j] == '\\' && j + 1 < len) {
            j += 2;
            continue;
          }
          if (text[j] == ch) {
            j++;
            break;
          }
          if (text[j] == '\n') break;
          j++;
        }
        addSpan(i, j, base.copyWith(color: strColor));
        i = j;
        continue;
      }

      // 4. الوسوم والتوجيهات (@override, #include)
      if (ch == '@' || (ch == '#' && !hashCommentLang)) {
        int j = i + 1;
        while (j < len && RegExp(r'[a-zA-Z0-9_]').hasMatch(text[j])) {
          j++;
        }
        addSpan(
          i,
          j,
          base.copyWith(color: tagColor, fontWeight: FontWeight.w600),
        );
        i = j;
        continue;
      }

      // 5. وسوم HTML / XML
      if (ch == '<' &&
          (languageId == 'html' || languageId == 'xml') &&
          i + 1 < len &&
          RegExp(r'[a-zA-Z/!?]').hasMatch(text[i + 1])) {
        int j = i + 1;
        while (j < len && RegExp(r'[a-zA-Z0-9_:!?/-]').hasMatch(text[j])) {
          j++;
        }
        addSpan(
          i,
          j,
          base.copyWith(color: tagColor, fontWeight: FontWeight.w600),
        );
        i = j;
        continue;
      }

      // 6. الأرقام
      if (RegExp(r'[0-9]').hasMatch(ch)) {
        int j = i + 1;
        while (j < len && RegExp(r'[0-9.xXa-fA-F_]').hasMatch(text[j])) {
          j++;
        }
        addSpan(i, j, base.copyWith(color: numColor));
        i = j;
        continue;
      }

      // 7. الكلمات والمُعرّفات
      if (RegExp(r'[a-zA-Z_]').hasMatch(ch)) {
        int j = i + 1;
        while (j < len && RegExp(r'[a-zA-Z0-9_]').hasMatch(text[j])) {
          j++;
        }
        final word = text.substring(i, j);
        if (_keywords.contains(word)) {
          addSpan(
            i,
            j,
            base.copyWith(color: kwColor, fontWeight: FontWeight.bold),
          );
        } else if (word.isNotEmpty &&
            word[0].toUpperCase() == word[0] &&
            word[0] != '_') {
          addSpan(i, j, base.copyWith(color: typeColor));
        } else {
          addSpan(i, j, base);
        }
        i = j;
        continue;
      }

      // 8. الأقواس والرموز البرمجية
      if (RegExp(r'[{}()\[\]=><+\-*/&|!:;.,?]').hasMatch(ch)) {
        addSpan(i, i + 1, base.copyWith(color: opColor));
        i++;
        continue;
      }

      // 9. أي محارف أخرى
      int j = i + 1;
      while (j < len &&
          !RegExp(r'''[a-zA-Z0-9_"'`@#/<>{}()\[\]=+\-*&|!:;.,?-]''')
              .hasMatch(text[j])) {
        j++;
      }
      addSpan(i, j, base);
      i = j;
    }

    return TextSpan(style: base, children: spans);
  }
}
