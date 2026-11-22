import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/comic.dart';
import 'pages/detail_page.dart';
import 'sources/comic_source.dart';

void main() {
  runApp(const ComicReaderApp());
}

class ComicReaderApp extends StatelessWidget {
  const ComicReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Comic Archive',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F6F2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F1F1F),
          surface: const Color(0xFFF7F6F2),
        ),
        fontFamilyFallback: const ['PingFang TC', 'Noto Sans TC', 'sans-serif'],
      ),
      home: const ArchiveHomeShell(),
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
  int _tabIndex = 0; // 0:發現, 1:書架, 2:本地, 3:我的
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
        title: const Text('搜尋漫畫', style: TextStyle(fontWeight: FontWeight.bold)),
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
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1F1F1F)),
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
                    title: Text(src.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(src.baseUrl, style: const TextStyle(fontSize: 12)),
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
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 255, 255, 0.86),
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
                child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
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
          _filterBar('最近更新', '${_discoverList.length} 本', onTap: _showSourcePicker),
          const SizedBox(height: 16),
          if (_loading)
            const SizedBox(
              height: 320,
              child: Center(child: CircularProgressIndicator(color: Color(0xFF1F1F1F))),
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
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1F1F1F)),
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
                activeIndex: _discoverActiveIdx.clamp(0, carouselItems.length - 1),
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
        _sectionHeader('COLLECTION / REGION', '
