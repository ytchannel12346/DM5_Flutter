import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/comic.dart';
import '../services/history_service.dart';
import '../sources/comic_source.dart';
import '../sources/local_comic_source.dart';
import 'reader_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
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

  Widget _buildCover(ReadHistoryItem item) {
    if (item.cover.isEmpty) {
      return Container(
        width: 56,
        height: 76,
        color: Colors.black12,
        child: const Icon(Icons.menu_book_rounded, color: Colors.black38),
      );
    }
    if (!item.cover.startsWith('http://') &&
        !item.cover.startsWith('https://')) {
      return Image.file(
        File(item.cover),
        width: 56,
        height: 76,
        fit: BoxFit.cover,
      );
    }
    final source = SourceManager.getById(item.sourceId);
    return CachedNetworkImage(
      imageUrl: item.cover,
      httpHeaders: source.getImageHeaders(item.comicUrl),
      width: 56,
      height: 76,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => Container(
        width: 56,
        height: 76,
        color: Colors.black12,
        child: const Icon(Icons.broken_image_outlined, color: Colors.black38),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F6F2),
        elevation: 0,
        title: const Text(
          '閱讀記錄',
          style: TextStyle(
            color: Color(0xFF1F1F1F),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              tooltip: '清空記錄',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFF1F1F1F),
              ),
              onPressed: () async {
                await HistoryService.clearAll();
                await _refresh();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Text(
                    '尚無閱讀記錄',
                    style: TextStyle(color: Colors.black54, fontSize: 15),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openHistory(item),
                      onLongPress: () async {
                        await HistoryService.removeItem(item);
                        await _refresh();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildCover(item),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.comicTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F1F1F),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '看到：${item.chapterTitle}（第 ${item.pageIndex + 1} 頁）',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(item.updatedAt),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black38,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.black38,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
