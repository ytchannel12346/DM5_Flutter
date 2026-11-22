import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/comic.dart';
import 'pages/detail_page.dart';
import 'pages/settings_pages.dart';
import 'services/app_settings.dart';
import 'sources/comic_source.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  runApp(const ComicReaderApp());
}

class ComicReaderApp extends StatelessWidget {
  const ComicReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final settings = AppSettings.instance;
        return MaterialApp(
          title: 'Comic Archive',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF7F6F2),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1F1F1F),
              surface: const Color(0xFFF7F6F2),
            ),
            fontFamilyFallback: const [
              'PingFang TC',
              'Noto Sans TC',
              'sans-serif',
            ],
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1F1F1F),
              brightness: Brightness.dark,
            ),
            fontFamilyFallback: const [
              'PingFang TC',
              'Noto Sans TC',
              'sans-serif',
            ],
          ),
          home: const ArchiveHomeShell(),
        );
      },
    );
  }
}

/// 暖紙白背景 + 淡方格線
class PaperGridBackground extends StatelessWidget {
  final Widget child;
  const PaperGridBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(color: Color(0xFFF7F6F2)),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _GridPainter()),
        ),
        child,
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEBE8E0)
      ..strokeWidth = 0.7;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ArchiveHomeShell extends StatefulWidget {
  const ArchiveHomeShell({super.key});

  @override
  State<ArchiveHomeShell> createState() => _ArchiveHomeShellState();
}

class _ArchiveHomeShellState extends State<ArchiveHomeShell> {
  late int _tabIndex = AppSettings.instance.startupTab.clamp(0, 3);
  List<ComicItem> _discoverList = [];
  List<ComicItem> _bookshelf = [];
  bool _loading = true;
  String? _error;

  int _discoverActiveIdx = 0;
  int _shelfActiveIdx = 0;

  @override
  void initState() {
    super.initState();
    _loadBookshelf();
    _loadDiscover();
  }

  Future<void> _loadBookshelf() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('bookshelf') ?? [];
    if (!mounted) return;
    setState(() {
      _bookshelf = raw
          .map((e) => ComicItem.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
      if (_shelfActiveIdx >= _bookshelf.length) _shelfActiveIdx = 0;
    });
  }

