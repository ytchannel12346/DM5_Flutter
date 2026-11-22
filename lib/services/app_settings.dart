import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _settingsKey = 'app_settings_v1';
  static const _historyKey = 'read_history_v1';

  // 使用方式
  bool forcePortrait = false;
  bool tapToReadDirectly = false;
  int startupTab = 0;
  bool continueOnLaunch = false;
  bool mergeBookshelf = false;
  bool offlineMode = false;
  bool readerOnlyMode = false;
  bool volumeKeyPaging = true; // 音量鍵翻頁

  // 閱讀與外觀
  ThemeMode themeMode = ThemeMode.system;
  String languageLabel = '繁體中文 · 香港';

  // 性能與動效
  String refreshRatePref = '自動高刷';
  bool lowPerfMode = false;
  double glassBlur = 8.0;
  double glassOpacity = 0.87;
  bool reduceMotion = false;
  bool hapticFeedback = true;

  // 統計與書籤（保留與現有 settings_pages.dart 相容）
  bool recordTouches = true;
  int totalTouches = 0;
  List<int> touchHeatmap = List<int>.filled(100, 0);
  Map<String, int> bookmarksByBook = {};

  /// 在 main() 啟動時呼叫
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _applyMap(Map<String, dynamic>.from(jsonDecode(raw)));
      } catch (_) {}
    }
    _applyOrientation();
    notifyListeners();
  }

  void update(VoidCallback fn) {
    fn();
    _applyOrientation();
    notifyListeners();
    _save();
  }

  void _applyOrientation() {
    if (forcePortrait) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } else {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(_toMap()));
  }

  Map<String, dynamic> _toMap() => {
        'forcePortrait': forcePortrait,
        'tapToReadDirectly': tapToReadDirectly,
        'startupTab': startupTab,
        'continueOnLaunch': continueOnLaunch,
        'mergeBookshelf': mergeBookshelf,
        'offlineMode': offlineMode,
        'readerOnlyMode': readerOnlyMode,
        'volumeKeyPaging': volumeKeyPaging,
        'themeMode': themeMode.index,
        'languageLabel': languageLabel,
        'refreshRatePref': refreshRatePref,
        'lowPerfMode': lowPerfMode,
        'glassBlur': glassBlur,
        'glassOpacity': glassOpacity,
        'reduceMotion': reduceMotion,
        'hapticFeedback': hapticFeedback,
        'recordTouches': recordTouches,
        'totalTouches': totalTouches,
      };

  void _applyMap(Map<String, dynamic> m) {
    forcePortrait = m['forcePortrait'] as bool? ?? forcePortrait;
    tapToReadDirectly = m['tapToReadDirectly'] as bool? ?? tapToReadDirectly;
    startupTab = m['startupTab'] as int? ?? startupTab;
    continueOnLaunch = m['continueOnLaunch'] as bool? ?? continueOnLaunch;
    mergeBookshelf = m['mergeBookshelf'] as bool? ?? mergeBookshelf;
    offlineMode = m['offlineMode'] as bool? ?? offlineMode;
    readerOnlyMode = m['readerOnlyMode'] as bool? ?? readerOnlyMode;
    volumeKeyPaging = m['volumeKeyPaging'] as bool? ?? volumeKeyPaging;
    final tmIdx = m['themeMode'] as int?;
    if (tmIdx != null && tmIdx >= 0 && tmIdx < ThemeMode.values.length) {
      themeMode = ThemeMode.values[tmIdx];
    }
    languageLabel = m['languageLabel'] as String? ?? languageLabel;
    refreshRatePref = m['refreshRatePref'] as String? ?? refreshRatePref;
    lowPerfMode = m['lowPerfMode'] as bool? ?? lowPerfMode;
    glassBlur = (m['glassBlur'] as num?)?.toDouble() ?? glassBlur;
    glassOpacity = (m['glassOpacity'] as num?)?.toDouble() ?? glassOpacity;
    reduceMotion = m['reduceMotion'] as bool? ?? reduceMotion;
    hapticFeedback = m['hapticFeedback'] as bool? ?? hapticFeedback;
    recordTouches = m['recordTouches'] as bool? ?? recordTouches;
    totalTouches = m['totalTouches'] as int? ?? totalTouches;
  }

  /// 匯出設定與閱讀歷史為 JSON
  Future<String> exportBackupJson() async {
    final prefs = await SharedPreferences.getInstance();
    final historyRaw = prefs.getString(_historyKey);
    final payload = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': _toMap(),
      'history': historyRaw != null ? jsonDecode(historyRaw) : [],
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// 從 JSON 還原設定與閱讀歷史
  Future<void> importBackupJson(String jsonStr) async {
    final data = jsonDecode(jsonStr);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('備份格式不正確');
    }
    final prefs = await SharedPreferences.getInstance();
    if (data['settings'] is Map) {
      _applyMap(Map<String, dynamic>.from(data['settings']));
      await prefs.setString(_settingsKey, jsonEncode(_toMap()));
    }
    if (data['history'] is List) {
      await prefs.setString(_historyKey, jsonEncode(data['history']));
    }
    _applyOrientation();
    notifyListeners();
  }

  void clearHistory() {
    notifyListeners();
  }
}
