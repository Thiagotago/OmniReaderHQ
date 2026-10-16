import 'dart:io';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoredChapter {
  const StoredChapter({required this.id, required this.bytes});
  final String id;
  final int bytes;
}

class StoredComic {
  const StoredComic({required this.id, required this.title, required this.bytes, required this.chapterCount, required this.modifiedAt, required this.chapters});
  final String id;
  final String title;
  final int bytes;
  final int chapterCount;
  final DateTime modifiedAt;
  final List<StoredChapter> chapters;
}

class StorageManager {
  static const _indexKey = 'comic_storage_index';
  StorageManager({Future<Directory> Function()? rootProvider})
      : _rootProvider = rootProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _rootProvider;

  Future<Directory> get comicsDirectory async {
    final root = await _rootProvider();
    return Directory('${root.path}${Platform.pathSeparator}comics');
  }

  Future<int> getUsedBytes() async {
    final comics = await listStoredComics();
    return comics.fold<int>(0, (total, comic) => total + comic.bytes);
  }

  Future<List<StoredComic>> listStoredComics() async {
    final root = await comicsDirectory;
    if (!await root.exists()) return const [];
    final result = <StoredComic>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      var bytes = 0;
      final chapterDirectories = <Directory>[];
      final storedChapters = <StoredChapter>[];
      await for (final child in entity.list(followLinks: false)) {
        if (child is Directory) {
          chapterDirectories.add(child);
          var chapterBytes = 0;
          await for (final file in child.list(recursive: true, followLinks: false)) {
            if (file is File) chapterBytes += await file.length();
          }
          bytes += chapterBytes;
          storedChapters.add(StoredChapter(
            id: child.path.split(Platform.pathSeparator).last,
            bytes: chapterBytes,
          ));
        } else if (child is File) {
          bytes += await child.length();
        }
      }
      result.add(StoredComic(
        id: entity.path.split(Platform.pathSeparator).last,
        title: _displayTitle(entity.path.split(Platform.pathSeparator).last),
        bytes: bytes,
        chapterCount: chapterDirectories.length,
        modifiedAt: (await entity.stat()).modified,
        chapters: storedChapters,
      ));
    }
    result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return result;
  }

  Future<void> deleteComic(String comicId) async {
    final root = await comicsDirectory;
    final target = Directory('${root.path}${Platform.pathSeparator}$comicId');
    if (target.parent.absolute.path != root.absolute.path) {
      throw ArgumentError.value(comicId, 'comicId', 'Invalid storage entry');
    }
    if (await target.exists()) await target.delete(recursive: true);
    final preferences = await SharedPreferences.getInstance();
    final index = _readIndex(preferences.getString(_indexKey));
    index.remove(comicId);
    await preferences.setString(_indexKey, jsonEncode(index));
  }

  Future<void> deleteChapter(String comicId, String chapterId) async {
    final root = await comicsDirectory;
    final comicDirectory = Directory('${root.path}${Platform.pathSeparator}$comicId');
    final target = Directory('${comicDirectory.path}${Platform.pathSeparator}$chapterId');
    if (target.parent.absolute.path != comicDirectory.absolute.path ||
        comicDirectory.parent.absolute.path != root.absolute.path) {
      throw ArgumentError('Invalid chapter storage entry');
    }
    if (await target.exists()) await target.delete(recursive: true);
    final preferences = await SharedPreferences.getInstance();
    final index = _readIndex(preferences.getString(_indexKey));
    final entry = index[comicId] as Map<String, dynamic>?;
    if (entry != null) {
      (entry['chapters'] as List<dynamic>? ?? []).remove(chapterId);
      (entry['completedChapters'] as List<dynamic>? ?? []).remove(chapterId);
      await preferences.setString(_indexKey, jsonEncode(index));
    }
  }

  Future<void> recordChapter({required String folderId, required String comicTitle, required String chapterId, bool completed = false}) async {
    final preferences = await SharedPreferences.getInstance();
    final index = _readIndex(preferences.getString(_indexKey));
    final entry = (index[folderId] as Map<String, dynamic>?) ?? <String, dynamic>{};
    entry['title'] = comicTitle;
    final chapters = (entry['chapters'] as List<dynamic>? ?? []).cast<String>().toSet()..add(chapterId);
    entry['chapters'] = chapters.toList();
    final completedChapters = (entry['completedChapters'] as List<dynamic>? ?? []).cast<String>().toSet();
    if (completed) {
      completedChapters.add(chapterId);
    } else {
      completedChapters.remove(chapterId);
    }
    entry['completedChapters'] = completedChapters.toList();
    index[folderId] = entry;
    await preferences.setString(_indexKey, jsonEncode(index));
  }

  Future<Map<String, Set<String>>> loadChapterIndex() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = _readIndex(preferences.getString(_indexKey));
    return raw.map((folderId, value) {
      final entry = value as Map<String, dynamic>;
      return MapEntry(folderId, (entry['chapters'] as List<dynamic>? ?? []).cast<String>().toSet());
    });
  }

  Future<Map<String, String>> loadTitleIndex() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = _readIndex(preferences.getString(_indexKey));
    return raw.map((folderId, value) => MapEntry(folderId, (value as Map<String, dynamic>)['title'] as String? ?? ''));
  }

  Future<Map<String, Set<String>>> loadCompletedChapterIndex() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = _readIndex(preferences.getString(_indexKey));
    return raw.map((folderId, value) {
      final entry = value as Map<String, dynamic>;
      return MapEntry(folderId, (entry['completedChapters'] as List<dynamic>? ?? []).cast<String>().toSet());
    });
  }

  Map<String, dynamic> _readIndex(String? encoded) {
    if (encoded == null) return <String, dynamic>{};
    try {
      return (jsonDecode(encoded) as Map).cast<String, dynamic>();
    } on Object {
      return <String, dynamic>{};
    }
  }

  Future<void> clear() async {
    final directory = await comicsDirectory;
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> clearIndex() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_indexKey);
  }

  String _displayTitle(String folder) => folder.replaceAll('_', ' ').trim();
}
