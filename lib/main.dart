import 'dart:convert';
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
      title: 'Comic Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4A6CF7),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF4A6CF7),
      ),
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tabIndex = 1; // 預設進入「發現」頁
  List<ComicItem> _bookshelf = [];
  List<ComicItem> _discoverList = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBookshelf();
    _loadDiscover();
  }

  Future<void> _loadBookshelf() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('bookshelf') ?? [];
    setState(() {
      _bookshelf = raw
          .map((e) => ComicItem.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
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
      setState(() {
        _discoverList = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '載入失敗：$e';
        _loading = false;
      });
    }
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('選擇漫畫網站書源', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...SourceManager.sources.map(
              (src) => ListTile(
                leading: const Icon(Icons.public),
                title: Text(src.name),
                subtitle: Text(src.baseUrl),
                trailing: src.id == SourceManager.current.id
                    ? const Icon(Icons.check_circle, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => SourceManager.current = src);
                  Navigator.pop(context);
                  _loadDiscover(keyword: _searchCtrl.text);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(ComicItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailPage(item: item)),
    );
    _loadBookshelf();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(_tabIndex == 0 ? '我的書架' : SourceManager.current.name),
        actions: [
          IconButton(
            tooltip: '切換書源',
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: _showSourcePicker,
          ),
        ],
      ),
      body: _tabIndex == 0 ? _buildBookshelf() : _buildDiscover(),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color.fromRGBO(30, 30, 36, 0.78)
                    : const Color.fromRGBO(255, 255, 255, 0.80),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navItem(Icons.collections_bookmark_rounded, '書架', 0),
                  _navItem(Icons.explore_rounded, '發現', 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final selected = _tabIndex == index;
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: () => setState(() => _tabIndex = index),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookshelf() {
    if (_bookshelf.isEmpty) {
      return const Center(child: Text('書架還是空的，去「發現」收藏幾本漫畫吧！'));
    }
    return _buildComicGrid(_bookshelf);
  }

  Widget _buildDiscover() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (val) => _loadDiscover(keyword: val),
            decoration: InputDecoration(
              hintText: '搜尋漫畫名稱...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchCtrl.clear();
                  _loadDiscover();
                },
              ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => _loadDiscover(keyword: _searchCtrl.text),
                            child: const Text('重試'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadDiscover(keyword: _searchCtrl.text),
                      child: _buildComicGrid(_discoverList),
                    ),
        ),
      ],
    );
  }

  Widget _buildComicGrid(List<ComicItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.62,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final source = SourceManager.getById(item.sourceId);
        return GestureDetector(
          onTap: () => _openDetail(item),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: item.cover,
                    httpHeaders: source.getImageHeaders(item.url),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.black12),
                    errorWidget: (_, __, ___) => const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }
}
