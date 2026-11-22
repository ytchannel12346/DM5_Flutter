import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ReadHistoryItem {
  final String sourceId;
  final String comicTitle;
  final String comicUrl;
  final String cover;
  final String chapterTitle;
  final String chapterUrl;
  final int pageIndex;
  final int updatedAt;

  ReadHistoryItem({
    required this.sourceId,
    required this.comicTitle,
    required this.comicUrl,
    required this.cover,
    required this.chapterTitle,
    required this.chapterUrl,
    required this.pageIndex,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'sourceId': sourceId,
        'comicTitle': comicTitle,
        'comicUrl': comicUrl,
        'cover': cover,
        'chapterTitle': chapterTitle,
        'chapterUrl': chapterUrl,
        'pageIndex': pageIndex,
        'updatedAt': updatedAt,
      };

  factory ReadHistoryItem.fromJson(Map<String, dynamic> json) =>
      ReadHistoryItem(
        sourceId: json['sourceId'] as String? ?? 'dm5',
        comicTitle: json['comicTitle'] as String? ?? '未命名',
        comicUrl: json['comicUrl'] as String? ?? '',
        cover: json['cover'] as String? ?? '',
        chapterTitle: json['chapterTitle'] as String? ?? '',
        chapterUrl: json['chapterUrl'] as String? ?? '',
        pageIndex: json['pageIndex'] as int? ?? 0,
        updatedAt: json['updatedAt'] as int? ?? 0,
      );
}

class HistoryService {
  static const _storageKey = 'read_history_v1';
  static const _maxItems = 100;

  static Future<List<ReadHistoryItem>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ReadHistoryItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> saveHistory(ReadHistoryItem item) async {
    final list = await loadHistory();
    list.removeWhere(
      (e) => e.sourceId == item.sourceId && e.comicUrl == item.comicUrl,
    );
    list.insert(0, item);
    if (list.length > _maxItems) {
      list.removeRange(_maxItems, list.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> removeItem(ReadHistoryItem item) async {
    final list = await loadHistory();
    list.removeWhere(
      (e) => e.sourceId == item.sourceId && e.comicUrl == item.comicUrl,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
