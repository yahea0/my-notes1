import 'package:flutter/material.dart';

class DetectedLink {
  final String rawText;
  final String normalizedUrl;
  final String platformName;
  final String categoryLabel;
  final IconData icon;
  final int start;
  final int end;

  const DetectedLink({
    required this.rawText,
    required this.normalizedUrl,
    required this.platformName,
    required this.categoryLabel,
    required this.icon,
    required this.start,
    required this.end,
  });
}

class LinkDetector {
  static final RegExp urlRegex = RegExp(
    r'''(?:https?:\/\/|www\.|(?:[a-zA-Z0-9-]+\.)*(?:youtube\.com|youtu\.be|tiktok\.com|vm\.tiktok\.com|instagram\.com|facebook\.com|fb\.watch|fb\.com|x\.com|twitter\.com|t\.me|telegram\.me|snapchat\.com|threads\.net|linkedin\.com|reddit\.com|vimeo\.com|dailymotion\.com|github\.com)\/)[^\s\u0600-\u06FF<>"'`]+''',
    caseSensitive: false,
  );

  static String _trimTrailingPunct(String s) {
    return s.replaceAll(RegExp(r'[.,;:!?)\]}]+$'), '');
  }

  static String normalizeUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.toLowerCase().startsWith('http://') ||
        trimmed.toLowerCase().startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  static DetectedLink _classify(String raw, int start, int end) {
    final lower = raw.toLowerCase();
    final url = normalizeUrl(raw);

    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      final isShort = lower.contains('/shorts/');
      return DetectedLink(
        rawText: raw,
        normalizedUrl: url,
        platformName: 'يوتيوب',
        categoryLabel: isShort ? 'فيديو قصير' : 'فيديو',
        icon: Icons.play_circle_filled,
        start: start,
        end: end,
      );
    }
    if (lower.contains('tiktok.com')) {
      return DetectedLink(
        rawText: raw,
        normalizedUrl: url,
        platformName: 'تيك توك',
        categoryLabel: 'فيديو',
        icon: Icons.music_video_rounded,
        start: start,
        end: end,
      );
    }
    if (lower.contains('instagram.com')) {
      final isReel = lower.contains('/reel');
      return DetectedLink(
        rawText: raw,
        normalizedUrl: url,
        platformName: 'إنستغرام',
        categoryLabel: isReel ? 'ريلز / فيديو' : 'منشور / صفحة',
        icon: Icons.camera_alt_outlined,
        start: start,
        end: end,
      );
    }
    if (lower.contains('facebook.com') ||
        lower.contains('fb.watch') ||
        lower.contains('fb.com')) {
      final isVideo = lower.contains('watch') || lower.contains('reel') || lower.contains('video');
      return DetectedLink(
        rawText: raw,
        normalizedUrl: url,
        platformName: 'فيسبوك',
        categoryLabel: isVideo ? 'فيديو' : 'صفحة / منشور',
        icon: Icons.facebook,
        start: start,
        end: end,
      );
    }
    if (lower.contains('x.com') || lower.contains('twitter.com')) {
      return DetectedLink(
        rawText: raw,
        normalizedUrl: url,
        platformName: 'إكس (تويتر)',
        categoryLabel: 'منشور / حساب',
        icon: Icons.alternate_email,
        start: start,
        end: end,
      );
    }
    if (lower.contains('t.me') || lower.contains('telegram.me')) {
      return DetectedLink(
        rawText: raw,
        normalizedUrl: url,
        platformName: 'تيليجرام',
        categoryLabel: 'قناة / رسالة',
        icon: Icons.send_outlined,
        start: start,
        end: end,
      );
    }
    if (lower.contains('snapchat.com')) {
      return DetectedLink(
        rawText: raw,
        normalizedUrl: url,
        platformName: 'سناب شات',
        categoryLabel: 'مقطع / حساب',
        icon: Icons.chat_bubble_outline,
        start: start,
        end: end,
      );
    }
    if (lower.contains('threads.net')) {
      return DetectedLink(
        rawText: raw,
        normalizedUrl: url,
        platformName: 'ثريدز',
        categoryLabel: 'منشور',
        icon: Icons.forum_outlined,
        start: start,
        end: end,
      );
    }
    if (lower.contains('linkedin.com')) {
      return DetectedLink(
        rawText: raw,
        normalizedUrl: url,
        platformName: 'لينكدإن',
        categoryLabel: 'صفحة مهنية',
        icon: Icons.work_outline,
        start: start,
        end: end,
      );
    }
    if (lower.contains('reddit.com')) {
      return DetectedLink(
        rawText: raw,
        normalizedUrl: url,
        platformName: 'ريديت',
        categoryLabel: 'نقاش',
        icon: Icons.forum_outlined,
        start: start,
        end: end,
      );
    }
    if (lower.contains('vimeo.com') || lower.contains('dailymotion.com')) {
      return DetectedLink(
        rawText: raw,
        normalizedUrl: url,
        platformName: 'فيديو',
        categoryLabel: 'مشاهدة',
        icon: Icons.ondemand_video,
        start: start,
        end: end,
      );
    }
    if (lower.contains('github.com')) {
      return DetectedLink(
        rawText: raw,
        normalizedUrl: url,
        platformName: 'GitHub',
        categoryLabel: 'مستودع / صفحة',
        icon: Icons.code,
        start: start,
        end: end,
      );
    }

    return DetectedLink(
      rawText: raw,
      normalizedUrl: url,
      platformName: 'رابط ويب',
      categoryLabel: 'فتح الرابط',
      icon: Icons.language,
      start: start,
      end: end,
    );
  }

  static List<DetectedLink> extractLinks(String text, {bool unique = true}) {
    if (text.trim().isEmpty) return const [];
    final List<DetectedLink> results = [];
    final Set<String> seen = {};

    for (final match in urlRegex.allMatches(text)) {
      final rawClean = _trimTrailingPunct(match.group(0) ?? '');
      if (rawClean.isEmpty) continue;
      final end = match.start + rawClean.length;
      final item = _classify(rawClean, match.start, end);
      if (unique) {
        if (seen.contains(item.normalizedUrl)) continue;
        seen.add(item.normalizedUrl);
      }
      results.add(item);
    }
    return results;
  }
}
