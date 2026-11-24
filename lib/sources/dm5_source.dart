List<String> _extractDm5Urls(String unpacked) {
    final pixMatch =
        RegExp(r'''pix\s*=\s*["']([^"']+)["']''').firstMatch(unpacked);
    final pvalueMatch =
        RegExp(r'''pvalue\s*=\s*\[([^\]]+)\]''').firstMatch(unpacked);
    if (pixMatch == null || pvalueMatch == null) return [];

    final pix = pixMatch.group(1)!;
    final cidMatch = RegExp(r'\bcid\s*=\s*(\d+)').firstMatch(unpacked);
    final keyMatch =
        RegExp(r'''\bkey\s*=\s*["']([^"']+)["']''').firstMatch(unpacked);
    final ukMatch =
        RegExp(r'''\buk\s*=\s*["']([^"']+)["']''').firstMatch(unpacked);

    // 直接抓取 JS 裡拼接的 ?cid=...&key=... 參數
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

    // 還原 JS 字串中的跳脫引號 \' -> '
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
