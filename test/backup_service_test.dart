import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omni_reader/src/data/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exports and restores supported local preferences', () async {
    SharedPreferences.setMockInitialValues({
      'weekly_reading_goal': 7,
      'comic_chapter_history': '[{"comicId":"c"}]',
      'unrelated': 'leave-me-out',
    });
    final directory = await Directory.systemTemp.createTemp('comic-backup-test');
    addTearDown(() => directory.delete(recursive: true));
    final backup = BackupService(fileProvider: () async => File('${directory.path}/backup.json'));

    await backup.exportBackup();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('weekly_reading_goal', 2);
    await preferences.setString('comic_chapter_history', '[]');
    await backup.restoreBackup();

    expect(preferences.getInt('weekly_reading_goal'), 7);
    expect(preferences.getString('comic_chapter_history'), '[{"comicId":"c"}]');
    expect(preferences.getString('unrelated'), 'leave-me-out');
  });
}
