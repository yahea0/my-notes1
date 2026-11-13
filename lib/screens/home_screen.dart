import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/onyx_theme.dart';
import '../utils/code_highlighter.dart';
import '../widgets/luxury_3d_glass.dart';
import 'add_note_screen.dart';
import 'splash_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _selectedCategory = 'الكل';
  int _currentIndex = 0; // 0: الرئيسية، 1: الأرشيف، 2: المفضلة، 3: الإعدادات، 4: سلة المهملات
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getTitleByIndex(int index) {
    switch (index) {
      case 0:
        return 'ملاحظاتي';
      case 1:
        return 'الأرشيف';
      case 2:
        return 'المفضلة';
      case 3:
        return 'الإعدادات';
      case 4:
        return 'سلة المهملات';
      default:
        return 'ملاحظاتي';
    }
  }

  dynamic _toJsonSafe(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _toJsonSafe(v)));
    }
    if (value is List) {
      return value.map(_toJsonSafe).toList();
    }
    return value;
  }

  Future<void> _openNoteWithLockCheck(Map note, dynamic noteKey) async {
    final bool isLocked = (note['isLocked'] as bool?) ?? false;
    if (!isLocked) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddNoteScreen(note: note, noteKey: noteKey),
        ),
      );
      return;
    }

    final pal = OnyxPalette.of(OnyxSettings.isDark);
    final pinController = TextEditingController();
    final bool? unlocked = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.elevatedBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: pal.glassStrongBorder),
        ),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: pal.textPrimary),
            const SizedBox(width: 8),
            Text('ملاحظة محمية', style: TextStyle(color: pal.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'أدخل الرقم السري للوصول إلى هذه الملاحظة',
              style: TextStyle(color: pal.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: pal.textPrimary,
                fontSize: 20,
                letterSpacing: 6,
              ),
              decoration: InputDecoration(
                hintText: '••••',
                hintStyle: TextStyle(color: pal.textMuted),
                filled: true,
                fillColor: pal.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: pal.glassBorder),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: pal.textMuted)),
          ),
          TextButton(
            onPressed: () {
              if (pinController.text.trim() == OnyxSettings.vaultPin) {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الرقم السري غير صحيح!')),
                );
              }
            },
            child: Text(
              'فتح',
              style: TextStyle(
                color: pal.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (unlocked == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddNoteScreen(note: note, noteKey: noteKey),
        ),
      );
    }
  }

  Future<void> _exportJsonBackup() async {
    try {
      final box = Hive.box('notes');
      final List<dynamic> exportList =
          box.toMap().entries.map((e) => _toJsonSafe(e.value)).toList();

      final jsonStr = const JsonEncoder.withIndent('  ').convert({
        'app': 'MyNotes',
        'exportedAt': DateTime.now().toIso8601String(),
        'count': exportList.length,
        'notes': exportList,
      });

      await Clipboard.setData(ClipboardData(text: jsonStr));

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/notes_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(jsonStr);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'نسخة احتياطية من تطبيق ملاحظاتي (${exportList.length} ملاحظة)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر التصدير: $e')),
        );
      }
    }
  }

  Future<void> _importJsonBackup(OnyxPalette pal) async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.elevatedBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: pal.glassBorder),
        ),
        title: Text(
          'استيراد نسخة احتياطية (JSON)',
          style: TextStyle(color: pal.textPrimary, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          maxLines: 6,
          style: TextStyle(
            color: pal.textPrimary,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
          decoration: InputDecoration(
            hintText: 'الصق محتوى ملف JSON هنا...',
            hintStyle: TextStyle(color: pal.textMuted),
            filled: true,
            fillColor: pal.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: pal.glassBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null) {
                controller.text = data!.text!;
              }
            },
            child: Text(
              'لصق من الحافظة',
              style: TextStyle(color: pal.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(color: pal.textMuted)),
          ),
          TextButton(
            onPressed: () {
              try {
                final decoded = jsonDecode(controller.text.trim());
                final List rawList = decoded is List
                    ? decoded
                    : (decoded is Map && decoded['notes'] is List)
                        ? decoded['notes'] as List
                        : [];
                if (rawList.isEmpty) throw const FormatException();
                final box = Hive.box('notes');
                int added = 0;
                for (final item in rawList) {
                  if (item is Map) {
                    box.add(
                      Map<String, dynamic>.from(
                        item.map((k, v) => MapEntry(k.toString(), v)),
                      ),
                    );
                    added++;
                  }
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم استيراد $added ملاحظة بنجاح')),
                );
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('صيغة JSON غير صالحة أو فارغة'),
                  ),
                );
              }
            },
            child: Text(
              'استيراد',
              style: TextStyle(
                color: pal.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmEmptyTrash(OnyxPalette pal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.elevatedBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: pal.glassBorder),
        ),
        title: Text('إفراغ سلة المهملات', style: TextStyle(color: pal.textPrimary)),
        content: Text(
          'سيتم حذف كل الملاحظات الموجودة في السلة نهائياً. هل أنت متأكد؟',
          style: TextStyle(color: pal.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(color: pal.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final box = Hive.box('notes');
              final keysToDelete = box.toMap().entries
                  .where((e) => e.value is Map && e.value['isTrashed'] == true)
                  .map((e) => e.key)
                  .toList();
              box.deleteAll(keysToDelete);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إفراغ سلة المهملات')),
              );
            },
            child: Text(
              'حذف نهائي',
              style: TextStyle(color: pal.danger, fontWeight: FontWeight.bold),
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
        final isDark = OnyxSettings.isDark;
        final pal = OnyxPalette.of(isDark);
        final isGrid = OnyxSettings.isGridView;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: pal.scaffoldBg,
          extendBody: true,
          drawer: _buildDrawer(pal),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: pal.textPrimary),
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: TextStyle(color: pal.textPrimary, fontSize: 17),
                    decoration: InputDecoration(
                      hintText: 'ابحث في العنوان أو المحتوى أو الوسوم...',
                      hintStyle: TextStyle(color: pal.textMuted, fontSize: 14),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  )
                : Text(
                    _getTitleByIndex(_currentIndex),
                    style: TextStyle(
                      color: pal.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
            actions: [
              if (_currentIndex == 4)
                IconButton(
                  tooltip: 'إفراغ السلة',
                  icon: Icon(Icons.delete_sweep, color: pal.danger),
                  onPressed: () => _confirmEmptyTrash(pal),
                ),
              if (_currentIndex != 3) ...[
                IconButton(
                  tooltip: 'تبديل العرض (قائمة / شبكة)',
                  icon: Icon(
                    isGrid
                        ? Icons.view_agenda_outlined
                        : Icons.grid_view_rounded,
                  ),
                  onPressed: () => OnyxSettings.setIsGridView(!isGrid),
                ),
                IconButton(
                  tooltip: 'بحث',
                  icon: Icon(_isSearching ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() {
                      if (_isSearching) {
                        _isSearching = false;
                        _searchQuery = '';
                        _searchController.clear();
                      } else {
                        _isSearching = true;
                      }
                    });
                  },
                ),
              ],
              IconButton(
                tooltip: 'تبديل الأسود / الأبيض',
                icon: Icon(
                  isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
                onPressed: () => OnyxSettings.setIsDark(!isDark),
              ),
            ],
          ),
          body: OnyxBackdrop(
            palette: pal,
            child: _currentIndex == 3
                ? _buildSettingsScreen(pal)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isSearching && _currentIndex != 4)
                        SizedBox(
                          height: 54,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              _categoryChip('الكل', Icons.apps),
                              _categoryChip('العمل', Icons.work_outline),
                              _categoryChip('الدراسة', Icons.school_outlined),
                              _categoryChip('شخصي', Icons.person_outline),
                              _categoryChip('عام', Icons.layers_outlined),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ValueListenableBuilder(
                          valueListenable: Hive.box('notes').listenable(),
                          builder: (context, Box box, _) {
                            final allNotes = box.toMap().entries.toList();
                            final q = _searchQuery.trim().toLowerCase();

                            final filteredNotes = allNotes.where((entry) {
                              if (entry.value is! Map) return false;
                              final note = entry.value as Map;
                              final title = (note['title'] ?? '').toString();
                              final content =
                                  (note['content'] ?? '').toString();
                              final category =
                                  (note['category'] ?? 'عام').toString();
                              final tags =
                                  List<String>.from(note['tags'] ?? []);
                              final isTrashed =
                                  (note['isTrashed'] as bool?) ?? false;
                              final isArchived =
                                  (note['isArchived'] as bool?) ?? false;
                              final isFavorite =
                                  (note['isFavorite'] as bool?) ?? false;
                              final isLocked =
                                  (note['isLocked'] as bool?) ?? false;
                              final maskContent =
                                  isLocked && OnyxSettings.hideLocked;

                              final bool matchesSearch = q.isEmpty ||
                                  title.toLowerCase().contains(q) ||
                                  category.toLowerCase().contains(q) ||
                                  (!maskContent &&
                                      tags.any(
                                          (t) => t.toLowerCase().contains(q))) ||
                                  (!maskContent &&
                                      content.toLowerCase().contains(q));

                              bool matchesTab = false;
                              if (_currentIndex == 4) {
                                matchesTab = isTrashed;
                              } else {
                                if (isTrashed) return false;
                                if (_currentIndex == 0) {
                                  matchesTab = !isArchived;
                                }
                                if (_currentIndex == 1) matchesTab = isArchived;
                                if (_currentIndex == 2) {
                                  matchesTab = isFavorite && !isArchived;
                                }
                              }

                              final bool matchesCategory =
                                  _currentIndex == 4 ||
                                      _selectedCategory == 'الكل' ||
                                      category == _selectedCategory;

                              return matchesSearch &&
                                  matchesTab &&
                                  matchesCategory;
                            }).toList();

                            final sortMode = OnyxSettings.sortMode;
                            filteredNotes.sort((a, b) {
                              final mapA = a.value as Map;
                              final mapB = b.value as Map;
                              final bool aPinned =
                                  (mapA['isPinned'] as bool?) ?? false;
                              final bool bPinned =
                                  (mapB['isPinned'] as bool?) ?? false;
                              if (aPinned && !bPinned) return -1;
                              if (!aPinned && bPinned) return 1;

                              if (sortMode == 'alpha') {
                                return (mapA['title'] ?? '')
                                    .toString()
                                    .compareTo((mapB['title'] ?? '').toString());
                              }
                              final int timeA =
                                  (mapA['updatedAt'] as int?) ?? 0;
                              final int timeB =
                                  (mapB['updatedAt'] as int?) ?? 0;
                              return timeB.compareTo(timeA);
                            });

                            if (filteredNotes.isEmpty) {
                              return Center(
                                child: Onyx3DGlassCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 24,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _currentIndex == 4
                                            ? Icons.delete_outline
                                            : Icons.note_alt_outlined,
                                        size: 46,
                                        color: pal.textMuted,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _currentIndex == 4
                                            ? 'سلة المهملات فارغة'
                                            : 'لا توجد ملاحظات هنا بعد',
                                        style: TextStyle(
                                          color: pal.textSecondary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            if (isGrid) {
                              return GridView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 6, 16, 110),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.78,
                                ),
                                itemCount: filteredNotes.length,
                                itemBuilder: (context, index) {
                                  final note =
                                      filteredNotes[index].value as Map;
                                  final key = filteredNotes[index].key;
                                  return _buildNoteCard(
                                    note,
                                    key,
                                    box,
                                    pal,
                                    compactGrid: true,
                                  );
                                },
                              );
                            }

                            return ListView.builder(
                              padding:
                                  const EdgeInsets.only(top: 4, bottom: 110),
                              itemCount: filteredNotes.length,
                              itemBuilder: (context, index) {
                                final note = filteredNotes[index].value as Map;
                                final key = filteredNotes[index].key;
                                return _buildNoteCard(note, key, box, pal);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          floatingActionButton: (_currentIndex == 3 || _currentIndex == 4)
              ? null
              : GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddNoteScreen()),
                  ),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: pal.isDark
                            ? [Colors.white, const Color(0xFFD5D7DF)]
                            : [
                                const Color(0xFF1F2026),
                                const Color(0xFF060608),
                              ],
                      ),
                      border: Border.all(color: pal.glassHighlight, width: 1.3),
                      boxShadow: [
                        BoxShadow(
                          color: pal.shadowDeep,
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(Icons.add, color: pal.onAccent, size: 30),
                  ),
                ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Onyx3DGlassCard(
              borderRadius: 26,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(0, Icons.home_rounded, 'الرئيسية', pal),
                  _navItem(1, Icons.archive_outlined, 'الأرشيف', pal),
                  _navItem(2, Icons.star_border_rounded, 'المفضلة', pal),
                  _navItem(3, Icons.settings_outlined, 'الإعدادات', pal),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _navItem(int idx, IconData icon, String label, OnyxPalette pal) {
    final bool active = _currentIndex == idx;
    return GestureDetector(
      onTap: () => setState(() {
        _currentIndex = idx;
        _isSearching = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? pal.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: active ? pal.onAccent : pal.textMuted,
            ),
            if (active) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: pal.onAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String title, IconData icon) {
    return Onyx3DPillButton(
      label: title,
      icon: icon,
      isSelected: _selectedCategory == title,
      onTap: () => setState(() => _selectedCategory = title),
    );
  }

  Widget _buildNoteCard(
    Map note,
    dynamic noteKey,
    Box box,
    OnyxPalette pal, {
    bool compactGrid = false,
  }) {
    final bool isFav = (note['isFavorite'] as bool?) ?? false;
    final bool isPinned = (note['isPinned'] as bool?) ?? false;
    final bool isArchived = (note['isArchived'] as bool?) ?? false;
    final bool isTrashed = (note['isTrashed'] as bool?) ?? false;
    final bool isLocked = (note['isLocked'] as bool?) ?? false;
    final bool maskLocked = isLocked && OnyxSettings.hideLocked;

    final Color titleColor =
        resolveAdaptiveNoteColor(note['textColor'] as int?, pal);
    final Color contentColor = resolveAdaptiveNoteColor(
      note['contentColor'] as int?,
      pal,
      isContent: true,
    );

    final String fontFam = (note['fontFamily'] as String?) ?? 'Tahoma';
    final double titleSize =
        ((note['titleFontSize'] as num?) ?? 18.0).toDouble();
    final double contentSize =
        ((note['contentFontSize'] as num?) ?? 14.0).toDouble();

    final List<dynamic> imagePaths = note['imagePaths'] ?? [];
    final List<dynamic> audioRecords = note['audioRecords'] ?? [];
    final List<dynamic> checklist = note['checklist'] ?? [];
    final List<dynamic> tags = note['tags'] ?? [];

    final String rawContent = (note['content'] ?? '').toString();
    final String codeMode = (note['codeMode'] as String?) ?? 'auto';
    final String savedLang = (note['codeLanguage'] as String?) ?? '';
    final CodeLanguageInfo? codeLang = codeMode == 'off'
        ? null
        : (savedLang.isNotEmpty
            ? getLanguageById(savedLang)
            : CodeDetector.detect(rawContent));

    final TextStyle titleStyle = applyArabicFont(
      fontFam,
      TextStyle(
        fontSize: compactGrid ? 15.5 : titleSize.clamp(15.0, 24.0),
        fontWeight: FontWeight.bold,
        color: titleColor,
      ),
    );
    final TextStyle contentStyle = applyArabicFont(
      fontFam,
      TextStyle(
        fontSize: compactGrid ? 12.5 : contentSize.clamp(12.0, 18.0),
        color: contentColor,
        height: 1.5,
      ),
    );

    final int doneTasks =
        checklist.where((item) => item is Map && item['done'] == true).length;

    return Onyx3DGlassCard(
      margin: compactGrid
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      padding: EdgeInsets.all(compactGrid ? 12 : 16),
      borderRadius: 22,
      isHighlighted: isPinned,
      enableShimmer: isPinned,
      onTap: isTrashed ? null : () => _openNoteWithLockCheck(note, noteKey),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPinned && !isTrashed) ...[
                const Icon(Icons.push_pin, size: 15, color: Colors.amber),
                const SizedBox(width: 5),
              ],
              if (isLocked) ...[
                Icon(Icons.lock_outline, size: 15, color: pal.textPrimary),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  (note['title'] ?? '').toString().trim().isEmpty
                      ? 'بدون عنوان'
                      : note['title'].toString(),
                  style: titleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!compactGrid)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: isTrashed
                      ? [
                          IconButton(
                            tooltip: 'استعادة',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.restore_from_trash,
                              color: pal.textPrimary,
                              size: 20,
                            ),
                            onPressed: () {
                              final updated = Map.from(note);
                              updated['isTrashed'] = false;
                              box.put(noteKey, updated);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تمت استعادة الملاحظة'),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'حذف نهائي',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.delete_forever,
                              color: pal.danger,
                              size: 20,
                            ),
                            onPressed: () =>
                                _showDeleteConfirmation(box, note, noteKey, pal, forceDelete: true),
                          ),
                        ]
                      : [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              isFav ? Icons.star : Icons.star_border,
                              color: isFav ? Colors.amber : pal.textMuted,
                              size: 20,
                            ),
                            onPressed: () {
                              final updated = Map.from(note);
                              updated['isFavorite'] = !isFav;
                              box.put(noteKey, updated);
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              isArchived
                                  ? Icons.unarchive_outlined
                                  : Icons.archive_outlined,
                              color: pal.textMuted,
                              size: 19,
                            ),
                            onPressed: () {
                              final updated = Map.from(note);
                              updated['isArchived'] = !isArchived;
                              box.put(noteKey, updated);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isArchived
                                        ? 'تمت الاستعادة من الأرشيف'
                                        : 'تمت الأرشفة',
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.delete_outline,
                              color: pal.danger,
                              size: 19,
                            ),
                            onPressed: () =>
                                _showDeleteConfirmation(box, note, noteKey, pal),
                          ),
                        ],
                ),
            ],
          ),

          if (!maskLocked &&
              imagePaths.isNotEmpty &&
              File(imagePaths[0].toString()).existsSync())
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(imagePaths[0].toString()),
                  height: compactGrid ? 70 : 110,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),

          const SizedBox(height: 6),

          if (maskLocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: pal.chipBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: pal.glassBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.visibility_off_outlined, size: 15, color: pal.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'محتوى سري مخفي — انقر لإدخال الرمز',
                      style: TextStyle(color: pal.textMuted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              rawContent,
              style: codeLang != null
                  ? TextStyle(
                      fontFamily: 'monospace',
                      fontSize: compactGrid ? 11.5 : 12.5,
                      color: contentColor,
                      height: 1.45,
                    )
                  : contentStyle,
              maxLines: compactGrid ? 2 : 3,
              overflow: TextOverflow.ellipsis,
            ),

          if (!maskLocked &&
              (codeLang != null ||
                  audioRecords.isNotEmpty ||
                  checklist.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (codeLang != null)
                    _miniMetaPill(pal, Icons.code, codeLang.displayName),
                  if (audioRecords.isNotEmpty)
                    _miniMetaPill(
                      pal,
                      Icons.audiotrack,
                      '${audioRecords.length} صوت',
                    ),
                  if (checklist.isNotEmpty)
                    _miniMetaPill(
                      pal,
                      Icons.check_circle_outline,
                      '$doneTasks/${checklist.length} مهام',
                    ),
                ],
              ),
            ),

          if (!maskLocked && tags.isNotEmpty && !compactGrid)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 5,
                children: tags
                    .take(3)
                    .map(
                      (t) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: pal.chipBg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '#$t',
                          style: TextStyle(color: pal.textMuted, fontSize: 10.5),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

          if (compactGrid) const Spacer() else const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: pal.chipBg,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: pal.glassBorder),
                ),
                child: Text(
                  (note['category'] ?? 'عام').toString(),
                  style: TextStyle(fontSize: 11, color: pal.textSecondary),
                ),
              ),
              Text(
                '${note['date'] ?? ''} · ${note['time'] ?? ''}',
                style: TextStyle(fontSize: 10.5, color: pal.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniMetaPill(OnyxPalette pal, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: pal.chipBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pal.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: pal.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: pal.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    Box box,
    Map note,
    dynamic noteKey,
    OnyxPalette pal, {
    bool forceDelete = false,
  }) {
    final bool moveToTrash = !forceDelete && OnyxSettings.useTrash;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.elevatedBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: pal.glassBorder),
        ),
        title: Text(
          moveToTrash ? 'نقل إلى سلة المهملات' : 'تأكيد الحذف النهائي',
          style:
              TextStyle(color: pal.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          moveToTrash
              ? 'يمكنك استعادة الملاحظة لاحقاً من سلة المهملات.'
              : 'هل أنت متأكد من حذف هذه الملاحظة نهائياً؟',
          style: TextStyle(color: pal.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(color: pal.textMuted)),
          ),
          TextButton(
            onPressed: () {
              if (moveToTrash) {
                final updated = Map.from(note);
                updated['isTrashed'] = true;
                box.put(noteKey, updated);
              } else {
                box.delete(noteKey);
              }
              Navigator.pop(ctx);
            },
            child: Text(
              moveToTrash ? 'نقل للسلة' : 'حذف نهائي',
              style:
                  TextStyle(color: pal.danger, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(OnyxPalette pal) {
    final all = Hive.box('notes').toMap().values.whereType<Map>();
    final int activeCount = all.where((n) => n['isTrashed'] != true).length;
    final int trashCount = all.where((n) => n['isTrashed'] == true).length;

    return Drawer(
      backgroundColor: pal.scaffoldBg,
      child: OnyxBackdrop(
        palette: pal,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Onyx3DGlassCard(
                enableShimmer: true,
                isHighlighted: true,
                borderRadius: 24,
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const OnyxNotebook3DLogo(size: 98, interactiveTilt: false),
                    const SizedBox(height: 10),
                    Text(
                      'ملاحظاتي',
                      style: TextStyle(
                        color: pal.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$activeCount ملاحظة محفوظة',
                      style: TextStyle(color: pal.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _drawerTile(pal, Icons.home_rounded, 'الرئيسية', () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              }),
              _drawerTile(pal, Icons.star_border_rounded, 'المفضلة', () {
                Navigator.pop(context);
                setState(() => _currentIndex = 2);
              }),
              _drawerTile(pal, Icons.archive_outlined, 'الأرشيف', () {
                Navigator.pop(context);
                setState(() => _currentIndex = 1);
              }),
              _drawerTile(
                pal,
                Icons.delete_outline,
                'سلة المهملات ($trashCount)',
                () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 4);
                },
              ),
              _drawerTile(pal, Icons.settings_outlined, 'الإعدادات', () {
                Navigator.pop(context);
                setState(() => _currentIndex = 3);
              }),
              Divider(color: pal.divider, height: 24),
              _drawerTile(
                pal,
                Icons.auto_awesome_outlined,
                'عرض شاشة البداية',
                () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SplashScreen(manualPreview: true),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerTile(
    OnyxPalette pal,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Icon(icon, color: pal.textPrimary),
      title: Text(title, style: TextStyle(color: pal.textPrimary)),
      onTap: onTap,
    );
  }

  Widget _buildSettingsScreen(OnyxPalette pal) {
    final isDark = OnyxSettings.isDark;
    final enable3D = OnyxSettings.enable3D;
    final enableShimmer = OnyxSettings.enableShimmer;
    final blurSigma = OnyxSettings.blurSigma;
    final hideLocked = OnyxSettings.hideLocked;
    final useTrash = OnyxSettings.useTrash;
    final confirmOnExit = OnyxSettings.confirmOnExit;
    final appLock = OnyxSettings.appLockEnabled;
    final sortMode = OnyxSettings.sortMode;
    final defaultFont = kOnyxFonts.any((f) => f['id'] == OnyxSettings.defaultFont)
        ? OnyxSettings.defaultFont
        : 'Tahoma';
    final defaultSize = OnyxSettings.defaultContentSize;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        _sectionLabel('المظهر والواجهة', pal),
        Onyx3DGlassCard(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Column(
            children: [
              SwitchListTile(
                title: Text(
                  isDark ? 'الوضع الداكن (أسود فاخر)' : 'الوضع المشرق (أبيض أنيق)',
                  style: TextStyle(
                    color: pal.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'تبديل فوري بين الأسود والأبيض',
                  style: TextStyle(color: pal.textMuted, fontSize: 12),
                ),
                value: isDark,
                activeColor: pal.accent,
                onChanged: (v) => OnyxSettings.setIsDark(v),
              ),
              Divider(color: pal.divider, height: 1),
              SwitchListTile(
                title: Text(
                  'بروز وتجسيم البطاقات',
                  style: TextStyle(color: pal.textPrimary),
                ),
                subtitle: Text(
                  'ظلال عميقة وحواف زجاجية مضيئة',
                  style: TextStyle(color: pal.textMuted, fontSize: 12),
                ),
                value: enable3D,
                activeColor: pal.accent,
                onChanged: (v) => OnyxSettings.setEnable3D(v),
              ),
              Divider(color: pal.divider, height: 1),
              SwitchListTile(
                title: Text(
                  'اللمعان الضوئي الخفيف',
                  style: TextStyle(color: pal.textPrimary),
                ),
                subtitle: Text(
                  'بريق متحرك على البطاقات المثبتة والأيقونة',
                  style: TextStyle(color: pal.textMuted, fontSize: 12),
                ),
                value: enableShimmer,
                activeColor: pal.accent,
                onChanged: (v) => OnyxSettings.setEnableShimmer(v),
              ),
              Divider(color: pal.divider, height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'قوة الضبابية الزجاجية',
                          style: TextStyle(color: pal.textPrimary),
                        ),
                        Text(
                          '${blurSigma.toInt()}px',
                          style: TextStyle(
                            color: pal.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: blurSigma,
                      min: 4,
                      max: 26,
                      divisions: 11,
                      activeColor: pal.accent,
                      onChanged: (v) => OnyxSettings.setBlurSigma(v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionLabel('المحرر والكتابة', pal),
        Onyx3DGlassCard(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.font_download_outlined, color: pal.textPrimary),
                title: Text(
                  'الخط الافتراضي للملاحظات الجديدة',
                  style: TextStyle(color: pal.textPrimary),
                ),
                trailing: DropdownButton<String>(
                  value: defaultFont,
                  dropdownColor: pal.elevatedBg,
                  underline: const SizedBox.shrink(),
                  style: TextStyle(color: pal.textPrimary, fontSize: 13),
                  items: kOnyxFonts
                      .map(
                        (f) => DropdownMenuItem<String>(
                          value: f['id'],
                          child: Text(f['name']!),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) OnyxSettings.setDefaultFont(v);
                  },
                ),
              ),
              Divider(color: pal.divider, height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'حجم الخط الافتراضي للنص',
                          style: TextStyle(color: pal.textPrimary),
                        ),
                        Text(
                          '${defaultSize.toInt()}',
                          style: TextStyle(
                            color: pal.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: defaultSize.clamp(12.0, 28.0),
                      min: 12,
                      max: 28,
                      divisions: 16,
                      activeColor: pal.accent,
                      onChanged: (v) => OnyxSettings.setDefaultContentSize(v),
                    ),
                  ],
                ),
              ),
              Divider(color: pal.divider, height: 1),
              SwitchListTile(
                title: Text(
                  'سؤال الحفظ عند الخروج دون حفظ',
                  style: TextStyle(color: pal.textPrimary),
                ),
                subtitle: Text(
                  'تنبيه لحفظ التعديلات عند الرجوع من الملاحظة',
                  style: TextStyle(color: pal.textMuted, fontSize: 12),
                ),
                value: confirmOnExit,
                activeColor: pal.accent,
                onChanged: (v) => OnyxSettings.setConfirmOnExit(v),
              ),
              Divider(color: pal.divider, height: 1),
              SwitchListTile(
                title: Text(
                  'نقل المحذوفات إلى سلة المهملات أولاً',
                  style: TextStyle(color: pal.textPrimary),
                ),
                subtitle: Text(
                  'حماية الملاحظات من الحذف غير المقصود',
                  style: TextStyle(color: pal.textMuted, fontSize: 12),
                ),
                value: useTrash,
                activeColor: pal.accent,
                onChanged: (v) => OnyxSettings.setUseTrash(v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionLabel('التنظيم والأمان', pal),
        Onyx3DGlassCard(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.sort, color: pal.textPrimary),
                title: Text(
                  'ترتيب الملاحظات',
                  style: TextStyle(color: pal.textPrimary),
                ),
                trailing: DropdownButton<String>(
                  value: sortMode,
                  dropdownColor: pal.elevatedBg,
                  underline: const SizedBox.shrink(),
                  style: TextStyle(color: pal.textPrimary, fontSize: 13),
                  items: const [
                    DropdownMenuItem(
                      value: 'pinned_newest',
                      child: Text('المثبت ثم الأحدث'),
                    ),
                    DropdownMenuItem(value: 'alpha', child: Text('أبجديًا')),
                  ],
                  onChanged: (v) {
                    if (v != null) OnyxSettings.setSortMode(v);
                  },
                ),
              ),
              Divider(color: pal.divider, height: 1),
              SwitchListTile(
                title: Text(
                  'إخفاء محتوى الملاحظات السرية',
                  style: TextStyle(color: pal.textPrimary),
                ),
                subtitle: Text(
                  'إخفاء النص والصور والوسوم في البطاقة والبحث',
                  style: TextStyle(color: pal.textMuted, fontSize: 12),
                ),
                value: hideLocked,
                activeColor: pal.accent,
                onChanged: (v) => OnyxSettings.setHideLocked(v),
              ),
              Divider(color: pal.divider, height: 1),
              SwitchListTile(
                title: Text(
                  'قفل التطبيق عند الفتح',
                  style: TextStyle(color: pal.textPrimary),
                ),
                subtitle: Text(
                  'يطلب الرقم السري عند تشغيل التطبيق',
                  style: TextStyle(color: pal.textMuted, fontSize: 12),
                ),
                value: appLock,
                activeColor: pal.accent,
                onChanged: (v) => OnyxSettings.setAppLockEnabled(v),
              ),
              Divider(color: pal.divider, height: 1),
              ListTile(
                leading: Icon(Icons.password_outlined, color: pal.textPrimary),
                title: Text(
                  'تغيير الرقم السري للقفل',
                  style: TextStyle(color: pal.textPrimary),
                ),
                subtitle: Text(
                  'الرمز الحالي: ${OnyxSettings.vaultPin}',
                  style: TextStyle(color: pal.textMuted, fontSize: 12),
                ),
                onTap: () => _changePinDialog(pal),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionLabel('البيانات والنسخ الاحتياطي', pal),
        Onyx3DGlassCard(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.auto_awesome, color: pal.textPrimary),
                title: Text(
                  'عرض واجهة البداية والترحيب',
                  style: TextStyle(color: pal.textPrimary),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SplashScreen(manualPreview: true),
                  ),
                ),
              ),
              Divider(color: pal.divider, height: 1),
              ListTile(
                leading: Icon(Icons.upload_file_outlined, color: pal.textPrimary),
                title: Text(
                  'تصدير نسخة احتياطية (JSON)',
                  style: TextStyle(color: pal.textPrimary),
                ),
                subtitle: Text(
                  'مشاركة وحفظ جميع الملاحظات مع النسخ للحافظة',
                  style: TextStyle(color: pal.textMuted, fontSize: 12),
                ),
                onTap: _exportJsonBackup,
              ),
              Divider(color: pal.divider, height: 1),
              ListTile(
                leading: Icon(Icons.download_outlined, color: pal.textPrimary),
                title: Text(
                  'استيراد نسخة احتياطية (JSON)',
                  style: TextStyle(color: pal.textPrimary),
                ),
                subtitle: Text(
                  'استرجاع ملاحظات محفوظة سابقاً',
                  style: TextStyle(color: pal.textMuted, fontSize: 12),
                ),
                onTap: () => _importJsonBackup(pal),
              ),
              Divider(color: pal.divider, height: 1),
              ListTile(
                leading: Icon(Icons.delete_forever, color: pal.danger),
                title: Text(
                  'مسح جميع الملاحظات',
                  style: TextStyle(color: pal.danger),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: pal.elevatedBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: BorderSide(color: pal.glassBorder),
                      ),
                      title: Text(
                        'تأكيد',
                        style: TextStyle(color: pal.textPrimary),
                      ),
                      content: Text(
                        'هل تريد مسح جميع الملاحظات نهائياً؟',
                        style: TextStyle(color: pal.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'إلغاء',
                            style: TextStyle(color: pal.textMuted),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Hive.box('notes').clear();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم مسح جميع الملاحظات'),
                              ),
                            );
                          },
                          child:
                              Text('مسح', style: TextStyle(color: pal.danger)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text, OnyxPalette pal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 6),
      child: Text(
        text,
        style: TextStyle(
          color: pal.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _changePinDialog(OnyxPalette pal) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.elevatedBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: pal.glassBorder),
        ),
        title: Text(
          'تعيين رمز قفل جديد',
          style: TextStyle(color: pal.textPrimary),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 8,
          textAlign: TextAlign.center,
          style:
              TextStyle(color: pal.textPrimary, fontSize: 18, letterSpacing: 4),
          decoration: InputDecoration(
            hintText: '4 أرقام على الأقل',
            hintStyle: TextStyle(color: pal.textMuted, fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(color: pal.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final pin = controller.text.trim();
              if (pin.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يجب أن يكون الرمز 4 خانات على الأقل'),
                  ),
                );
                return;
              }
              OnyxSettings.setVaultPin(pin);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تحديث رمز القفل بنجاح')),
              );
            },
            child: Text('حفظ', style: TextStyle(color: pal.textPrimary)),
          ),
        ],
      ),
    );
  }
}
