import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/onyx_theme.dart';
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
  int _currentIndex = 0;
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
        'app': 'ONYX NOTES',
        'exportedAt': DateTime.now().toIso8601String(),
        'count': exportList.length,
        'notes': exportList,
      });

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/onyx_notes_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(jsonStr);

      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'نسخة احتياطية من تطبيق ملاحظاتي ONYX (${exportList.length} ملاحظة)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر التصدير: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          if (_currentIndex != 3) ...[
            IconButton(
              tooltip: 'تبديل العرض (قائمة / شبكة)',
              icon: Icon(
                isGrid ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
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
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
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
                  if (!_isSearching)
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
                          final content = (note['content'] ?? '').toString();
                          final category =
                              (note['category'] ?? 'عام').toString();
                          final tags = List<String>.from(note['tags'] ?? []);
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
                              tags.any((t) => t.toLowerCase().contains(q)) ||
                              (!maskContent &&
                                  content.toLowerCase().contains(q));

                          bool matchesTab = false;
                          if (_currentIndex == 0) matchesTab = !isArchived;
                          if (_currentIndex == 1) matchesTab = isArchived;
                          if (_currentIndex == 2) {
                            matchesTab = isFavorite && !isArchived;
                          }

                          final bool matchesCategory =
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
                          final int timeA = (mapA['updatedAt'] as int?) ?? 0;
                          final int timeB = (mapB['updatedAt'] as int?) ?? 0;
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
                                    Icons.note_alt_outlined,
                                    size: 46,
                                    color: pal.textMuted,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'لا توجد ملاحظات هنا بعد',
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
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.78,
                            ),
                            itemCount: filteredNotes.length,
                            itemBuilder: (context, index) {
                              final note = filteredNotes[index].value as Map;
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
                          padding: const EdgeInsets.only(top: 4, bottom: 110),
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
      floatingActionButton: _currentIndex == 3
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
                        : [const Color(0xFF1F2026), const Color(0xFF060608)],
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
      onTap: () => _openNoteWithLockCheck(note, noteKey),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPinned) ...[
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
                  children: [
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
                          _showDeleteConfirmation(box, noteKey, pal),
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
          Text(
            maskLocked
                ? 'محتوى محمي برقم سري ••••••'
                : (note['content'] ?? '').toString(),
            style: contentStyle,
            maxLines: compactGrid ? 2 : 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (!maskLocked && (audioRecords.isNotEmpty || checklist.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
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
          if (tags.isNotEmpty && !compactGrid)
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

  void _showDeleteConfirmation(Box box, dynamic noteKey, OnyxPalette pal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.elevatedBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: pal.glassBorder),
        ),
        title: Text(
          'تأكيد الحذف',
          style:
              TextStyle(color: pal.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'هل أنت متأكد من حذف هذه الملاحظة؟',
          style: TextStyle(color: pal.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(color: pal.textMuted)),
          ),
          TextButton(
            onPressed: () {
              box.delete(noteKey);
              Navigator.pop(ctx);
            },
            child: Text(
              'تأكيد الحذف',
              style:
                  TextStyle(color: pal.danger, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(OnyxPalette pal) {
    final notesCount = Hive.box('notes').length;

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
                    const OnyxSculptedPrism3D(size: 92, interactiveTilt: false),
                    const SizedBox(height: 10),
                    Text(
                      'ملاحظاتي ONYX',
                      style: TextStyle(
                        color: pal.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'إصدار 3D الزجاجي · $notesCount ملاحظة محفوظة',
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
              _drawerTile(pal, Icons.settings_outlined, 'الإعدادات', () {
                Navigator.pop(context);
                setState(() => _currentIndex = 3);
              }),
              Divider(color: pal.divider, height: 24),
              _drawerTile(
                pal,
                Icons.auto_awesome_outlined,
                'استعراض واجهة البداية 3D',
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
    final sortMode = OnyxSettings.sortMode;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        _sectionLabel('المظهر والزجاج ثلاثي الأبعاد', pal),
        Onyx3DGlassCard(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Column(
            children: [
              SwitchListTile(
                title: Text(
                  isDark
                      ? 'الأسود الفاخر (Obsidian Noir)'
                      : 'الأبيض الأنيق (Alabaster White)',
                  style: TextStyle(
                    color: pal.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'تبديل فوري للواجهة الكاملة بين الأسود والأبيض',
                  style: TextStyle(color: pal.textMuted, fontSize: 12),
                ),
                value: isDark,
                activeColor: pal.accent,
                onChanged: (v) => OnyxSettings.setIsDark(v),
              ),
              Divider(color: pal.divider, height: 1),
              SwitchListTile(
                title: Text(
                  'بروز ثلاثي الأبعاد (3D Depth)',
                  style: TextStyle(color: pal.textPrimary),
                ),
                subtitle: Text(
                  'ظلال متعددة الطبقات وحواف زجاجية مضيئة',
                  style: TextStyle(color: pal.textMuted, fontSize: 12),
                ),
                value: enable3D,
                activeColor: pal.accent,
                onChanged: (v) => OnyxSettings.setEnable3D(v),
              ),
              Divider(color: pal.divider, height: 1),
              SwitchListTile(
                title: Text(
                  'لمعان ضوئي خفيف (Shimmer)',
                  style: TextStyle(color: pal.textPrimary),
                ),
                subtitle: Text(
                  'تأثير بريق متحرك على الأشكال والملاحظات المثبتة',
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
        _sectionLabel('التنظيم والأمان', pal),
        Onyx3DGlassCard(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.sort, color: pal.textPrimary),
                title: Text('ترتيب الملاحظات',
                    style: TextStyle(color: pal.textPrimary)),
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
                  'إخفاء معاينة الملاحظات المقفلة',
                  style: TextStyle(color: pal.textPrimary),
                ),
                value: hideLocked,
                activeColor: pal.accent,
                onChanged: (v) => OnyxSettings.setHideLocked(v),
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
                  'عرض واجهة البداية والترحيب 3D',
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
                leading: Icon(Icons.download_outlined, color: pal.textPrimary),
                title: Text(
                  'تصدير نسخة احتياطية (JSON)',
                  style: TextStyle(color: pal.textPrimary),
                ),
                subtitle: Text(
                  'مشاركة وحفظ جميع الملاحظات كملف نصي منظم',
                  style: TextStyle(color: pal.textMuted, fontSize: 12),
                ),
                onTap: _exportJsonBackup,
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
                      title: Text('تأكيد',
                          style: TextStyle(color: pal.textPrimary)),
                      content: Text(
                        'هل تريد مسح جميع الملاحظات نهائياً؟',
                        style: TextStyle(color: pal.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('إلغاء',
                              style: TextStyle(color: pal.textMuted)),
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
        const SizedBox(height: 18),
        _sectionLabel('حول التطبيق', pal),
        Onyx3DGlassCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline, color: pal.textPrimary),
            title: Text(
              'ملاحظاتي · ONYX 3D Edition',
              style: TextStyle(
                color: pal.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'الإصدار 2.0.0 — تطوير واجهات زجاجية 3D فاخرة',
              style: TextStyle(color: pal.textMuted, fontSize: 12),
            ),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'ملاحظاتي ONYX',
                applicationVersion: '2.0.0',
              );
            },
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
        title: Text('تعيين رمز قفل جديد',
            style: TextStyle(color: pal.textPrimary)),
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
