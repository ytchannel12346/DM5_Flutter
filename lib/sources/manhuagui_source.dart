String _unpackJs(String packed) {
    final match = RegExp(
      r"\}\('((?:\\.|[^'\\])*)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'([^']+)'",
      dotAll: true,
    ).firstMatch(packed);
    if (match == null) return '';

    final payload = match
        .group(1)!
        .replaceAll(r"\'", "'")
        .replaceAll(r'\"', '"')
        .replaceAll(r'\\', r'\');
    final radix = int.parse(match.group(2)!);
    final count = int.parse(match.group(3)!);
    final rawDict = match.group(4)!;

    final symtab = rawDict.contains('|')
        ? rawDict.split('|')
        : _decompressFromBase64(rawDict).split('|');

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

  static const String _keyStrBase64 =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';

  String _decompressFromBase64(String input) {
    if (input.isEmpty) return '';
    return _decompress(input.length, 32, (index) {
      if (index >= input.length) return 0;
      return _keyStrBase64.indexOf(input[index]);
    });
  }

  String _decompress(
    int length,
    int resetValue,
    int Function(int) getNextValue,
  ) {
    final dictionary = <int, String>{};
    var enlargeIn = 4;
    var dictSize = 4;
    var numBits = 3;
    var entry = '';
    final result = StringBuffer();
    var w = '';
    var c = 0;

    var currentVal = getNextValue(0);
    var currentPos = resetValue;
    var index = 1;

    int readBits(int bits) {
      var res = 0;
      var power = 1;
      for (var i = 0; i < bits; i++) {
        final val = currentVal & currentPos;
        currentPos >>= 1;
        if (currentPos == 0) {
          currentPos = resetValue;
          currentVal = getNextValue(index++);
        }
        res |= (val > 0 ? 1 : 0) * power;
        power <<= 1;
      }
      return res;
    }

    for (var i = 0; i < 3; i++) {
      dictionary[i] = i.toString();
    }

    final bits = readBits(2);
    switch (bits) {
      case 0:
        c = readBits(8);
        w = String.fromCharCode(c);
        break;
      case 1:
        c = readBits(16);
        w = String.fromCharCode(c);
        break;
      case 2:
        return '';
    }

    dictionary[3] = w;
    result.write(w);

    while (true) {
      if (index > length) {
        return '';
      }
      var cc = readBits(numBits);
      if (cc == 0) {
        c = readBits(8);
        dictionary[dictSize++] = String.fromCharCode(c);
        cc = dictSize - 1;
        enlargeIn--;
      } else if (cc == 1) {
        c = readBits(16);
        dictionary[dictSize++] = String.fromCharCode(c);
        cc = dictSize - 1;
        enlargeIn--;
      } else if (cc == 2) {
        return result.toString();
      }

      if (enlargeIn == 0) {
        enlargeIn = 1 << numBits;
        numBits++;
      }

      if (dictionary.containsKey(cc)) {
        entry = dictionary[cc]!;
      } else if (cc == dictSize) {
        entry = w + w[0];
      } else {
        return '';
      }

      result.write(entry);
      dictionary[dictSize++] = w + entry[0];
      enlargeIn--;
      w = entry;

      if (enlargeIn == 0) {
        enlargeIn = 1 << numBits;
        numBits++;
      }
    }
  }
