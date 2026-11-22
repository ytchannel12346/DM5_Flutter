import 'dart:io';
import 'package:flutter/material.dart';
import '../models/comic.dart';
import '../services/local_comic_service.dart';
import '../sources/local_comic_source.dart';
import 'reader_page.dart';

class LocalPage extends StatefulWidget {
  const LocalPage({super.key});

  @override
  State<LocalPage> createState() => _LocalPageState();
}

class _LocalPageState extends State<LocalPage> {
  List<LocalBook> _books = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final books = await LocalComicService.loadBooks();
    if (mounted) {
      setState(() {
        _books = books;
        _loading = false;
      });
    }
  }

  Future<void> _importArchive() async {
    try {
      final book = await LocalComicService.importArchive();
      if (book != null) await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('匯入失敗：$e')),
        );
      }
    }
  }

  Future<void> _importImages() async {
    try {
      final book = await LocalComicService.importImages();
      if (book != null) await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('匯入失敗：$e')),
        );
      }
    }
  }

  void _openBook(LocalBook book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderPage(
          source: LocalComicSource(),
          chapters: [ComicChapter(title: book.title, url: book.dirPath)],
          initialIndex: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F6F2),
        elevation: 0,
        title: const Text(
          '本地漫畫',
          style: TextStyle(color: Color(0xFF1F1F1F), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: '匯入 ZIP / CBZ',
            icon: const Icon(Icons.folder_zip_outlined, color: Color(0xFF1F1F1F)),
            onPressed: _importArchive,
          ),
          IconButton(
            tooltip: '匯入圖片',
            icon: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF1F1F1F)),
            onPressed: _importImages,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _books.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '尚無本地漫畫',
                        style: TextStyle(color: Colors.black54, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _importArchive,
                        icon: const Icon(Icons.folder_zip_outlined),
                        label: const Text('匯入 CBZ / ZIP'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _books.length,
                  itemBuilder: (_, i) {
                    final book = _books[i];
                    return GestureDetector(
                      onTap: () => _openBook(book),
                      onLongPress: () async {
                        await LocalComicService.deleteBook(book);
                        await _refresh();
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(book.coverPath),
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${book.pageCount} 頁',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
