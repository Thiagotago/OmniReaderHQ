class ReadingStatus {
  const ReadingStatus();

  bool isChapterComplete({required int page, required int totalPages}) =>
      totalPages > 0 && page >= totalPages - 1;

  bool areDownloadedChaptersComplete({
    required Set<String> downloadedChapterIds,
    required Set<String> completedChapterIds,
  }) => downloadedChapterIds.isNotEmpty && completedChapterIds.containsAll(downloadedChapterIds);
}
