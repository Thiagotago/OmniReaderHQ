import 'reading_progress.dart';

abstract interface class ReadingProgressStore {
  Future<ReadingProgress?> load();

  Future<void> save(ReadingProgress progress);
}
