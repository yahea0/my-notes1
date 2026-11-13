import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

const List<Map<String, String>> kOnyxFonts = [
  {'id': 'Tahoma', 'name': 'افتراضي'},
  {'id': 'Cairo', 'name': 'القاهرة'},
  {'id': 'Amiri', 'name': 'أميري (نسخ)'},
  {'id': 'Aref Ruqaa', 'name': 'عارف رقعة'},
  {'id': 'Reem Kufi', 'name': 'ريم كوفي'},
  {'id': 'Lateef', 'name': 'لطيف (يدوي)'},
  {'id': 'Scheherazade New', 'name': 'شهرزاد'},
  {'id': 'Tajawal', 'name': 'تجوال'},
  {'id': 'Almarai', 'name': 'المراعي'},
  {'id': 'Noto Naskh Arabic', 'name': 'نوتو نسخ'},
  {'id': 'El Messiri', 'name': 'المسيري'},
  {'id': 'Changa', 'name': 'تشانغا'},
];

TextStyle applyArabicFont(String fontId, TextStyle base) {
  try {
    switch (fontId) {
      case 'Cairo':
        return GoogleFonts.cairo(textStyle: base);
      case 'Amiri':
        return GoogleFonts.amiri(textStyle: base);
      case 'Tajawal':
        return GoogleFonts.tajawal(textStyle: base);
      case 'Almarai':
        return GoogleFonts.almarai(textStyle: base);
      case 'Noto Naskh Arabic':
        return GoogleFonts.notoNaskhArabic(textStyle: base);
      case 'Reem Kufi':
        return GoogleFonts.reemKufi(textStyle: base);
      case 'El Messiri':
        return GoogleFonts.elMessiri(textStyle: base);
      case 'Markazi Text':
        return GoogleFonts.markaziText(textStyle: base);
      case 'Changa':
        return GoogleFonts.changa(textStyle: base);
      case 'Aref Ruqaa':
        return GoogleFonts.arefRuqaa(textStyle: base);
      case 'Lateef':
        return GoogleFonts.lateef(textStyle: base);
      case 'Scheherazade New':
        return GoogleFonts.scheherazadeNew(textStyle: base);
      default:
        return base;
    }
  } catch (_) {
    return base;
  }
}

class OnyxPalette {
  final bool isDark;
  final Color scaffoldBg;
  final Color voidBg;
  final Color elevatedBg;
  final Color cardTop;
  final Color cardBottom;
  final Color glassHighlight;
  final Color glassBorder;
  final Color glassStrongBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color onAccent;
  final Color shadowDeep;
  final Color shadowSoft;
  final Color chipBg;
  final Color divider;
  final Color inputFill;
  final Color danger;

  const OnyxPalette({
    required this.isDark,
    required this.scaffoldBg,
    required this.voidBg,
    required this.elevatedBg,
    required this.cardTop,
    required this.cardBottom,
    required this.glassHighlight,
    required this.glassBorder,
    required this.glassStrongBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.shadowDeep,
    required this.shadowSoft,
    required this.chipBg,
    required this.divider,
    required this.inputFill,
    required this.danger,
  });

  factory OnyxPalette.of(bool isDark) {
    if (isDark) {
      return OnyxPalette(
        isDark: true,
        scaffoldBg: const Color(0xFF070709),
        voidBg: const Color(0xFF030304),
        elevatedBg: const Color(0xFF121318),
        cardTop: Colors.white.withOpacity(0.11),
        cardBottom: Colors.white.withOpacity(0.025),
        glassHighlight: Colors.white.withOpacity(0.24),
        glassBorder: Colors.white.withOpacity(0.14),
        glassStrongBorder: Colors.white.withOpacity(0.32),
        textPrimary: Colors.white,
        textSecondary: Colors.white.withOpacity(0.78),
        textMuted: Colors.white.withOpacity(0.46),
        accent: Colors.white,
        onAccent: const Color(0xFF08080A),
        shadowDeep: Colors.black.withOpacity(0.82),
        shadowSoft: Colors.white.withOpacity(0.07),
        chipBg: Colors.white.withOpacity(0.08),
        divider: Colors.white.withOpacity(0.10),
        inputFill: Colors.white.withOpacity(0.05),
        danger: const Color(0xFFFF5C6C),
      );
    }

    return OnyxPalette(
      isDark: false,
      scaffoldBg: const Color(0xFFF3F4F7),
      voidBg: const Color(0xFFE7E9EF),
      elevatedBg: Colors.white,
      cardTop: Colors.white.withOpacity(0.95),
      cardBottom: const Color(0xFFE9EBF2).withOpacity(0.76),
      glassHighlight: Colors.white,
      glassBorder: Colors.black.withOpacity(0.10),
      glassStrongBorder: Colors.black.withOpacity(0.24),
      textPrimary: const Color(0xFF0B0B0E),
      textSecondary: const Color(0xFF3A3B42),
      textMuted: const Color(0xFF6B6E79),
      accent: const Color(0xFF0B0B0E),
      onAccent: Colors.white,
      shadowDeep: const Color(0xFF10121A).withOpacity(0.14),
      shadowSoft: Colors.white.withOpacity(0.92),
      chipBg: Colors.black.withOpacity(0.06),
      divider: Colors.black.withOpacity(0.08),
      inputFill: Colors.black.withOpacity(0.045),
      danger: const Color(0xFFD92D3E),
    );
  }
}

