import 'app_settings.dart';

class AppL10n {
  static String get _lang => AppSettings.instance.languageLabel;

  static String t(String key) {
    final map = _table[_lang] ?? _table['繁體中文 · 香港']!;
    return map[key] ?? _table['繁體中文 · 香港']![key] ?? key;
  }

  static const Map<String, Map<String, String>> _table = {
    '繁體中文 · 香港': {
      'discover': '發現',
      'bookshelf': '書架',
      'local': '本地',
      'mine': '我的',
      'settings': '設置',
      'usage': '使用方式',
      'appearance': '閱讀與外觀',
      'performance': '性能與動效',
      'storage': '數據與存儲',
      'history': '閱讀歷史',
      'backup_restore': '備份與恢復',
      'volume_paging': '音量鍵翻頁',
      'volume_paging_sub': '閱讀時按音量上下鍵切換上一頁 / 下一頁',
      'prev_chapter': '上一話',
      'next_chapter': '下一話',
      'toc': '目錄',
      'reader_settings': '閱讀設定',
    },
    '簡體中文': {
      'discover': '发现',
      'bookshelf': '书架',
      'local': '本地',
      'mine': '我的',
      'settings': '设置',
      'usage': '使用方式',
      'appearance': '阅读与外观',
      'performance': '性能与动效',
      'storage': '数据与存储',
      'history': '阅读历史',
      'backup_restore': '备份与恢复',
      'volume_paging': '音量键翻页',
      'volume_paging_sub': '阅读时按音量上下键切换上一页 / 下一页',
      'prev_chapter': '上一话',
      'next_chapter': '下一话',
      'toc': '目录',
      'reader_settings': '阅读设置',
    },
    'English': {
      'discover': 'Discover',
      'bookshelf': 'Shelf',
      'local': 'Local',
      'mine': 'Mine',
      'settings': 'Settings',
      'usage': 'Usage',
      'appearance': 'Appearance',
      'performance': 'Performance',
      'storage': 'Data & Storage',
      'history': 'Reading History',
      'backup_restore': 'Backup & Restore',
      'volume_paging': 'Volume Key Paging',
      'volume_paging_sub': 'Use volume up/down keys to turn pages while reading',
      'prev_chapter': 'Prev',
      'next_chapter': 'Next',
      'toc': 'Chapters',
      'reader_settings': 'Reader Settings',
    },
  };
}
