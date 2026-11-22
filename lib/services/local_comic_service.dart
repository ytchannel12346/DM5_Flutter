import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalBook {
  final String id;
  final String title;
  final String dirPath;
  final String coverPath;
  final int pageCount;

  LocalBook({
    required this.id,
    required this.title,
    required this.dirPath,
    required this.coverPath,
    required this.pageCount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dirPath': dirPath,
        'coverPath': coverPath,
        'pageCount': pageCount,
      };

  factory LocalBook.fromJson(Map<String, dynamic> json) => LocalBook(
        id: json['id'] as String,
        title: json['title'] as String,
        dirPath: json['dirPath'] as String,
        coverPath: json['coverPath'] as String,
        pageCount: json['pageCount'] as int? ?? 0,
      );
}

class LocalComicService {
  static const _storageKey = 'local_books_v1';

  static Future<List<LocalBook>> loadBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => LocalBook.fromJson(Map<String, dynamic>.from(e)))
        .where((b) => Directory(b.dirPath).existsSync())
        .toList();
  }

  static Future<void> _saveBooks(List<LocalBook> books) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(books.map((b) => b.toJson()).toList()),
    );
  }

  /// Import a .cbz or .zip comic archive
  static Future<LocalBook?> importArchive() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['cbz', 'zip'],
    );
    if (picked == null || picked.files.single.path == null) return null;

    final file = File(picked.files.single.path!);
    final fileName = picked.files.single.name;
    final title = fileName.replaceAll(RegExp(r'\.(cbz|zip)$', caseSensitive: false), '');

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final docsDir = await getApplicationDocumentsDirectory();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final bookDir = Directory('${docsDir.path}/local_comics/$id');
    await bookDir.create(recursive: true);

    final savedPaths = <String>[];
    for (final entry in archive) {
      if (!entry.isFile) continue;
      if (!RegExp(r'\.(jpg|jpeg|png|webp)$', caseSensitive: false)
          .hasMatch(entry.name)) {
        continue;
      }
      final safeName = entry.name.split('/').last;
      if (safeName.startsWith('.')) continue;

      final outFile = File('${bookDir.path}/$safeName');
      await outFile.writeAsBytes(entry.content as List<int>);
      savedPaths.add(outFile.path);
    }

    if (savedPaths.isEmpty) {
      await bookDir.delete(recursive: true);
      throw Exception('壓縮檔內沒有找到圖片');
    }

    savedPaths.sort();
    final book = LocalBook(
      id: id,
      title: title,
      dirPath: bookDir.path,
      coverPath: savedPaths.first,
      pageCount: savedPaths.length,
    );

    final books = await loadBooks();
    books.insert(0, book);
    await _saveBooks(books);
    return book;
  }

  /// Import multiple image files as a single local book
  static Future<LocalBook?> importImages({String? customTitle}) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (picked == null || picked.files.isEmpty) return null;

    final docsDir = await getApplicationDocumentsDirectory();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final bookDir = Directory('${docsDir.path}/local_comics/$id');
    await bookDir.create(recursive: true);

    final savedPaths = <String>[];
    for (var i = 0; i < picked.files.length; i++) {
      final path = picked.files[i].path;
      if (path == null) continue;
      final ext = path.split('.').last;
      final outPath = '${bookDir.path}/${(i + 1).toString().padLeft(4, '0')}.$ext';
      await File(path).copy(outPath);
      savedPaths.add(outPath);
    }

    if (savedPaths.isEmpty) return null;

    final book = LocalBook(
      id: id,
      title: (customTitle != null && customTitle.trim().isNotEmpty)
          ? customTitle.trim()
          : '本地漫畫 ${DateTime.now().month}/${DateTime.now().day}',
      dirPath: bookDir.path,
      coverPath: savedPaths.first,
      pageCount: savedPaths.length,
    );

    final books = await loadBooks();
    books.insert(0, book);
    await _saveBooks(books);
    return book;
  }

  static Future<void> deleteBook(LocalBook book) async {
    final dir = Directory(book.dirPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    final books = await loadBooks();
    books.removeWhere((b) => b.id == book.id);
    await _saveBooks(books);
  }
}
