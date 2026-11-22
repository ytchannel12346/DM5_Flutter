import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryRecord {
  final String title;
  final String url;
  final String sourceId;
  final String chapterTitle;
  final int progressPercent;
  final String timestamp;

  const HistoryRecord({
    required this.title,
    required this.url,
    required this.sourceId,
    required this.chapterTitle,
    required this.progressPercent,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'sourceId': sourceId,
        'chapterTitle': chapterTitle,
        'progressPercent': progressPercent,
        'timestamp': timestamp,
      };

  factory HistoryRecord.fromJson(Map<String, dynamic> j) => HistoryRecord(
        title: j['title'] ?? '',
        url: j['url'] ?? '',
        sourceId: j['sourceId'] ?? 'dm5',
        chapterTitle: j['chapterTitle'] ?? '第 1 話',
        progressPercent: j['progressPercent'] ?? 0,
        timestamp: j['timestamp'] ?? '',
      );
}

class AppSettings extends ChangeNotifier {
  static final AppSettings instance = AppSettings._();
  AppSettings._();

  // 使用方式
  bool forcePortrait = false;
  bool tapToReadDirectly = false;
  int startupTab = 0; // 0:發現, 1:書架, 2:本地, 3:我的
  bool continueOnLaunch = false;
  bool mergeBookshelf = false;
  bool offlineMode = false;
  bool readerOnlyMode = false;

  // 外觀
  ThemeMode themeMode = ThemeMode.system;
  String languageLabel = '繁體中文 · 香港';

  // 性能與動效
  String refreshRatePref = '自動高刷';
  bool lowPerfMode = false;
  double glassBlur = 8.0;
  double glassOpacity = 0.87;
  bool reduceMotion = false;
  bool hapticFeedback = true;

  // 統計與記錄
  bool recordTouches = true;
  int totalTouches = 0;
  List<int> touchHeatmap = List.filled(14 * 10, 0);
  List<HistoryRecord> history = [];
  Map<String, int> bookmarksByBook = {};

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    forcePortrait = p.getBool('set_forcePortrait') ?? false;
    tapToReadDirectly = p.getBool('set_tapToRead') ?? false;
    startupTab = p.getInt('set_startupTab') ?? 0;
    continueOnLaunch = p.getBool('set_continueOnLaunch') ?? false;
    mergeBookshelf = p.getBool('set_mergeBookshelf') ?? false;
    offlineMode = p.getBool('set_offlineMode') ?? false;
    readerOnlyMode = p.getBool('set_readerOnlyMode') ?? false;

    final tm = p.getInt('set_themeMode') ?? 0;
    themeMode = ThemeMode.values[tm.clamp(0, 2)];
    languageLabel = p.getString('set_lang') ?? '繁體中文 · 香港';

    refreshRatePref = p.getString('set_fps') ?? '自動高刷';
    lowPerfMode = p.getBool('set_lowPerf') ?? false;
    glassBlur = p.getDouble('set_glassBlur') ?? 8.0;
    glassOpacity = p.getDouble('set_glassOpacity') ?? 0.87;
    reduceMotion = p.getBool('set_reduceMotion') ?? false;
    hapticFeedback = p.getBool('set_haptic') ?? true;

    recordTouches = p.getBool('stat_recordTouches') ?? true;
    totalTouches = p.getInt('stat_totalTouches') ?? 0;
    final rawMap = p.getStringList('stat_heatmap');
    if (rawMap != null && rawMap.length == 140) {
      touchHeatmap = rawMap.map((e) => int.tryParse(e) ?? 0).toList();
    }

    final rawHist = p.getStringList('reading_history') ?? [];
    history = rawHist
        .map((e) => HistoryRecord.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();

    final rawBm = p.getString('bookmarks_map');
    if (rawBm != null) {
      final decoded = jsonDecode(rawBm) as Map<String, dynamic>;
      bookmarksByBook = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    }

    await _applyOrientation();
    notifyListeners();
  }

  Future<void> _applyOrientation() async {
    if (forcePortrait) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  Future<void> update(VoidCallback fn) async {
    fn();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('set_forcePortrait', forcePortrait);
    await p.setBool('set_tapToRead', tapToReadDirectly);
    await p.setInt('set_startupTab', startupTab);
    await p.setBool('set_continueOnLaunch', continueOnLaunch);
    await p.setBool('set_mergeBookshelf', mergeBookshelf);
    await p.setBool('set_offlineMode', offlineMode);
    await p.setBool('set_readerOnlyMode', readerOnlyMode);
    await p.setInt('set_themeMode', themeMode.index);
    await p.setString('set_lang', languageLabel);
    await p.setString('set_fps', refreshRatePref);
    await p.setBool('set_lowPerf', lowPerfMode);
    await p.setDouble('set_glassBlur', glassBlur);
    await p.setDouble('set_glassOpacity', glassOpacity);
    await p.setBool('set_reduceMotion', reduceMotion);
    await p.setBool('set_haptic', hapticFeedback);
    await p.setBool('stat_recordTouches', recordTouches);
    await _applyOrientation();
  }

  Future<void> addHistory(HistoryRecord rec) async {
    history.removeWhere((h) => h.url == rec.url);
    history.insert(0, rec);
    if (history.length > 100) history = history.sublist(0, 100);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      'reading_history',
      history.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> clearHistory() async {
    history.clear();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.remove('reading_history');
  }

  Future<void> recordTouchAt(int cellIndex) async {
    if (!recordTouches || cellIndex < 0 || cellIndex >= touchHeatmap.length) return;
    totalTouches++;
    touchHeatmap[cellIndex]++;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt('stat_totalTouches', totalTouches);
    await p.setStringList(
      'stat_heatmap',
      touchHeatmap.map((e) => e.toString()).toList(),
    );
  }

  Future<String> exportBackupJson() async {
    final p = await SharedPreferences.getInstance();
    return jsonEncode({
      'bookshelf': p.getStringList('bookshelf') ?? [],
      'history': p.getStringList('reading_history') ?? [],
      'bookmarks': bookmarksByBook,
    });
  }

  Future<bool> importBackupJson(String raw) async {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final p = await SharedPreferences.getInstance();
      if (map['bookshelf'] is List) {
        await p.setStringList(
          'bookshelf',
          (map['bookshelf'] as List).map((e) => e.toString()).toList(),
        );
      }
      if (map['history'] is List) {
        await p.setStringList(
          'reading_history',
          (map['history'] as List).map((e) => e.toString()).toList(),
        );
      }
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }
}
