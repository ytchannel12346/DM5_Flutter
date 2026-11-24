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
