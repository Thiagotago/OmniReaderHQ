import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reading_progress.dart';
import '../domain/reading_progress_store.dart';

class SharedPreferencesProgressStore implements ReadingProgressStore {
  static const _progressKey = 'reading.progress.v1';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<ReadingProgress?> load() async {
    final stored = (await _preferences).getString(_progressKey);
    if (stored == null) return null;

    try {
      final json = jsonDecode(stored) as Map<String, dynamic>;
      return ReadingProgress(
        comicId: json['comicId'] as String,
        comicTitle: json['comicTitle'] as String,
        chapterId: json['chapterId'] as String,
        chapterTitle: json['chapterTitle'] as String,
        page: json['page'] as int,
        totalPages: json['totalPages'] as int,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> save(ReadingProgress progress) async {
    final json = <String, Object>{
      'comicId': progress.comicId,
      'comicTitle': progress.comicTitle,
      'chapterId': progress.chapterId,
      'chapterTitle': progress.chapterTitle,
      'page': progress.page,
      'totalPages': progress.totalPages,
      'updatedAt': progress.updatedAt.toIso8601String(),
    };
    await (await _preferences).setString(_progressKey, jsonEncode(json));
  }
}
