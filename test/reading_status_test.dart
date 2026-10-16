import 'package:flutter_test/flutter_test.dart';
import 'package:omni_reader/src/domain/reading_status.dart';

void main() {
  const status = ReadingStatus();

  test('marks a chapter complete only at its final page', () {
    expect(status.isChapterComplete(page: 8, totalPages: 10), isFalse);
    expect(status.isChapterComplete(page: 9, totalPages: 10), isTrue);
    expect(status.isChapterComplete(page: 0, totalPages: 0), isFalse);
  });

  test('marks a downloaded series complete only when all downloaded chapters are done', () {
    expect(status.areDownloadedChaptersComplete(
      downloadedChapterIds: {'one', 'two'},
      completedChapterIds: {'one'},
    ), isFalse);
    expect(status.areDownloadedChaptersComplete(
      downloadedChapterIds: {'one', 'two'},
      completedChapterIds: {'one', 'two'},
    ), isTrue);
  });
}
