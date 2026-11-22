import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/comic.dart';
import 'comic_source.dart';

class ManhuarenSource extends ComicSource {
  @override
  String get id => 'manhuaren';

  @override
  String get name => '漫畫人 (Manhuaren)';

  @override
  String get baseUrl => 'https://www.manhuaren.com';

  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': _ua,
        'Referer': '$baseUrl/manhua-list/',
        'Accept-Language': 'zh-TW,zh;q=0.9,en;q=0.8',
      },
    ),
  );

  String _toFullUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '$baseUrl/';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }
    return '$baseUrl${trimmed.startsWith('/') ? '' : '/'}$trimmed';
  }

  String _extractCssUrl(String style) {
    final match = RegExp(r'url\(([^)]+)\)').firstMatch(style);
    if (match == null) return '';
    return match.group(1)!.replaceAll(RegExp(r'''["']'''), '').trim();
  }

  @override
  Map<String, String> getImageHeaders(String refererUrl) => {
        'Referer': _toFullUrl(refererUrl),
        'User-Agent': _ua,
        'Accept':
            'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      };

  /// Fetches comics from https://www.manhuaren.com/manhua-list/
  @override
  Future<List<ComicItem>> getPopular({int page = 1}) async {
    final path = page <= 1 ? '/manhua-list/' : '/manhua-list-p$page/';
    final res = await _dio.get(path);
    return _parseComicList(res.data.toString());
  }

  @override
  Future<List<ComicItem>> search(String keyword, {int page = 1}) async {
    final res = await _dio.get(
      '/search',
      queryParameters: {
        'title': keyword.trim(),
        'page': page,
      },
    );
    return _parseComicList(res.data.toString());
  }

  List<ComicItem> _parseComicList(String htmlStr) {
    final doc = html_parser.parse(htmlStr);
    final results = <ComicItem>[];
    final seenUrls = <String>{};

    final cards = doc.querySelectorAll(
      '.mh-list li, .manga-list li, .book-list li, .list-con li',
    );

    for (final card in cards) {
      final anchor = card.querySelector('a[href]');
      final href = anchor?.attributes['href']?.trim() ?? '';
      if (href.isEmpty) continue;

      final fullUrl = _toFullUrl(href);
      if (!seenUrls.add(fullUrl)) continue;

      final img = card.querySelector('img');
      final rawCover = img?.attributes['data-src'] ??
          img?.attributes['src'] ??
          _extractCssUrl(
            card.querySelector('[style*="background"]')?.attributes['style'] ??
                '',
          );

      final title = (img?.attributes['alt'] ??
              anchor?.attributes['title'] ??
              card.querySelector('.title, .mh-title, h3, h4, a')?.text ??
              '未命名')
          .trim();

      final latest = (card
                  .querySelector('.chapter, .update, .status, p.ell')
                  ?.text ??
              '')
          .trim();

      if (title.isEmpty) continue;

      results.add(
        ComicItem(
          sourceId: id,
          title: title,
          url: fullUrl,
          cover: rawCover.isEmpty ? '' : _toFullUrl(rawCover),
          latestChapter: latest,
        ),
      );
    }

    return results;
  }

  @override
  Future<ComicDetail> getDetail(ComicItem item) async {
    final fullUrl = _toFullUrl(item.url);
    final res = await _dio.get(fullUrl);
    final doc = html_parser.parse(res.data.toString());

    final title = (doc
                .querySelector('.detail-main-info .title, .book-title, h1')
                ?.text ??
            '')
        .trim();

    final img = doc.querySelector(
      '.detail-main-cover img, .book-cover img, .cover img, img',
    );
    final rawCover = img?.attributes['data-src'] ?? img?.attributes['src'] ?? '';

    final author = (doc
                .querySelector(
                  '.detail-main-info .author, .author a, [class*="author"]',
                )
                ?.text ??
            '')
        .trim();

    final desc = (doc
                .querySelector(
                  '.detail-main-info .content, .book-intro, .intro, .desc',
                )
                ?.text ??
            '暫無簡介')
        .trim();

    final chapters = <ComicChapter>[];
    final seenChapterUrls = <String>{};

    for (final a in doc.querySelectorAll(
      '#chapterlistload a[href], .chapter-list a[href], #detail-list-select a[href], a[href*="/m"]',
    )) {
      final href = a.attributes['href']?.trim() ?? '';
      final text = a.text.trim();
      if (href.isEmpty || text.isEmpty) continue;
      if (!RegExp(r'/m\d+/?').hasMatch(href) &&
          !RegExp(r'/\d+/\d+\.html').hasMatch(href)) {
        continue;
      }

      final chUrl = _toFullUrl(href);
      if (!seenChapterUrls.add(chUrl)) continue;

      chapters.add(
        ComicChapter(
          title: text,
          url: chUrl,
        ),
      );
    }

    return ComicDetail(
      item: ComicItem(
        sourceId: id,
        title: title.isNotEmpty ? title : item.title,
        url: fullUrl,
        cover: rawCover.isNotEmpty ? _toFullUrl(rawCover) : item.cover,
        latestChapter: item.latestChapter,
      ),
      author: author,
      description: desc.isEmpty ? '暫無簡介' : desc,
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> getChapterImages(String chapterUrl) async {
    final fullUrl = _toFullUrl(chapterUrl);
    final res = await _dio.get(
      fullUrl,
      options: Options(headers: {'Referer': fullUrl}),
    );
    final htmlStr = res.data.toString();
    final doc = html_parser.parse(htmlStr);

    // 1. Direct image elements when present in HTML
    final directUrls = doc
        .querySelectorAll('#cp_img img, #mangaFile, .viewer img, img[data-src]')
        .map((e) => e.attributes['data-src'] ?? e.attributes['src'] ?? '')
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty && !u.startsWith('data:'))
        .map(_toFullUrl)
        .toList();
    if (directUrls.isNotEmpty) {
      return directUrls.toSet().toList();
    }

    // 2. Extract image URLs from inline script arrays/variables if present
    final arrayMatch = RegExp(
      r'''(?:var\s+)?(?:picList|chapterImages|imageList|pvalue|files)\s*=\s*\[([^\]]+)\]''',
      caseSensitive: false,
    ).firstMatch(htmlStr);

    if (arrayMatch != null) {
      final urls = RegExp(r'''["'](https?://[^"']+|//[^"']+|/[^"']+)["']''')
          .allMatches(arrayMatch.group(1)!)
          .map((m) => _toFullUrl(m.group(1)!))
          .where((u) => u.isNotEmpty)
          .toList();
      if (urls.isNotEmpty) {
        return urls.toSet().toList();
      }
    }

    throw Exception(
      '無法直接解析 Manhuaren 章節圖片（可能需要動態腳本或 AJAX 介面）',
    );
  }
}
