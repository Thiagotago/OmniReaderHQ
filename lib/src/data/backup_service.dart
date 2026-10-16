import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupService {
  static const fileName = 'omni_reader_backup.json';
  static const _keys = <String>[
    'comic_chapter_history',
    'comic_history_list',
    'comic_favorites',
    'comic_collections',
    'comic_storage_index',
    'catalog_sources_v1',
    'weekly_reading_goal',
    'reader_vertical_mode',
    'reader_brightness',
    'reader_page_spacing',
  ];

  BackupService({Future<File> Function()? fileProvider})
      : _fileProvider = fileProvider;
  final Future<File> Function()? _fileProvider;

  Future<File> get backupFile async {
    if (_fileProvider != null) return _fileProvider!();
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  Future<File> exportBackup() async {
    final preferences = await SharedPreferences.getInstance();
    final data = <String, Object?>{};
    for (final key in _keys) {
      if (preferences.containsKey(key)) data[key] = preferences.get(key);
    }
    final file = await backupFile;
    await file.writeAsString(jsonEncode({
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'data': data
    }));
    return file;
  }

  Future<void> restoreBackup() async {
    final file = await backupFile;
    if (!await file.exists())
      throw const FileSystemException('Backup local não encontrado.');
    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (decoded['version'] != 1 || decoded['data'] is! Map) {
      throw const FormatException(
          'Formato de backup inválido ou não compatível.');
    }
    final preferences = await SharedPreferences.getInstance();
    final data = (decoded['data'] as Map).cast<String, dynamic>();
    for (final key in _keys) {
      if (!data.containsKey(key)) continue;
      final value = data[key];
      if (value is String) await preferences.setString(key, value);
      if (value is int) await preferences.setInt(key, value);
      if (value is double) await preferences.setDouble(key, value);
      if (value is bool) await preferences.setBool(key, value);
      if (value is List<String>) await preferences.setStringList(key, value);
    }
  }
}
