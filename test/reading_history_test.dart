import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omni_reader/src/domain/reading_history_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates legacy single chapter and retains progress per chapter', () async {
    SharedPreferences.setMockInitialValues({
      'comic_history_list': jsonEncode([
        {'comicId': 'series', 'comicTitle': 'Série', 'chapterId': 'one', 'chapterTitle': 'Um', 'page': 2, 'totalPages': 3},
      ]),
    });

    final store = ReadingHistoryStore();
    final migrated = await store.load();
    expect(migrated.single['chapterId'], 'one');

    await store.save({
      'comicId': 'series',
      'comicTitle': 'Série',
      'chapterId': 'two',
      'chapterTitle': 'Dois',
      'page': 0,
      'totalPages': 4,
    });
    final history = await store.load();
    expect(history.map((item) => item['chapterId']).toSet(), {'one', 'two'});
  });
}
