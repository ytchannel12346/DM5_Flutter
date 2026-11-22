import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/comic.dart';
import '../services/app_settings.dart';
import '../services/history_service.dart';
import '../sources/comic_source.dart';
import '../sources/local_comic_source.dart';
import 'reader_page.dart';

/// 共用暖紙白設定頁外框
class _ArchiveScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget body;

  const _ArchiveScaffold({
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  _circleBtn(Icons.chevron_left, () => Navigator.pop(context)),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F1F1F),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.4,
                            color: Colors.black45,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing ?? const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E2DA)),
        ),
        child: Icon(icon, color: const Color(0xFF1F1F1F), size: 22),
      ),
    );
  }
}

Widget _cardBox({required Widget child, EdgeInsets? padding}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE5E2DA)),
    ),
    child: child,
  );
}

Widget _sectionTag(String mono, String title) {
  return Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              mono,
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 1.4,
                color: Colors.black45,
                fontFamily: 'monospace',
              ),
            ),
            const Spacer(),
            Container(width: 4, height: 4, color: const Color(0xFF1F1F1F)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F1F1F),
          ),
        ),
      ],
    ),
  );
}

/// 1. 設置主頁 (SYSTEM / PREFERENCES)
class SettingsHubPage extends StatelessWidget {
  const SettingsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _ArchiveScaffold(
      title: '設置',
      subtitle: 'SYSTEM / PREFERENCES',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _navCard(context, Icons.grid_view_rounded, '使用方式', '啟動與續讀、書架及離線適配', const UsageSettingsPage()),
          _navCard(context, Icons.text_fields_rounded, '閱讀與外觀', '外觀模式、主題配色、字體與語言', const AppearanceSettingsPage()),
          _navCard(context, Icons.speed_rounded, '性能與動效', '振動反饋、幀率偏好與動態效果', const PerformanceSettingsPage()),
          _navCard(context, Icons.wifi_rounded, '局域網續讀', '連接自己的設備，接著上次的位置閱讀', null),
          _navCard(context, Icons.widgets_outlined, '小組件', '配置桌面上的閱讀主題與隱私', null),
          _navCard(context, Icons.folder_outlined, '數據與存儲', '閱讀歷史、緩存管理與備份恢復', const StorageSettingsPage()),
        ],
      ),
    );
  }

  Widget _navCard(BuildContext context, IconData icon, String title, String sub, Widget? page) {
    return _cardBox(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(icon, color: const Color(0xFF1F1F1F), size: 24),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(sub, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.black38),
        onTap: () {
          if (page != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => page));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title 功能將於後續版本支援')),
            );
          }
        },
      ),
    );
  }
}

/// 2. 使用方式 (SYSTEM / USAGE)
class UsageSettingsPage extends StatelessWidget {
  const UsageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    const tabs = ['發現', '書架', '本地', '我的'];

