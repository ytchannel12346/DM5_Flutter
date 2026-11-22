import 'dart:io';
import '../models/comic.dart';
import 'comic_source.dart';

class LocalComicSource extends ComicSource {
  @override
  String get id => 'local';

  @override
  String get name => '本地書庫';

  @override
  String get baseUrl => '';

  @override
  Map<String, String> getImageHeaders(String refererUrl) => const {};

  @override
  Future<List<ComicItem>> getPopular({int page = 1}) async => [];

  @override
  Future<List<ComicItem>> search(String keyword, {int page = 1}) async => [];

  @override
  Future<ComicDetail> getDetail(ComicItem item) async {
    return ComicDetail(
      item: item,
      author: '本地匯入',
      description: '本地漫畫檔案',
      chapters: [ComicChapter(title: item.title, url: item.url)],
    );
  }

  @override
  Future<List<String>> getChapterImages(String chapterUrl) async {
    final dir = Directory(chapterUrl);
    if (!await dir.exists()) return [];

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => RegExp(r'\.(jpg|jpeg|png|webp)$', caseSensitive: false)
            .hasMatch(f.path))
        .toList();

    files.sort((a, b) => _naturalCompare(
          a.uri.pathSegments.last,
          b.uri.pathSegments.last,
        ));

    return files.map((f) => f.path).toList();
  }

  int _naturalCompare(String a, String b) {
    final reg = RegExp(r'(\d+|\D+)');
    final aParts = reg.allMatches(a).map((m) => m.group(0)!).toList();
    final bParts = reg.allMatches(b).map((m) => m.group(0)!).toList();
    final len = aParts.length < bParts.length ? aParts.length : bParts.length;

    for (var i = 0; i < len; i++) {
      final aNum = int.tryParse(aParts[i]);
      final bNum = int.tryParse(bParts[i]);
      final cmp = (aNum != null && bNum != null)
          ? aNum.compareTo(bNum)
          : aParts[i].compareTo(bParts[i]);
      if (cmp != 0) return cmp;
    }
    return aParts.length.compareTo(bParts.length);
  }
}
