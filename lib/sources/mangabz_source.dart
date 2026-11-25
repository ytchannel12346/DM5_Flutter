import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/comic.dart';
import 'comic_source.dart';

class MangabzSource extends ComicSource {
  @override
  String get id => 'mangabz';

  @override
  String get name => 'MangaBZ';

  @override
  String get baseUrl => 'https://www.mangabz.com';

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
        'Referer': '$baseUrl/',
        'Cookie': 'mangabz_machineid=1; isAdult=1',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
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
        'Referer': refererUrl.isNotEmpty ? refererUrl : '$baseUrl/',
        'User-Agent': _ua,
        'Accept':
            'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      };

  @override
  Future<List<ComicItem>> getPopular({int page = 1}) async {
    final path = page <= 1 ? '/manga-list/' : '/manga-list-p$page/';
    final res = await _dio.get(path);
    return _parseComicList(res.data.toString(), sourcePath: path);
  }

  @override
  Future<List<ComicItem>> search(String keyword, {int page = 1}) async {
    final res = await _dio.get(
      '/search/',
      queryParameters: {
        'title': keyword.trim(),
        if (page > 1) 'page': page,
      },
      options: Options(headers: {'Referer': '$baseUrl/search/'}),
    );
    return _parseComicList(res.data.toString(), sourcePath: '/search/');
  }

