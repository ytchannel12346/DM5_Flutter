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
        'Cookie': 'isAdult=1',
        'Accept-Language': 'zh-CN,zh;q=0.9',
      },
    ),
  );

  @override
  Map<String, String> getImageHeaders(String refererUrl) => {
        'Referer': 'https://www.dm5.com/',
        'User-Agent': _ua,
        'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      };

  @override
  Future<List<ComicItem>> getPopular({int page = 1}) async {
    final res = await _dio.get('/manhua-list-p$page/');
    return _parseComicList(res.data.toString());
  }

  @override
  Future<List<ComicItem>> search(String keyword, {int page = 1}) async {
    final res = await _dio.get(
      '/search',
      queryParameters: {'title': keyword, 'language': 1, 'page': page},
    );
    return _parseComicList(res.data.toString());
  }

  List<ComicItem> _parseComicList(String htmlStr) {
    final doc = html_parser.parse(htmlStr);
    final items = doc.querySelectorAll('.mh-list .mh-item');
    final results = <ComicItem>[];

    for (final el in items) {
      final link = el.querySelector('.title a');
      final href = link?.attributes['href'] ?? '';
      if (href.isEmpty) continue;

      final coverStyle = el.querySelector('.mh-cover')?.attributes['style'] ?? '';
      final coverMatch = RegExp(r'url\(([^)]+)\)').firstMatch(coverStyle);
      final cover = _normalizeUrl(
        coverMatch?.group(1)?.replaceAll(RegExp(r'["\x27]'), '') ?? '',
      );
      final latest = el.querySelector('.chapter a')?.text.trim() ?? '';

      results.add(
        ComicItem(
          sourceId: id,
          title: link?.text.trim() ?? '未命名',
          url: href.startsWith('http') ? href : '$baseUrl$href',
          cover: cover,
          latestChapter: latest,
        ),
      );
    }
    return results;
  }

  @override
  Future<ComicDetail> getDetail(ComicItem item) async {
    final res = await _dio.get(item.url);
    final doc = html_parser.parse(res.data.toString());

    final title = doc.querySelector('.banner_detail_form .info .title')?.text.trim();
    final cover = _normalizeUrl(
      doc.querySelector('.banner_detail_form .cover img')?.attributes['src'] ?? '',
    );
    final author = doc.querySelector('.banner_detail_form .info .subtitle')?.text.trim() ?? '';
    final desc = doc.querySelector('.banner_detail_form .content')?.text.trim() ?? '暫無簡介';

    final chapters = doc.querySelectorAll('#chapterlistload ul li a').map((a) {
      final href = a.attributes['href'] ?? '';
      return ComicChapter(
        title: a.text.trim(),
        url: href.startsWith('http') ? href : '$baseUrl$href',
      );
    }).where((c) => c.url.isNotEmpty).toList();

    return ComicDetail(
      item: ComicItem(
        sourceId: id,
        title: (title != null && title.isNotEmpty) ? title : item.title,
        url: item.url,
        cover: cover.isNotEmpty ? cover : item.cover,
        latestChapter: item.latestChapter,
      ),
      author: author,
      description: desc,
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> getChapterImages(String chapterUrl) async {
    final res = await _dio.get(chapterUrl);
    final htmlStr = res.data.toString();

    final doc = html_parser.parse(htmlStr);
    final directImgs = doc
        .querySelectorAll('#barChapter img')
        .map((e) => _normalizeUrl(e.attributes['data-src'] ?? e.attributes['src'] ?? ''))
        .where((src) => src.isNotEmpty)
        .toList();
    if (directImgs.isNotEmpty) return directImgs;

    String extractVar(String name) {
      final m = RegExp('var\\s+$name\\s*=\\s*["\']?([^;"\']+)["\']?;')
          .firstMatch(htmlStr);
      return m?.group(1)?.trim() ?? '';
    }

    final cid = extractVar('DM5_CID');
    final mid = extractVar('DM5_MID');
    final dt = extractVar('DM5_VIEWSIGN_DT');
    final sign = extractVar('DM5_VIEWSIGN');
    final totalPages = int.tryParse(extractVar('DM5_IMAGE_COUNT')) ?? 0;

    final imageUrls = <String>[];
    int page = 1;

    while (page <= totalPages) {
      final funRes = await _dio.get(
        '/m$cid/chapterfun.ashx',
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
        options: Options(headers: {'Referer': chapterUrl}),
      );

      final unpacked = _unpackJs(funRes.data.toString());
      final urls = _extractImageUrlsFromUnpackedJs(unpacked);

      if (urls.isEmpty) break;
      for (final u in urls) {
        if (!imageUrls.contains(u)) imageUrls.add(u);
      }
      page += urls.length;
    }

    return imageUrls;
  }

  String _normalizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }
    if (trimmed.startsWith('http://')) {
      return trimmed.replaceFirst('http://', 'https://');
    }
    return trimmed;
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

  List<String> _extractImageUrlsFromUnpackedJs(String js) {
    final pix = RegExp(r'''var\s+pix\s*=\s*["']([^"']+)["']''').firstMatch(js)?.group(1) ?? '';
    final pvalueRaw = RegExp(r'var\s+pvalue\s*=\s*\[([^\]]+)\]').firstMatch(js)?.group(1) ?? '';
    final query = RegExp(r'''\+["'](\?cid=[^"']+)["']''').firstMatch(js)?.group(1) ?? '';

    if (pix.isEmpty || pvalueRaw.isEmpty) return [];

    return RegExp(r'''["']([^"']+)["']''')
        .allMatches(pvalueRaw)
        .map((m) => _normalizeUrl('$pix${m.group(1)}$query'))
        .where((u) => u.isNotEmpty)
        .toList();
  }
}
