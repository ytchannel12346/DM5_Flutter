import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comic.dart';
import '../sources/comic_source.dart';
import 'reader_page.dart';

class DetailPage extends StatefulWidget {
  final ComicItem item;
  const DetailPage({super.key, required this.item});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  ComicDetail? _detail;
  bool _loading = true;
  bool _inBookshelf = false;
  String? _error;

  late final ComicSource _source = SourceManager.getById(widget.item.sourceId);

  @override
  void initState() {
    super.initState();
    _checkBookshelf();
    _loadDetail();
  }

  Future<void> _checkBookshelf() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('bookshelf') ?? [];
    final exists = raw.any((e) {
      final m = jsonDecode(e) as Map<String, dynamic>;
      return m['url'] == widget.item.url;
    });
    if (mounted) setState(() => _inBookshelf = exists);
  }

  Future<void> _toggleBookshelf() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('bookshelf') ?? [];
    if (_inBookshelf) {
      raw.removeWhere((e) => (jsonDecode(e) as Map<String, dynamic>)['url'] == widget.item.url);
    } else {
      raw.insert(0, jsonEncode((_detail?.item ?? widget.item).toJson()));
    }
    await prefs.setStringList('bookshelf', raw);
    if (mounted) setState(() => _inBookshelf = !_inBookshelf);
  }

  Future<void> _loadDetail() async {
    try {
      final d = await _source.getDetail(widget.item);
      if (mounted) {
        setState(() {
          _detail = d;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '載入詳情失敗：$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayItem = _detail?.item ?? widget.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(displayItem.title),
        actions: [
          IconButton(
            icon: Icon(_inBookshelf ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _toggleBookshelf,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: displayItem.cover,
                            httpHeaders: _source.getImageHeaders(displayItem.url),
                            width: 110,
                            height: 155,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayItem.title,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              if (_detail!.author.isNotEmpty)
                                Text(_detail!.author, style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _toggleBookshelf,
                                icon: Icon(_inBookshelf ? Icons.check : Icons.add),
                                label: Text(_inBookshelf ? '已在書架' : '加入書架'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(_detail!.description, style: const TextStyle(height: 1.5)),
                    const Divider(height: 32),
                    Text(
                      '章節列表 (${_detail!.chapters.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_detail!.chapters.length, (i) {
                        final ch = _detail!.chapters[i];
                        return ActionChip(
                          label: Text(ch.title),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReaderPage(
                                  source: _source,
                                  chapters: _detail!.chapters,
                                  initialIndex: i,
                                ),
                              ),
                            );
                          },
                        );
                      }),
                    ),
                  ],
                ),
    );
  }
}