Color resolveAdaptiveNoteColor(
  int? rawColor,
  OnyxPalette pal, {
  bool isContent = false,
}) {
  if (rawColor == null) {
    return isContent ? pal.textPrimary.withOpacity(0.88) : pal.textPrimary;
  }
  final int whiteVal = Colors.white.value;
  final int blackVal = Colors.black.value;
  if (!pal.isDark && rawColor == whiteVal) {
    return isContent ? pal.textPrimary.withOpacity(0.88) : pal.textPrimary;
  }
  if (pal.isDark && (rawColor == blackVal || rawColor == 0xFF0B0B0E)) {
    return isContent ? pal.textPrimary.withOpacity(0.88) : pal.textPrimary;
  }
  return Color(rawColor);
}

class OnyxSettings {
  static Box get _box => Hive.box('settings');

  static bool get isDark => _box.get('isDark', defaultValue: true) as bool;
  static Future<void> setIsDark(bool val) => _box.put('isDark', val);

  static bool get enable3D => _box.get('enable3D', defaultValue: true) as bool;
  static Future<void> setEnable3D(bool val) => _box.put('enable3D', val);

  static bool get enableShimmer =>
      _box.get('enableShimmer', defaultValue: true) as bool;
  static Future<void> setEnableShimmer(bool val) =>
      _box.put('enableShimmer', val);

  static double get blurSigma =>
      (_box.get('blurSigma', defaultValue: 16.0) as num).toDouble();
  static Future<void> setBlurSigma(double val) => _box.put('blurSigma', val);

  static bool get isGridView =>
      _box.get('isGridView', defaultValue: false) as bool;
  static Future<void> setIsGridView(bool val) => _box.put('isGridView', val);

  static String get sortMode =>
      _box.get('sortMode', defaultValue: 'pinned_newest') as String;
  static Future<void> setSortMode(String val) => _box.put('sortMode', val);

  static String get vaultPin =>
      _box.get('vaultPin', defaultValue: '1234') as String;
  static Future<void> setVaultPin(String val) => _box.put('vaultPin', val);

  static bool get hideLocked =>
      _box.get('hideLocked', defaultValue: true) as bool;
  static Future<void> setHideLocked(bool val) => _box.put('hideLocked', val);

  static bool get useTrash =>
      _box.get('useTrash', defaultValue: true) as bool;
  static Future<void> setUseTrash(bool val) => _box.put('useTrash', val);

  static bool get confirmOnExit =>
      _box.get('confirmOnExit', defaultValue: true) as bool;
  static Future<void> setConfirmOnExit(bool val) =>
      _box.put('confirmOnExit', val);

  static bool get appLockEnabled =>
      _box.get('appLockEnabled', defaultValue: false) as bool;
  static Future<void> setAppLockEnabled(bool val) =>
      _box.put('appLockEnabled', val);

  static String get defaultFont =>
      _box.get('defaultFont', defaultValue: 'Tahoma') as String;
  static Future<void> setDefaultFont(String val) =>
      _box.put('defaultFont', val);

  static double get defaultContentSize =>
      (_box.get('defaultContentSize', defaultValue: 16.0) as num).toDouble();
  static Future<void> setDefaultContentSize(double val) =>
      _box.put('defaultContentSize', val);
}
