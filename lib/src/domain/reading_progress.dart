class ReadingProgress {
  const ReadingProgress({
    required this.comicId,
    required this.comicTitle,
    required this.chapterId,
    required this.chapterTitle,
    required this.page,
    required this.totalPages,
    required this.updatedAt,
  });

  final String comicId;
  final String comicTitle;
  final String chapterId;
  final String chapterTitle;
  final int page;
  final int totalPages;
  final DateTime updatedAt;
}