  List<ComicItem> _parseComicList(
    String htmlStr, {
    required String sourcePath,
  }) {
    if (htmlStr.trim().isEmpty) {
      throw Exception('MangaBZ ($sourcePath) 回傳空白內容');
    }

    final doc = html_parser.parse(htmlStr);
    final results = <ComicItem>[];
    final seenUrls = <String>{};

    final cards = doc.querySelectorAll(
      '.mh-list li, .book-list li, .manga-list li, .list-con li, li',
    );

    for (final card in cards) {
      final anchor = card.querySelector('a[href]');
      final href = anchor?.attributes['href']?.trim() ?? '';
      if (href.isEmpty ||
          href.startsWith('#') ||
          href.toLowerCase().startsWith('javascript:')) {
        continue;
      }
      if (href.contains('/search') ||
          href.contains('/manga-list') ||
          href.contains('/tag') ||
          href.contains('/rank') ||
          href.contains('/login')) {
        continue;
      }

      final fullUrl = _toFullUrl(href);
      if (!seenUrls.add(fullUrl)) continue;

      final img = card.querySelector('img');
      final coverStyle =
          card.querySelector('.mh-cover, [style*="background"]')?.attributes['style'] ??
              card.attributes['style'] ??
              '';
      final rawCover = img?.attributes['data-src'] ??
          img?.attributes['src'] ??
          _extractCssUrl(coverStyle);

      final title = (card.querySelector('.title a, .title, .book-title, h2, h3, p.title')?.text ??
              anchor?.attributes['title'] ??
              img?.attributes['alt'] ??
              anchor?.text ??
              '')
          .trim();

      if (title.isEmpty || title.length > 100) continue;

      final latest = (card
                  .querySelector('.chapter a, .chapter, .update, .status, p.chapter')
                  ?.text ??
              '')
          .trim();

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

    if (results.isEmpty) {
      throw Exception('MangaBZ ($sourcePath) 未解析出漫畫項目');
    }

    return results;
  }

  @override
  Future<ComicDetail> getDetail(ComicItem item) async {
    final fullUrl = _toFullUrl(item.url);
    final res = await _dio.get(fullUrl);
    final doc = html_parser.parse(res.data.toString());

    final title =
        (doc.querySelector('.detail-main-info-title, .book-title, h1')?.text ??
                '')
            .trim();
    final img = doc.querySelector(
      '.detail-main-cover img, .book-cover img, .cover img, img',
    );
    final rawCover =
        img?.attributes['data-src'] ?? img?.attributes['src'] ?? '';
    final author = (doc
                .querySelector(
                  '.detail-main-info-author, .author a, .author, [class*="author"]',
                )
                ?.text ??
            '')
        .trim();
    final desc = (doc
                .querySelector(
                  '.detail-desc, .detail-main-info-content, .book-intro, .intro, .content',
                )
                ?.text ??
            '暫無簡介')
        .trim();

    final chapters = <ComicChapter>[];
    final seenChapterUrls = <String>{};

    for (final a in doc.querySelectorAll(
      '#chapterlistload a[href], #detail-list-select a[href], .chapter-list a[href], a[href*="/m"]',
    )) {
      final href = a.attributes['href']?.trim() ?? '';
      final chTitle = (a.attributes['title'] ?? a.text)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (href.isEmpty || chTitle.isEmpty) continue;
      if (!RegExp(r'/m\d+/?').hasMatch(href)) continue;

      final chUrl = _toFullUrl(href);
      if (!seenChapterUrls.add(chUrl)) continue;

      chapters.add(
        ComicChapter(
          title: chTitle,
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
      options: Options(headers: {'Referer': '$baseUrl/'}),
    );
    final htmlStr = res.data.toString();

    final cidMatch = RegExp(r'MANGABZ_CID\s*=\s*(\d+)').firstMatch(htmlStr);
    final midMatch = RegExp(r'MANGABZ_MID\s*=\s*(\d+)').firstMatch(htmlStr);
    final countMatch =
        RegExp(r'MANGABZ_IMAGE_COUNT\s*=\s*(\d+)').firstMatch(htmlStr);
    final signMatch = RegExp(r'''MANGABZ_VIEWSIGN\s*=\s*["']([^"']+)["']''')
        .firstMatch(htmlStr);
    final dtMatch = RegExp(r'''MANGABZ_VIEWSIGN_DT\s*=\s*["']([^"']+)["']''')
        .firstMatch(htmlStr);

    if (cidMatch == null || countMatch == null) {
      throw Exception('無法解析 MangaBZ 章節參數');
    }

    final cid = cidMatch.group(1)!;
    final mid = midMatch?.group(1) ?? '0';
    final imageCount = int.parse(countMatch.group(1)!);
    final sign = signMatch?.group(1) ?? '';
    final dt = dtMatch?.group(1) ?? '';

    final images = <String>[];
    int page = 1;
    while (page <= imageCount && images.length < imageCount) {
      final funRes = await _dio.get(
        '$baseUrl/m$cid/chapterimage.ashx',
        queryParameters: {
          'cid': cid,
          'page': page,
          'key': '',
          '_cid': cid,
          '_mid': mid,
          '_dt': dt,
          '_sign': sign,
        },
        options: Options(headers: {'Referer': fullUrl}),
      );

      final unpacked = _unpackJs(funRes.data.toString());
      final pageUrls = RegExp(
        r'''["'](https?://[^"']+\.(?:jpg|jpeg|png|webp)[^"']*)["']''',
        caseSensitive: false,
      ).allMatches(unpacked).map((m) => m.group(1)!).toList();

      if (pageUrls.isEmpty) {
        page++;
        continue;
      }

      for (final u in pageUrls) {
        if (!images.contains(u)) {
          images.add(u);
        }
      }
      page += pageUrls.length;
    }

    if (images.isEmpty) {
      throw Exception('無法解析 MangaBZ 章節圖片');
    }
    return images;
  }

  String _unpackJs(String packed) {
    final match = RegExp(
      r"\}\('((?:\\.|[^'\\])*)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'([^']*)'\.split\('\|'\)",
      dotAll: true,
    ).firstMatch(packed);
    if (match == null) return packed;

    final payload = match
        .group(1)!
        .replaceAll(r"\'", "'")
        .replaceAll(r'\"', '"')
        .replaceAll(r'\\', r'\');
    final radix = int.parse(match.group(2)!);
    final count = int.parse(match.group(3)!);
    final symtab = match.group(4)!.split('|');

    String encodeBase(int num) {
      const chars =
          '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
      if (num == 0) return '0';
      var result = '';
      var n = num;
      while (n > 0) {
        result = chars[n % radix] + result;
        n ~/= radix;
      }
      return result;
    }

    final dict = <String, String>{};
    for (int i = count - 1; i >= 0; i--) {
      final key = encodeBase(i);
      dict[key] = (i < symtab.length && symtab[i].isNotEmpty) ? symtab[i] : key;
    }

    return payload.replaceAllMapped(
      RegExp(r'\b\w+\b'),
      (m) => dict[m.group(0)] ?? m.group(0)!,
    );
  }
}