  Future<void> _loadDiscover({String keyword = ''}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = keyword.trim().isEmpty
          ? await SourceManager.current.getPopular()
          : await SourceManager.current.search(keyword.trim());
      if (!mounted) return;
      setState(() {
        _discoverList = list;
        _discoverActiveIdx = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '載入失敗：$e';
        _loading = false;
      });
    }
  }

  Future<void> _openDetail(ComicItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailPage(item: item)),
    );
    _loadBookshelf();
  }

  void _showSearchDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF7F6F2),
        title: const Text(
          '搜尋漫畫',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '輸入漫畫名稱...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2DFD7)),
            ),
          ),
          onSubmitted: (v) {
            Navigator.pop(ctx);
            setState(() => _tabIndex = 0);
            _loadDiscover(keyword: v);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadDiscover();
            },
            child: const Text('顯示熱門', style: TextStyle(color: Colors.black54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1F1F1F),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _tabIndex = 0);
              _loadDiscover(keyword: ctrl.text);
            },
            child: const Text('搜尋'),
          ),
        ],
      ),
    );
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF7F6F2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SOURCE / LIST',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: Colors.black45,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '漫畫書源',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              ...SourceManager.sources.map(
                (src) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E2DA)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.public, color: Color(0xFF1F1F1F)),
                    title: Text(
                      src.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      src.baseUrl,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: src.id == SourceManager.current.id
                        ? const Icon(Icons.check_circle, color: Color(0xFF1F1F1F))
                        : const Icon(Icons.chevron_right, color: Colors.black38),
                    onTap: () {
                      setState(() => SourceManager.current = src);
                      Navigator.pop(context);
                      _loadDiscover();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: PaperGridBackground(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _tabIndex,
            children: [
              _buildDiscoverTab(),
              _buildBookshelfTab(),
              _buildLocalTab(),
              _buildProfileTab(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildFloatingCapsuleNav(),
    );
  }

  /// 底部懸浮毛玻璃膠囊導覽列（平板自動置中限寬）
  Widget _buildFloatingCapsuleNav() {
    final settings = AppSettings.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: settings.glassBlur,
                sigmaY: settings.glassBlur,
              ),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(255, 255, 255, settings.glassOpacity),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: const Color(0xFFE5E2DA)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.06),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _navItem(Icons.explore_outlined, '發現', 0),
                    _navItem(Icons.library_books_outlined, '書架', 1),
                    _navItem(Icons.folder_outlined, '本地', 2),
                    _navItem(Icons.person_outline_rounded, '我的', 3),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final selected = _tabIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _tabIndex = index),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 21,
              color: selected ? const Color(0xFF1F1F1F) : Colors.black45,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? const Color(0xFF1F1F1F) : Colors.black45,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 14 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 01 發現頁
  Widget _buildDiscoverTab() {
    final carouselItems = _discoverList.take(10).toList();
    return RefreshIndicator(
      color: const Color(0xFF1F1F1F),
      onRefresh: () => _loadDiscover(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F1F),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    SourceManager.current.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F1F1F),
                    ),
                  ),
                  const Text(
                    'DM5 / READING ARCHIVE',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.4,
                      color: Colors.black45,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _circleIconButton(Icons.public, _showSourcePicker),
              const SizedBox(width: 8),
              _circleIconButton(Icons.search, _showSearchDialog),
            ],
          ),
          const SizedBox(height: 20),
          _sectionHeader('COLLECTION / REGION', '發現'),
          const SizedBox(height: 12),
          _filterBar(
            '最近更新',
            '${_discoverList.length} 本',
            onTap: _showSourcePicker,
          ),
          const SizedBox(height: 16),
          if (_loading)
            const SizedBox(
              height: 320,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF1F1F1F)),
              ),
            )
          else if (_error != null)
            SizedBox(
              height: 260,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1F1F1F),
                      ),
                      onPressed: () => _loadDiscover(),
                      child: const Text('重試'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            if (carouselItems.isNotEmpty)
              BookSpineCarousel(
                items: carouselItems,
                activeIndex:
                    _discoverActiveIdx.clamp(0, carouselItems.length - 1),
                onChanged: (i) => setState(() => _discoverActiveIdx = i),
                onOpen: _openDetail,
              ),
            const SizedBox(height: 28),
            _sectionHeader('02 / ARCHIVE INDEX', '更多漫畫'),
            const SizedBox(height: 14),
            _buildArchiveGrid(_discoverList),
          ],
        ],
      ),
    );
  }

  /// 02 書架頁
  Widget _buildBookshelfTab() {
    final carouselItems = _bookshelf.take(10).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: [
        Row(
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '書架',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F1F1F),
                  ),
                ),
                Text(
                  '02 / PERSONAL ARCHIVE',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    color: Colors.black45,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const Spacer(),
            _circleIconButton(Icons.search, _showSearchDialog),
          ],
        ),
        const SizedBox(height: 20),
        _sectionHeader('COLLECTION / REGION', '立體書架'),
        const SizedBox(height: 12),
        _filterBar('全部書籍', '${_bookshelf.length} 本'),
        const SizedBox(height: 16),
        if (_bookshelf.isEmpty)
          Container(
            height: 220,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E2DA)),
            ),
            child: const Text(
              '書架還是空的，去「發現」收藏幾本漫畫吧！',
              style: TextStyle(color: Colors.black54),
            ),
          )
        else ...[
          BookSpineCarousel(
            items: carouselItems,
            activeIndex: _shelfActiveIdx.clamp(0, carouselItems.length - 1),
            onChanged: (i) => setState(() => _shelfActiveIdx = i),
            onOpen: _openDetail,
          ),
          const SizedBox(height: 28),
          _sectionHeader('COLLECTION / REGION', '圖書列表'),
          const SizedBox(height: 14),
          _buildArchiveGrid(_bookshelf),
        ],
      ],
    );
  }

  /// 03 本地頁
  Widget _buildLocalTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: [
        const Text(
          '本地',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F1F1F),
          ),
        ),
        const Text(
          '03 / LOCAL ARCHIVE',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.4,
            color: Colors.black45,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E2DA)),
          ),
          child: const Column(
            children: [
              Icon(Icons.folder_zip_outlined, size: 40, color: Colors.black45),
              SizedBox(height: 12),
              Text(
                '暫無本地漫畫',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 6),
              Text(
                '未來可在此匯入本地 CBZ / ZIP 漫畫壓縮檔',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 04 我的頁
  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: [
        const Text(
          '我的',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F1F1F),
          ),
        ),
        const Text(
          '04 / PERSONAL ARCHIVE',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.4,
            color: Colors.black45,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 20),
        _profileCard(
          icon: Icons.account_box_outlined,
          title: 'Comic Reader',
          subtitle:
              '已收藏 ${_bookshelf.length} 本漫畫 · 書源：${SourceManager.current.name}',
          onTap: _showSourcePicker,
        ),
        _profileCard(
          icon: Icons.bar_chart_rounded,
          title: '統計',
          subtitle: '閱讀記錄、藏書與指尖落點',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StatsPage()),
          ),
        ),
        _profileCard(
          icon: Icons.bookmark_border_rounded,
          title: '書籤',
          subtitle: '${AppSettings.instance.bookmarksByBook.length} 本書的書籤與摘錄',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BookmarksPage()),
          ),
        ),
        _profileCard(
          icon: Icons.settings_outlined,
          title: '設置',
          subtitle: '閱讀、外觀、性能與本地數據',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsHubPage()),
          ),
        ),
        _profileCard(
          icon: Icons.info_outline_rounded,
          title: '關於',
          subtitle:
              '版本 ${const String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0')} · DM5 Flutter Archive',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _profileCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E2DA)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(icon, color: const Color(0xFF1F1F1F), size: 26),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.black38),
        onTap: onTap,
      ),
    );
  }

  Widget _circleIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E2DA)),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF1F1F1F)),
      ),
    );
  }

  Widget _sectionHeader(String mono, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              mono,
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
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
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F1F1F),
          ),
        ),
      ],
    );
  }

  Widget _filterBar(String label, String count, {VoidCallback? onTap}) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E2DA)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 17,
                    color: Color(0xFF1F1F1F),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(count, style: const TextStyle(color: Colors.black54, fontSize: 13)),
      ],
    );
  }

  /// 自適應網格（手機 3 欄，平板自動擴展為 5～7 欄）
  Widget _buildArchiveGrid(List<ComicItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: 0.60,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final src = SourceManager.getById(item.sourceId);
        return GestureDetector(
          onTap: () => _openDetail(item),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E2DA)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CachedNetworkImage(
                    imageUrl: item.cover,
                    httpHeaders: src.getImageHeaders(item.url),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const ColoredBox(color: Color(0xFFEFEDE7)),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F1F1F),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 3D 立體書脊輪播元件（支援平板寬螢幕）
class BookSpineCarousel extends StatelessWidget {
  final List<ComicItem> items;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final ValueChanged<ComicItem> onOpen;

  const BookSpineCarousel({
    super.key,
    required this.items,
    required this.activeIndex,
    required this.onChanged,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final activeItem = items[activeIndex];

    final indices = List.generate(items.length, (i) => i);
    indices.sort((a, b) {
      final da = (a - activeIndex).abs();
      final db = (b - activeIndex).abs();
      return db.compareTo(da);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final vx = details.primaryVelocity ?? 0;
            if (vx < -150 && activeIndex < items.length - 1) {
              onChanged(activeIndex + 1);
            } else if (vx > 150 && activeIndex > 0) {
              onChanged(activeIndex - 1);
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isTablet = width >= 600;
              final maxSideBooks = isTablet ? 6 : 4;

              return SizedBox(
                height: isTablet ? 320 : 290,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: indices.map((i) {
                    final diff = i - activeIndex;
                    if (diff.abs() > maxSideBooks) {
                      return const SizedBox.shrink();
                    }

                    final isSelected = diff == 0;
                    final double dx = isSelected
                        ? 0
                        : (diff > 0
                            ? 78.0 + (diff - 1) * 32.0
                            : -78.0 + (diff + 1) * 32.0);
                    final double dy =
                        isSelected ? -14.0 : 12.0 + diff.abs() * 3.0;
                    final double scale =
                        isSelected ? 1.0 : (0.90 - diff.abs() * 0.03);

                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      left: width / 2 + dx - (isSelected ? 78 : 22),
                      top: 32 + dy,
                      child: GestureDetector(
                        onTap: () => isSelected ? onOpen(items[i]) : onChanged(i),
                        child: Transform.scale(
                          scale: scale,
                          child: isSelected
                              ? _buildSelected3DBook(items[i], i)
                              : _buildSpineBook(items[i], i),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => onOpen(activeItem),
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeItem.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F1F1F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeItem.latestChapter.isNotEmpty
                          ? '${SourceManager.getById(activeItem.sourceId).name} · ${activeItem.latestChapter}'
                          : '${SourceManager.getById(activeItem.sourceId).name} · 連載中',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.north_east_rounded,
                size: 20,
                color: Color(0xFF1F1F1F),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed:
                  activeIndex > 0 ? () => onChanged(activeIndex - 1) : null,
            ),
            Text(
              '${(activeIndex + 1).toString().padLeft(2, '0')}  /  ${items.length.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Colors.black54,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: activeIndex < items.length - 1
                  ? () => onChanged(activeIndex + 1)
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  /// 選中的 3D 立體書（書脊 + 微傾封面）
  Widget _buildSelected3DBook(ComicItem item, int index) {
    final src = SourceManager.getById(item.sourceId);
    final numStr = (index + 1).toString().padLeft(2, '0');
    final noStr = 'NO.${(index + 1).toString().padLeft(3, '0')}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 220,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F2EE),
            border: Border.all(color: const Color(0xFFDAD7CE)),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.10),
                blurRadius: 10,
                offset: Offset(-4, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                numStr,
                style: const TextStyle(
                  fontSize: 9,
                  fontFamily: 'monospace',
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 1,
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F1F1F),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Transform(
          alignment: Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0018)
            ..rotateY(-0.22),
          child: Container(
            width: 132,
            height: 220,
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFDAD7CE)),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.14),
                  blurRadius: 16,
                  offset: Offset(6, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  noStr,
                  style: const TextStyle(
                    fontSize: 9,
                    fontFamily: 'monospace',
                    color: Colors.black45,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: CachedNetworkImage(
                      imageUrl: item.cover,
                      httpHeaders: src.getImageHeaders(item.url),
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const ColoredBox(color: Color(0xFFEFEDE7)),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'DM5-${(index + 1).toString().padLeft(4, '0')}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontFamily: 'monospace',
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 兩側排列的白色立體書脊
  Widget _buildSpineBook(ComicItem item, int index) {
    final numStr = (index + 1).toString().padLeft(2, '0');
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(math.pi / 24),
      child: Container(
        width: 34,
        height: 205,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDAD7CE)),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.07),
              blurRadius: 8,
              offset: Offset(2, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              numStr,
              style: const TextStyle(
                fontSize: 9,
                fontFamily: 'monospace',
                color: Colors.black45,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: RotatedBox(
                quarterTurns: 1,
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2B2B2B),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
