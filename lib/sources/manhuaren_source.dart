import 'dart:convert';
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
        'Referer': '$baseUrl/',
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
        'Referer': '$baseUrl/',
        'User-Agent': _ua,
        'Accept':
            'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      };

  @override
  Future<List<ComicItem>> getPopular({int page = 1}) async {
    final res = await _dio.post(
      '/dm5.ashx',
      data: {
        'pagesize': 21,
        'pageindex': page,
        'tagid': 0,
        'status': 0,
        'usergroup': 0,
        'pay': -1,
        'areaid': 0,
        'sort': 10,
        'subject': 0,
        'action': 'getclasscomics',
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Referer': '$baseUrl/manhua-list/',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ),
    );

    final raw = res.data is String ? jsonDecode(res.data) : res.data;
    final items = (raw is Map ? raw['UpdateComicItems'] : null) as List? ?? [];

    final results = <ComicItem>[];
    for (final item in items) {
      if (item is! Map) continue;
      final title = (item['Title'] ?? '').toString().trim();
      final urlKey = (item['UrlKey'] ?? '').toString().trim();
      final cover = (item['ShowPicUrlB'] ?? item['ShowConver'] ?? '')
          .toString()
          .trim();
      final latest = (item['ShowLastPartName'] ?? '').toString().trim();
      if (title.isEmpty || urlKey.isEmpty) continue;

      results.add(
        ComicItem(
          sourceId: id,
          title: title,
          url: _toFullUrl('/$urlKey/'),
          cover: cover.isEmpty ? '' : _toFullUrl(cover),
          latestChapter: latest,
        ),
      );
    }

    if (results.isEmpty) {
      throw Exception('Manhuaren API 未回傳漫畫項目');
    }
    return results;
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
    return _parseComicList(res.data.toString(), sourcePath: '/search');
  }

  List<ComicItem> _parseComicList(
    String htmlStr, {
    required String sourcePath,
  }) {
    if (htmlStr.trim().isEmpty) {
      throw Exception('Manhuaren ($sourcePath) 回傳空白內容');
    }

    final doc = html_parser.parse(htmlStr);
    final results = <ComicItem>[];
    final seenUrls = <String>{};

    final cards = doc.querySelectorAll(
      '.manga-list-2 li, .mh-list li, .manga-list li, .book-list li, .list-con li, .mh-item, li, a[href]',
    );

    for (final card in cards) {
      final anchor = card.localName == 'a' ? card : card.querySelector('a[href]');
      final href = anchor?.attributes['href']?.trim() ?? '';
      if (href.isEmpty ||
          href.startsWith('#') ||
          href.toLowerCase().startsWith('javascript:')) {
        continue;
      }
      if (href.contains('/manhua-list') ||
          href.contains('/search') ||
          href.contains('/tag') ||
          href.contains('/category') ||
          href.contains('/rank') ||
          href.contains('/login')) {
        continue;
      }
      if (!RegExp(r'/\d+/?(?:\.html)?$').hasMatch(href) &&
          !RegExp(r'/\d+/').hasMatch(href) &&
          !RegExp(r'manhua-[^/]+', caseSensitive: false).hasMatch(href)) {
        continue;
      }

      final fullUrl = _toFullUrl(href);
      if (!seenUrls.add(fullUrl)) continue;

      final img = card.querySelector('img');
      final rawCover = img?.attributes['data-src'] ??
          img?.attributes['lz_src'] ??
          img?.attributes['src'] ??
          _extractCssUrl(
            card.querySelector('[style*="background"]')?.attributes['style'] ??
                card.attributes['style'] ??
                '',
          );

      final title = (img?.attributes['alt'] ??
              anchor?.attributes['title'] ??
              card
                  .querySelector('.title, .mh-title, .manga-list-2-title, h3, h4, p.ell, a')
                  ?.text ??
              anchor?.text ??
              '')
          .trim();

      if (title.isEmpty || title.length > 80) continue;

      final latest = (card
                  .querySelector('.chapter, .update, .status, .manga-list-2-tip, p.ell')
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
      final sampleLinks = doc
          .querySelectorAll('a[href]')
          .map((a) => a.attributes['href'] ?? '')
          .where((h) => h.isNotEmpty)
          .take(8)
          .join(', ');
      throw Exception(
        'Manhuaren ($sourcePath) 未解析出漫畫項目，連結樣本：$sampleLinks',
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
                .querySelector('.detail-main-info-title, .detail-main-info .title, .book-title, h1')
                ?.text ??
            '')
        .trim();

    final img = doc.querySelector(
      '.detail-main-cover img, .book-cover img, .cover img, img',
    );
    final rawCover =
        img?.attributes['data-src'] ?? img?.attributes['src'] ?? '';

    final author = (doc
                .querySelector(
                  '.detail-main-info-author, .detail-main-info .author, .author a, [class*="author"]',
                )
                ?.text ??
            '')
        .trim();

    final desc = (doc
                .querySelector(
                  '.detail-desc, .detail-main-info .content, .book-intro, .intro',
                )
                ?.text ??
            '暫無簡介')
        .trim();

    final chapters = <ComicChapter>[];
    final seenChapterUrls = <String>{};

    for (final a in doc.querySelectorAll(
      '#detail-list-select-1 a[href], #chapterlistload a[href], .chapter-list a[href], #detail-list-select a[href], a[href*="/m"]',
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
      options: Options(headers: {'Referer': '$baseUrl/'}),
    );
    final htmlStr = res.data.toString();

    final packedMatches = RegExp(
      r"eval\(function\(p,a,c,k,e,[dr]\).*?\)\)",
      dotAll: true,
    ).allMatches(htmlStr);

    for (final m in packedMatches) {
      final unpacked = _unpackJs(m.group(0)!);
      final urls = _extractImageUrls(unpacked);
      if (urls.isNotEmpty) return urls;
    }

    final cidMatch = RegExp(r'DM5_CID\s*=\s*(\d+)').firstMatch(htmlStr);
    final midMatch = RegExp(r'DM5_MID\s*=\s*(\d+)').firstMatch(htmlStr);
    final countMatch = RegExp(r'DM5_IMAGE_COUNT\s*=\s*(\d+)').firstMatch(htmlStr);
    final signMatch =
        RegExp(r'''DM5_VIEWSIGN\s*=\s*["']([^"']+)["']''').firstMatch(htmlStr);
    final dtMatch =
        RegExp(r'''DM5_VIEWSIGN_DT\s*=\s*["']([^"']+)["']''').firstMatch(htmlStr);

    if (cidMatch != null && countMatch != null) {
      final cid = cidMatch.group(1)!;
      final mid = midMatch?.group(1) ?? '0';
      final imageCount = int.parse(countMatch.group(1)!);
      final sign = signMatch?.group(1) ?? '';
      final dt = dtMatch?.group(1) ?? '';

      final images = <String>[];
      int page = 1;
      while (page <= imageCount && images.length < imageCount) {
        final funRes = await _dio.get(
          '$baseUrl/m$cid/chapterfun.ashx',
          queryParameters: {
            'cid': cid,
            'page': page,
            'key': '',
            'language': 1,
            'gtk': 6,
            '_cid': cid,
            '_mid': mid,
            '_dt': dt,
            '_sign': sign,
          },
          options: Options(headers: {'Referer': fullUrl}),
        );

        final unpacked = _unpackJs(funRes.data.toString());
        final pageUrls = _extractDm5Urls(unpacked);
        if (pageUrls.isEmpty) {
          page++;
          continue;
        }
        for (final u in pageUrls) {
          if (!images.contains(u)) images.add(u);
        }
        page += pageUrls.length;
      }
      if (images.isNotEmpty) return images;
    }

    final direct = _extractImageUrls(htmlStr);
    if (direct.isNotEmpty) return direct;

    throw Exception('無法解析 Manhuaren 章節圖片');
  }

  List<String> _extractImageUrls(String text) {
    final newImgsMatch = RegExp(
      r'''(?:newImgs|picList|chapterImages|imageList)\s*=\s*\[([^\]]+)\]''',
      caseSensitive: false,
    ).firstMatch(text);
    final target = newImgsMatch?.group(1) ?? text;

    return RegExp(
      r'''["'](https?://[^"']+\.(?:jpg|jpeg|png|webp)[^"']*)["']''',
      caseSensitive: false,
    )
        .allMatches(target)
        .map((m) => m.group(1)!)
        .toSet()
        .toList();
  }

  List<String> _extractDm5Urls(String unpacked) {
    final pixMatch =
        RegExp(r'''pix\s*=\s*["']([^"']+)["']''').firstMatch(unpacked);
    final pvalueMatch =
        RegExp(r'''pvalue\s*=\s*\[([^\]]+)\]''').firstMatch(unpacked);
    if (pixMatch == null || pvalueMatch == null) {
      return _extractImageUrls(unpacked);
    }

    final pix = pixMatch.group(1)!;
    final cidMatch = RegExp(r'\bcid\s*=\s*(\d+)').firstMatch(unpacked);
    final keyMatch =
        RegExp(r'''\bkey\s*=\s*["']([^"']+)["']''').firstMatch(unpacked);
    final ukMatch =
        RegExp(r'''\buk\s*=\s*["']([^"']+)["']''').firstMatch(unpacked);
    final directQueryMatch =
        RegExp(r'''["'](\?[^"']*cid=[^"']+)["']''').firstMatch(unpacked);
    final queryMatch =
        RegExp(r'''\bquery\s*=\s*["']([^"']+)["']''').firstMatch(unpacked);

    String query = directQueryMatch?.group(1) ?? queryMatch?.group(1) ?? '';
    if (query.isEmpty && keyMatch != null) {
      final cid = cidMatch?.group(1) ?? '';
      final key = keyMatch.group(1)!;
      final uk = ukMatch?.group(1) ?? '';
      query = '?cid=$cid&key=$key${uk.isNotEmpty ? '&uk=$uk' : ''}';
    }

    return RegExp(r'''["']([^"']+)["']''')
        .allMatches(pvalueMatch.group(1)!)
        .map((m) {
          final p = m.group(1)!;
          if (p.startsWith('http')) return p;
          if (p.contains('?')) return '$pix$p';
          return '$pix$p$query';
        })
        .toList();
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
