import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/comic.dart';
import '../sources/comic_source.dart';

class ReaderPage extends StatefulWidget {
  final ComicSource source;
  final List<ComicChapter> chapters;
  final int initialIndex;

  const ReaderPage({
    super.key,
    required this.source,
    required this.chapters,
    required this.initialIndex,
  });

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late int _currentIndex = widget.initialIndex;
  List<String> _images = [];
  bool _loading = true;
  bool _showOverlay = true;
  String? _error;

  ComicChapter get _currentChapter => widget.chapters[_currentIndex];

  @override
  void initState() {
    super.initState();
    _loadChapter();
  }

  Future<void> _loadChapter() async {
    setState(() {
      _loading = true;
      _error = null;
      _images = [];
    });
    try {
      final urls = await widget.source.getChapterImages(_currentChapter.url);
      if (mounted) {
        setState(() {
          _images = urls;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '圖片載入失敗：$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showOverlay = !_showOverlay),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _error != null
                    ? Center(
                        child: Text(_error!, style: const TextStyle(color: Colors.white)),
                      )
                    : ListView.builder(
                        itemCount: _images.length,
                        itemBuilder: (context, i) {
                          return CachedNetworkImage(
                            imageUrl: _images[i],
                            httpHeaders: widget.source.getImageHeaders(_currentChapter.url),
                            fit: BoxFit.fitWidth,
                            placeholder: (_, __) => const SizedBox(
                              height: 360,
                              child: Center(
                                child: CircularProgressIndicator(color: Colors.white54),
                              ),
                            ),
                            errorWidget: (_, __, ___) => const SizedBox(
                              height: 200,
                              child: Center(
                                child: Icon(Icons.broken_image, color: Colors.white54),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (_showOverlay)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppBar(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                title: Text(_currentChapter.title, style: const TextStyle(fontSize: 15)),
              ),
            ),
          if (_showOverlay)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _currentIndex < widget.chapters.length - 1
                            ? () {
                                _currentIndex++;
                                _loadChapter();
                              }
                            : null,
                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                        label: const Text('上一話', style: TextStyle(color: Colors.white)),
                      ),
                      Text(
                        '共 ${_images.length} 頁',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      TextButton.icon(
                        onPressed: _currentIndex > 0
                            ? () {
                                _currentIndex--;
                                _loadChapter();
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right, color: Colors.white),
                        label: const Text('下一話', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
