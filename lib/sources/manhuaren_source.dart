@override
  Future<List<String>> getChapterImages(String chapterUrl) async {
    final fullUrl = _toFullUrl(chapterUrl);
    final res = await _dio.get(
      fullUrl,
      options: Options(headers: {'Referer': '$baseUrl/'}),
    );
    final htmlStr = res.data.toString();

    // 1. 優先嘗試解包網頁內嵌的 eval(function(p,a,c,k,e,d)...)（常見於 newImgs）
    final packedMatches = RegExp(
      r"eval\(function\(p,a,c,k,e,[dr]\).*?\)\)",
      dotAll: true,
    ).allMatches(htmlStr);

    for (final m in packedMatches) {
      final unpacked = _unpackJs(m.group(0)!);
      final urls = _extractImageUrls(unpacked);
      if (urls.isNotEmpty) return urls;
    }

    // 2. 嘗試 DM5 系列的 chapterfun.ashx 動態介面
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

    // 3. 最後退回直接抓頁面中的圖片陣列或 img 標籤
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