    return ListenableBuilder(
      listenable: s,
      builder: (_, __) => _ArchiveScaffold(
        title: '使用方式',
        subtitle: 'SYSTEM / USAGE',
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _cardBox(
              child: Column(
                children: [
                  _switchRow(Icons.stay_current_portrait, '強制豎屏', '僅本 App 固定豎屏，關閉後跟隨系統', s.forcePortrait, (v) => s.update(() => s.forcePortrait = v)),
                  const Divider(height: 1),
                  _switchRow(Icons.menu_book_outlined, '點書直接閱讀', '從上次位置繼續閱讀', s.tapToReadDirectly, (v) => s.update(() => s.tapToReadDirectly = v)),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.explore_outlined, color: Color(0xFF1F1F1F)),
                    title: const Text('啟動頁面', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    trailing: DropdownButton<int>(
                      value: s.startupTab,
                      underline: const SizedBox.shrink(),
                      items: List.generate(tabs.length, (i) => DropdownMenuItem(value: i, child: Text(tabs[i]))),
                      onChanged: (v) {
                        if (v != null) s.update(() => s.startupTab = v);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  _switchRow(Icons.history, '啟動時繼續閱讀', '打開應用後進入最近讀過的書', s.continueOnLaunch, (v) => s.update(() => s.continueOnLaunch = v)),
                  const Divider(height: 1),
                  _switchRow(Icons.layers_outlined, '合併書架', '收藏與本地書統一顯示在書架', s.mergeBookshelf, (v) => s.update(() => s.mergeBookshelf = v)),
                  const Divider(height: 1),
                  _switchRow(Icons.wifi_off_rounded, '離線適配', '斷網後隱藏發現，書架只顯示已緩存的收藏', s.offlineMode, (v) => s.update(() => s.offlineMode = v)),
                  const Divider(height: 1),
                  _switchRow(Icons.chrome_reader_mode_outlined, '閱讀器模式', '只顯示本地和我的', s.readerOnlyMode, (v) => s.update(() => s.readerOnlyMode = v)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow(IconData icon, String title, String sub, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      secondary: Icon(icon, color: const Color(0xFF1F1F1F)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      activeColor: const Color(0xFF1F1F1F),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// 3. 閱讀與外觀 (SYSTEM / READING)
class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (_, __) => _ArchiveScaffold(
        title: '閱讀與外觀',
        subtitle: 'SYSTEM / READING',
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _cardBox(
              child: const ListTile(
                leading: Icon(Icons.auto_awesome_outlined, color: Color(0xFF1F1F1F)),
                title: Text('閱讀紀念', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('紀念風格、閱讀里程碑與書頁終點', style: TextStyle(fontSize: 12)),
                trailing: Icon(Icons.chevron_right, color: Colors.black38),
              ),
            ),
            _cardBox(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.dark_mode_outlined, color: Color(0xFF1F1F1F)),
                    title: const Text('外觀模式', style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: DropdownButton<ThemeMode>(
                      value: s.themeMode,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: ThemeMode.system, child: Text('跟隨系統')),
                        DropdownMenuItem(value: ThemeMode.light, child: Text('淺色模式')),
                        DropdownMenuItem(value: ThemeMode.dark, child: Text('深色模式')),
                      ],
                      onChanged: (v) {
                        if (v != null) s.update(() => s.themeMode = v);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.language, color: Color(0xFF1F1F1F)),
                    title: const Text('語言', style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: DropdownButton<String>(
                      value: s.languageLabel,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: '繁體中文 · 香港', child: Text('繁體中文 · 香港')),
                        DropdownMenuItem(value: '簡體中文', child: Text('簡體中文')),
                        DropdownMenuItem(value: 'English', child: Text('English')),
                      ],
                      onChanged: (v) {
                        if (v != null) s.update(() => s.languageLabel = v);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.palette_outlined, color: Color(0xFF1F1F1F)),
                    title: Text('主題配色', style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text('暖紙白', style: TextStyle(color: Colors.black54)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 4. 性能與動效 (SYSTEM / EFFECTS)
class PerformanceSettingsPage extends StatelessWidget {
  const PerformanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    const fpsOptions = ['自動高刷', '系統調度', '30 Hz', '40 Hz', '60 Hz', '90 Hz', '120 Hz'];

    return ListenableBuilder(
      listenable: s,
      builder: (_, __) => _ArchiveScaffold(
        title: '性能與動效',
        subtitle: 'SYSTEM / EFFECTS',
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _sectionTag('01 / CATALOG', '顯示流暢度'),
            _cardBox(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.speed_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('幀率偏好', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: fpsOptions.map((opt) {
                      final selected = s.refreshRatePref == opt;
                      return ChoiceChip(
                        label: Text(opt),
                        selected: selected,
                        selectedColor: const Color(0xFFEBE9E4),
                        backgroundColor: Colors.white,
                        onSelected: (_) => s.update(() => s.refreshRatePref = opt),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '高刷新率適合滾動與翻頁，較低刷新率更省電；最終調度由系統決定。',
                    style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
                  ),
                ],
              ),
            ),
            _cardBox(
              child: SwitchListTile(
                secondary: const Icon(Icons.battery_saver_outlined, color: Color(0xFF1F1F1F)),
                title: const Text('低性能設備模式', style: TextStyle(fontWeight: FontWeight.bold)),
                value: s.lowPerfMode,
                activeColor: const Color(0xFF1F1F1F),
                onChanged: (v) => s.update(() => s.lowPerfMode = v),
              ),
            ),
            _sectionTag('01 / CATALOG', '視覺效果'),
            _cardBox(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('模糊度', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${s.glassBlur.round()}', style: const TextStyle(fontFamily: 'monospace')),
                    ],
                  ),
                  Slider(
                    value: s.glassBlur,
                    min: 0,
                    max: 24,
                    activeColor: const Color(0xFF1F1F1F),
                    onChanged: (v) => s.update(() => s.glassBlur = v),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('不透明度', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${(s.glassOpacity * 100).round()}%', style: const TextStyle(fontFamily: 'monospace')),
                    ],
                  ),
                  Slider(
                    value: s.glassOpacity,
                    min: 0.4,
                    max: 1.0,
                    activeColor: const Color(0xFF1F1F1F),
                    onChanged: (v) => s.update(() => s.glassOpacity = v),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => s.update(() {
                        s.glassBlur = 8.0;
                        s.glassOpacity = 0.87;
                      }),
                      child: const Text('恢復默認', style: TextStyle(color: Color(0xFF1F1F1F))),
                    ),
                  ),
                ],
              ),
            ),
            _sectionTag('01 / CATALOG', '交互與觸感'),
            _cardBox(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.animation, color: Color(0xFF1F1F1F)),
                    title: const Text('減少動態效果', style: TextStyle(fontWeight: FontWeight.bold)),
                    value: s.reduceMotion,
                    activeColor: const Color(0xFF1F1F1F),
                    onChanged: (v) => s.update(() => s.reduceMotion = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration, color: Color(0xFF1F1F1F)),
                    title: const Text('振動反饋', style: TextStyle(fontWeight: FontWeight.bold)),
                    value: s.hapticFeedback,
                    activeColor: const Color(0xFF1F1F1F),
                    onChanged: (v) {
                      if (v) HapticFeedback.lightImpact();
                      s.update(() => s.hapticFeedback = v);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 5. 數據與存儲 (SYSTEM / STORAGE)
class StorageSettingsPage extends StatelessWidget {
  const StorageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return _ArchiveScaffold(
      title: '數據與存儲',
      subtitle: 'SYSTEM / STORAGE',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _sectionTag('02 / READING LOG', '閱讀記錄'),
          _cardBox(
            child: ListTile(
              leading: const Icon(Icons.history, color: Color(0xFF1F1F1F)),
              title: const Text('閱讀歷史', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right, color: Colors.black38),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadingHistoryPage())),
            ),
          ),
          _sectionTag('03 / LOCAL ARCHIVE', '離線閱讀'),
          _cardBox(
            child: ListTile(
              leading: const Icon(Icons.cloud_download_outlined, color: Color(0xFF1F1F1F)),
              title: const Text('緩存管理', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right, color: Colors.black38),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OfflineCachePage())),
            ),
          ),
          _sectionTag('01 / CATALOG', '備份與清理'),
          _cardBox(
            child: ListTile(
              leading: const Icon(Icons.backup_outlined, color: Color(0xFF1F1F1F)),
              title: const Text('備份與恢復', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('匯出 JSON 到剪貼簿，或從剪貼簿恢復', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: Colors.black38),
              onTap: () async {
                final jsonStr = await s.exportBackupJson();
                await Clipboard.setData(ClipboardData(text: jsonStr));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已將書架與閱讀歷史備份複製到剪貼簿')),
                  );
                }
              },
            ),
          ),
          _cardBox(
            child: ListTile(
              leading: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF1F1F1F)),
              title: const Text('清理插圖緩存', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('不影響書架與閱讀記錄', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: Colors.black38),
              onTap: () {
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已清理記憶體圖片緩存')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 6. 閱讀歷史 (ARCHIVE / READING LOG)
class ReadingHistoryPage extends StatefulWidget {
  const ReadingHistoryPage({super.key});

  @override
  State<ReadingHistoryPage> createState() => _ReadingHistoryPageState();
}

class _ReadingHistoryPageState extends State<ReadingHistoryPage> {
  List<ReadHistoryItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final items = await HistoryService.loadHistory();
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  void _openHistory(ReadHistoryItem item) {
    final source = item.sourceId == 'local'
        ? LocalComicSource()
        : SourceManager.getById(item.sourceId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderPage(
          source: source,
          chapters: [
            ComicChapter(title: item.chapterTitle, url: item.chapterUrl),
          ],
          initialIndex: 0,
        ),
      ),
    ).then((_) => _refresh());
  }

  String _formatTime(int millis) {
    if (millis <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$m/$d $h:$min';
  }

  Widget _buildCover(ReadHistoryItem item) {
    if (item.cover.isEmpty) {
      return Container(
        width: 48,
        height: 64,
        color: Colors.black12,
        child: const Icon(Icons.menu_book_outlined, color: Colors.black38),
      );
    }
    if (!item.cover.startsWith('http://') &&
        !item.cover.startsWith('https://')) {
      return Image.file(
        File(item.cover),
        width: 48,
        height: 64,
        fit: BoxFit.cover,
      );
    }
    final source = SourceManager.getById(item.sourceId);
    return CachedNetworkImage(
      imageUrl: item.cover,
      httpHeaders: source.getImageHeaders(item.comicUrl),
      width: 48,
      height: 64,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => Container(
        width: 48,
        height: 64,
        color: Colors.black12,
        child: const Icon(Icons.broken_image_outlined, color: Colors.black38),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ArchiveScaffold(
      title: '閱讀歷史',
      subtitle: 'ARCHIVE / READING LOG',
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Color(0xFF1F1F1F)),
        onPressed: () async {
          await HistoryService.clearAll();
          AppSettings.instance.clearHistory();
          await _refresh();
        },
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _sectionTag('02 / READING LOG', '最近閱讀 (${_items.length} 本書)'),
                const Text(
                  '未收藏的作品也會記錄。長按單筆可移除記錄，點擊可直接續讀。',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 14),
                if (_items.isEmpty)
                  _cardBox(
                    padding: const EdgeInsets.all(24),
                    child: const Center(
                      child: Text(
                        '暫無閱讀歷史記錄',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  )
                else
                  ..._items.map(
                    (h) => _cardBox(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _buildCover(h),
                        ),
                        title: Text(
                          h.comicTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${h.chapterTitle} · 第 ${h.pageIndex + 1} 頁\n${_formatTime(h.updatedAt)}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.black38,
                        ),
                        onTap: () => _openHistory(h),
                        onLongPress: () async {
                          await HistoryService.removeItem(h);
                          await _refresh();
                        },
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// 7. 離線緩存 (ARCHIVE / LOCAL STORAGE)
class OfflineCachePage extends StatelessWidget {
  const OfflineCachePage({super.key});

  @override
  Widget build(BuildContext context) {
    return _ArchiveScaffold(
      title: '離線緩存',
      subtitle: 'ARCHIVE / LOCAL STORAGE',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _sectionTag('01 / CATALOG', '本地存儲'),
          const Text(
            '已緩存圖片可離線閱讀。清理緩存不會移出書架，也不會刪除閱讀進度。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          _cardBox(
            padding: const EdgeInsets.all(24),
            child: const Column(
              children: [
                Icon(Icons.cloud_done_outlined, size: 36, color: Colors.black45),
                SizedBox(height: 8),
                Text('目前暫無離線下載章節', style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 8. 書籤 (PERSONAL / EXCERPTS)
class BookmarksPage extends StatelessWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (_, __) => _ArchiveScaffold(
        title: '書籤',
        subtitle: 'PERSONAL / EXCERPTS',
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _sectionTag('01 / EXCERPTS', '書籤分類 (${s.bookmarksByBook.length} 本書)'),
            if (s.bookmarksByBook.isEmpty)
              _cardBox(
                padding: const EdgeInsets.all(24),
                child: const Center(child: Text('暫無書籤與標記', style: TextStyle(color: Colors.black54))),
              )
            else
              ...s.bookmarksByBook.entries.map(
                (e) => _cardBox(
                  child: ListTile(
                    leading: const Icon(Icons.menu_book_outlined, color: Color(0xFF1F1F1F)),
                    title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${e.value} 條書籤與標記'),
                    trailing: const Icon(Icons.chevron_right, color: Colors.black38),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 9. 統計 (PERSONAL / READING RECORDS - 含指尖落點熱力圖)
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  bool _landscapeView = false;

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (_, __) {
        final maxVal = s.touchHeatmap.fold<int>(1, (a, b) => a > b ? a : b);

        return _ArchiveScaffold(
          title: '統計',
          subtitle: 'PERSONAL / READING RECORDS',
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _cardBox(
                child: SwitchListTile(
                  title: const Text('記錄已開啟', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('正文觸碰起點 · 本機累計', style: TextStyle(fontSize: 12)),
                  value: s.recordTouches,
                  activeColor: const Color(0xFF1F1F1F),
                  onChanged: (v) => s.update(() => s.recordTouches = v),
                ),
              ),
              _sectionTag('READING / FINGERPRINT', '指尖落點'),
              Text(
                '${s.totalTouches}',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F)),
              ),
              const Text('累計觸碰', style: TextStyle(color: Colors.black54, fontSize: 12)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _landscapeView = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_landscapeView ? const Color(0xFFEBE9E4) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: const Text('豎屏', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _landscapeView = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _landscapeView ? const Color(0xFFEBE9E4) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: const Text('橫屏', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Container(
                  width: _landscapeView ? 300 : 210,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E2DA)),
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _landscapeView ? 14 : 10,
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 3,
                    ),
                    itemCount: s.touchHeatmap.length,
                    itemBuilder: (_, i) {
                      final count = s.touchHeatmap[i];
                      final ratio = count == 0 ? 0.05 : (count / maxVal).clamp(0.15, 1.0);
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(ratio * 0.85),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
