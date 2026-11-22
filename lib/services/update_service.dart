import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UpdateInfo {
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;
  final String releasePageUrl;

  const UpdateInfo({
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.releasePageUrl,
  });
}

class UpdateService {
  /// 請將 YOUR_USERNAME 改為你的 GitHub 帳號名稱
  static const String repo = 'YOUR_USERNAME/DM5_Flutter';

  static const String currentVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'DM5-Flutter-App',
      },
    ),
  );

  /// 比較版本號（支援 1.0.12 與 v1.0.15）
  static bool _isNewer(String latest, String current) {
    List<int> parse(String v) => v
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('.')
        .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();

    final l = parse(latest);
    final c = parse(current);
    final len = l.length > c.length ? l.length : c.length;
    for (int i = 0; i < len; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  /// 查詢 GitHub 最新 Release
  static Future<UpdateInfo?> fetchLatestRelease() async {
    final res = await _dio.get('https://api.github.com/repos/$repo/releases/latest');
    final data = res.data;
    if (data is! Map) return null;

    final tagName = (data['tag_name'] ?? '').toString().trim();
    if (tagName.isEmpty || !_isNewer(tagName, currentVersion)) {
      return null;
    }

    final body = (data['body'] ?? '修復已知問題並優化體驗').toString().trim();
    final htmlUrl = (data['html_url'] ?? '').toString().trim();
    final assets = (data['assets'] as List?) ?? [];

    final targetExt = Platform.isIOS ? '.ipa' : '.apk';
    String downloadUrl = htmlUrl;
    for (final a in assets) {
      if (a is Map) {
        final name = (a['name'] ?? '').toString().toLowerCase();
        final url = (a['browser_download_url'] ?? '').toString();
        if (name.endsWith(targetExt) && url.isNotEmpty) {
          downloadUrl = url;
          break;
        }
      }
    }

    return UpdateInfo(
      latestVersion: tagName,
      releaseNotes: body.isEmpty ? '修復已知問題並優化體驗' : body,
      downloadUrl: downloadUrl,
      releasePageUrl: htmlUrl,
    );
  }

  /// 檢查更新並顯示提示（silent: true 表示啟動時靜默檢查，無更新不打擾）
  static Future<void> checkUpdate(
    BuildContext context, {
    bool silent = false,
  }) async {
    try {
      final info = await fetchLatestRelease();
      if (!context.mounted) return;

      if (info == null) {
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('目前已是最新版本 ($currentVersion)')),
          );
        }
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFFF7F6F2),
          title: Text(
            '發現新版本 ${info.latestVersion}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '目前版本：v$currentVersion',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                Text(
                  info.releaseNotes,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('稍後', style: TextStyle(color: Colors.black54)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1F1F1F),
              ),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: info.downloadUrl));
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已複製下載連結，請在瀏覽器貼上安裝')),
                  );
                }
              },
              child: const Text('複製下載連結'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('檢查更新失敗：$e')),
        );
      }
    }
  }
}
