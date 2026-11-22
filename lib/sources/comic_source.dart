import '../models/comic.dart';
import 'dm5_source.dart';

abstract class ComicSource {
  String get id;
  String get name;
  String get baseUrl;

  Map<String, String> getImageHeaders(String refererUrl);

  Future<List<ComicItem>> getPopular({int page = 1});
  Future<List<ComicItem>> search(String keyword, {int page = 1});
  Future<ComicDetail> getDetail(ComicItem item);
  Future<List<String>> getChapterImages(String chapterUrl);
}

class SourceManager {
  static final List<ComicSource> sources = [
    Dm5Source(),
    // 未來可以在這裡直接加入其他網站，例如：ManhuaguiSource(),
  ];

  static ComicSource current = sources.first;

  static ComicSource getById(String id) {
    return sources.firstWhere(
      (s) => s.id == id,
      orElse: () => sources.first,
    );
  }
}
