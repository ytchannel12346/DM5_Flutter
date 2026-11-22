import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/comic.dart';
import 'comic_source.dart';

class Dm5Source extends ComicSource {
  @override
  String get id => 'dm5';

  @override
  String get name => '動漫屋 (DM5)';

  @override
  String get baseUrl => 'https://www.dm5.com';

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
        'Cookie': 'isAdult=1',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-TW,zh;q=0.9,en;q=0.8',
      },
    ),
  );

  String _toFullUrl(String url, {String? preferredOrigin}) {
    final trimmed = url.trim();
    final origin = preferredOrigin ?? baseUrl;
    if (trimmed.isEmpty) return '$origin/';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }
    return '$origin${trimmed.startsWith('/') ? '' : '/'}$trimmed';
  }

  @override
  Map<String, String> getImageHeaders(String refererUrl) => {
        'Referer': 'https://www.dm5.com/',
        'User-Agent': _ua,
        'Accept':
            'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      };

  @override
  Future<List<ComicItem>> getPopular({int page = 1}) async {
    final path = page <= 1 ? '/manhua-list/' : '/manhua-list-p$page/';
    final res = await _dio.get(path);
    return _parseList(res.data.toString());
  }

  @override
  Future<List<ComicItem>> search(String keyword, {int page = 1}) async {
    final res = await _dio.get(
      '/search',
      queryParameters: {
        'title': keyword.trim(),
        'language': 1,
        'page': page,
      },
    );
    return _parseList(res.data.toString());
  }

  List<ComicItem> _parseList(String htmlStr) {
    final doc = html_parser.parse(htmlStr);
    final results = <ComicItem>[];
    final seenUrls = <String>{};

    for (final card in doc.querySelectorAll('.mh-list li, .mh-item')) {
      final anchor = card.querySelector('.mh-item-detali h2.title a, h2.title a, a[href]');
      final href = anchor?.attributes['href']?.trim() ?? '';
      if (href.isEmpty || href.startsWith('javascript:')) continue;

      final fullUrl = _toFullUrl(href);
      if (!seenUrls.add(fullUrl)) continue;

      final coverStyle =
          card.querySelector('.mh-cover')?.attributes['style'] ?? '';
      final coverMatch = RegExp(r'url\(([^)]+)\)').firstMatch(coverStyle);
      final rawCover = coverMatch != null
          ? coverMatch.group(1)!.replaceAll(RegExp(r'''["']'''), '').trim()
          : (card.querySelector('img')?.attributes['src'] ?? '');

      final title = (anchor?.attributes['title'] ?? anchor?.text ?? '').trim();
      if (title.isEmpty) continue;

      final latest = (card.querySelector('.chapter a, .chapter')?.text ?? '').trim();

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

    final title =
        (doc.querySelector('.banner_detail_form .info .title')?.text ?? '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    final rawCover =
        doc.querySelector('.banner_detail_form .cover img')?.attributes['src'] ??
            '';
    final author =
        (doc.querySelector('.banner_detail_form .info .subtitle')?.text ?? '')
            .trim();
    final desc =
        (doc.querySelector('.banner_detail_form .info .content')?.text ?? '暫無簡介')
            .trim();

    final chapters = doc
        .querySelectorAll('#chapterlistload ul li a')
        .map((a) {
          final href = a.attributes['href'] ?? '';
          final chTitle = (a.attributes['title'] ?? a.text)
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          return ComicChapter(
            title: chTitle.isNotEmpty ? chTitle : a.text.trim(),
            url: _toFullUrl(href),
          );
        })
        .where((c) => c.url.isNotEmpty && c.title.isNotEmpty)
        .toList();

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

    final cid = RegExp(r'DM5_CID\s*=\s*(\d+)').firstMatch(htmlStr)?.group(1);
    final mid = RegExp(r'DM5_MID\s*=\s*(\d+)').firstMatch(htmlStr)?.group(1) ?? '';
    final count = int.tryParse(
          RegExp(r'DM5_IMAGE_COUNT\s*=\s*(\d+)').firstMatch(htmlStr)?.group(1) ??
              '0',
        ) ??
        0;
    final sign =
        RegExp(r'''DM5_VIEWSIGN\s*=\s*["']([^"']+)["']''').firstMatch(htmlStr)?.group(1) ??
            '';
    final dt = RegExp(r'''DM5_VIEWSIGN_DT\s*=\s*["']([^"']+)["']''')
            .firstMatch(htmlStr)
            ?.group(1) ??
        '';

    if (cid == null || count == 0) {
      throw Exception('無法解析 DM5 章節參數');
    }

    final images = <String>[];
    final seen = <String>{};

    for (var page = 1; page <= count; page++) {
      if (images.length >= count) break;
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
        options: Options(
          headers: {
            'Referer': fullUrl,
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      final unpacked = _unpackJs(funRes.data.toString());
      final urls = _extractUrls(unpacked);
      for (final u in urls) {
        if (seen.add(u)) {
          images.add(u);
        }
      }
      if (urls.length > 1) {
        page += urls.length - 1;
      }
    }

    if (images.isEmpty) {
      throw Exception('DM5 未回傳章節圖片');
    }
    return images;
  }

  List<String> _extractUrls(String js) {
    final pix =
        RegExp(r'''var\s+pix\s*=\s*["']([^"']+)["']''').firstMatch(js)?.group(1) ??
            '';
    final pvalueMatch =
        RegExp(r'''var\s+pvalue\s*=\s*\[([^\]]+)\]''').firstMatch(js);
    if (pvalueMatch == null) return [];

    final query =
        RegExp(r'''var\s+query\s*=\s*["']([^"']*)["']''').firstMatch(js)?.group(1) ??
            '';

    return RegExp(r'''["']([^"']+)["']''')
        .allMatches(pvalueMatch.group(1)!)
        .map((m) {
          final file = m.group(1)!;
          if (file.startsWith('http://') || file.startsWith('https://')) {
            return '$file$query';
          }
          return '$pix$file$query';
        })
        .where((u) => u.startsWith('http'))
        .toList();
  }

  String _unpackJs(String packed) {
    final match = RegExp(
      r"\}\('(.*)',\s*(\d+),\s*(\d+),\s*'([^']*)'\.split\('\|'\)",
      dotAll: true,
    ).firstMatch(packed);
    if (match == null) return packed;

    final payload = match.group(1)!;
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
