import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/comic.dart';
import 'comic_source.dart';

class ManhuaguiSource extends ComicSource {
  @override
  String get id => 'manhuagui';

  @override
  String get name => '看漫畫 (Manhuagui)';

  @override
  String get baseUrl => 'https://m.manhuagui.com';

  static const String _mobileUa =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 '
      '(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': _mobileUa,
        'Referer': '$baseUrl/',
        'Cookie': 'isAdult=1',
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
        'Referer': _toFullUrl(refererUrl),
        'User-Agent': _mobileUa,
        'Cookie': 'isAdult=1',
        'Accept':
            'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      };

  @override
  Future<List<ComicItem>> getPopular({int page = 1}) async {
    final path =
        page <= 1 ? '/list/lianzai/' : '/list/lianzai/index_p$page.html';
    final res = await _dio.get(path);
    return _parseList(res.data.toString(), sourcePath: path);
  }

  @override
  Future<List<ComicItem>> search(String keyword, {int page = 1}) async {
    final encoded = Uri.encodeComponent(keyword.trim());
    final path = page <= 1 ? '/s/$encoded.html' : '/s/${encoded}_p$page.html';
    final res = await _dio.get(path);
    return _parseList(res.data.toString(), sourcePath: path);
  }

  List<ComicItem> _parseList(String htmlStr, {required String sourcePath}) {
    if (htmlStr.trim().isEmpty) {
      throw Exception('Manhuagui ($sourcePath) 回傳空白內容');
    }

    final doc = html_parser.parse(htmlStr);
    final results = <ComicItem>[];
    final seenUrls = <String>{};

    final candidates = doc.querySelectorAll(
      '#bookList li, .book-list li, .list-comic li, .cont-list li, li, a[href]',
    );

    for (final el in candidates) {
      final anchor = el.localName == 'a' ? el : el.querySelector('a[href]');
      final href = anchor?.attributes['href']?.trim() ?? '';
      if (href.isEmpty) continue;
      if (href.contains('/list/') ||
          href.contains('/s/') ||
          href.contains('javascript:')) {
        continue;
      }
      if (!RegExp(r'/\d+/?(?:\.html)?$').hasMatch(href)) continue;

      final fullUrl = _toFullUrl(href);
      if (!seenUrls.add(fullUrl)) continue;

      final img = el.querySelector('img');
      final rawCover = img?.attributes['data-src'] ??
          img?.attributes['lz_src'] ??
          img?.attributes['src'] ??
          _extractCssUrl(
            el.querySelector('[style*="background"]')?.attributes['style'] ??
                el.attributes['style'] ??
                '',
          );

      final title = (img?.attributes['alt'] ??
              anchor?.attributes['title'] ??
              el.querySelector('.title, .book-title, h3, h4, .txt a, p')?.text ??
              anchor?.text ??
              '')
          .trim();

      if (title.isEmpty || title.length > 80) continue;

      final latest = (el
                  .querySelector('.status, .update, .chapter, .tt, span')
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
      final snippet = htmlStr
          .replaceAll(RegExp(r'\s+'), ' ')
          .substring(0, htmlStr.length > 140 ? 140 : htmlStr.length);
      throw Exception(
        'Manhuagui ($sourcePath) 未解析出漫畫項目，頁面片段：$snippet',
      );
    }

    return results;
  }

  @override
  Future<ComicDetail> getDetail(ComicItem item) async {
    final res = await _dio.get(_toFullUrl(item.url));
    final htmlStr = res.data.toString();
    final doc = html_parser.parse(htmlStr);

    final title =
        (doc.querySelector('.book-title h1, .detail-title, h1, h2')?.text ?? '')
            .trim();
    final img = doc.querySelector('.book-cover img, .detail-cover img, img');
    final rawCover =
        img?.attributes['data-src'] ?? img?.attributes['src'] ?? '';
    final author = (doc
                .querySelector('.author, .detail-author, [class*="author"]')
                ?.text ??
            '')
        .trim();
    final desc = (doc
                .querySelector(
                  '.book-intro, .detail-desc, .intro, #intro-all',
                )
                ?.text ??
            '暫無簡介')
        .trim();

    final chapters = <ComicChapter>[];
    final hiddenData =
        doc.querySelector('#VIEWDATA, textarea[id*="chapter"]')?.text.trim() ??
            '';
    if (hiddenData.isNotEmpty) {
      try {
        final decoded = utf8.decode(base64.decode(hiddenData));
        final parsedJson = jsonDecode(decoded);
        if (parsedJson is List) {
          for (final entry in parsedJson) {
            if (entry is Map && entry['url'] != null) {
              chapters.add(
                ComicChapter(
                  title: (entry['name'] ?? entry['title'] ?? '章節')
                      .toString()
                      .trim(),
                  url: _toFullUrl(entry['url'].toString()),
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    if (chapters.isEmpty) {
      for (final a in doc.querySelectorAll(
        '#chapter-list-1 a, #chapterList a, .chapter-list a, ul.chapter a, a[href*=".html"]',
      )) {
        final href = a.attributes['href']?.trim() ?? '';
        final text = a.text.trim();
        if (href.isEmpty || text.isEmpty) continue;
        if (!RegExp(r'/\d+/\d+\.html').hasMatch(href)) continue;

        chapters.add(
          ComicChapter(
            title: text,
            url: _toFullUrl(href),
          ),
        );
      }
    }

    return ComicDetail(
      item: ComicItem(
        sourceId: id,
        title: title.isNotEmpty ? title : item.title,
        url: _toFullUrl(item.url),
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
