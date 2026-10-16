import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'reading_progress.dart';
import 'reading_progress_store.dart';

/// Local, per-chapter reading history with one-time compatibility for the old key.
class ReadingHistoryStore {
  static const key = 'comic_chapter_history';
  static const legacyKey = 'comic_history_list';

  Future<void> save(Map<String, dynamic> data) async {
    final preferences = await SharedPreferences.getInstance();
    final history = await load();
    history.removeWhere((item) =>
        item['comicId'] == data['comicId'] && item['chapterId'] == data['chapterId']);
    history.insert(0, data);
    await preferences.setString(key, jsonEncode(history));
    await preferences.remove(legacyKey);
  }

  Future<List<Map<String, dynamic>>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final decoded = <Map<String, dynamic>>[];
    for (final source in [preferences.getString(key), preferences.getString(legacyKey)]) {
      if (source == null) continue;
      try {
        decoded.addAll((jsonDecode(source) as List).cast<Map<String, dynamic>>());
      } on Object {
        // Preserve valid records when one stored value is malformed.
      }
    }
    final unique = <String, Map<String, dynamic>>{};
    for (final item in decoded) {
      unique['${item['comicId']}|${item['chapterId']}'] ??= item;
    }
    return unique.values.toList();
  }
}

class ReadingHistoryProgressAdapter implements ReadingProgressStore {
  const ReadingHistoryProgressAdapter(this.history, {this.onSave, this.extraData = const {}});
  final ReadingHistoryStore history;
  final Future<void> Function(ReadingProgress progress)? onSave;
  final Map<String, Object?> extraData;

  @override
  Future<void> save(ReadingProgress progress) async {
    await history.save({
      'comicId': progress.comicId,
      'comicTitle': progress.comicTitle,
      'chapterId': progress.chapterId,
      'chapterTitle': progress.chapterTitle,
      'page': progress.page,
      'totalPages': progress.totalPages,
      'updatedAt': progress.updatedAt.toIso8601String(),
      ...extraData,
    });
    await onSave?.call(progress);
  }

  @override
  Future<ReadingProgress?> load() async {
    final items = await history.load();
    if (items.isEmpty) return null;
    final item = items.first;
    return ReadingProgress(
      comicId: item['comicId'] as String,
      comicTitle: item['comicTitle'] as String,
      chapterId: item['chapterId'] as String,
      chapterTitle: item['chapterTitle'] as String,
      page: item['page'] as int,
      totalPages: item['totalPages'] as int,
      updatedAt: DateTime.tryParse(item['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
