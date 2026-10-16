class CatalogEntry {
  const CatalogEntry({
    required this.title,
    required this.sourceUrl,
    required this.coverUrl,
    required this.chapters,
  });

  final String title;
  final Uri sourceUrl;
  final Uri? coverUrl;
  final List<CatalogChapter> chapters;
}

class CatalogChapter {
  const CatalogChapter({
    required this.title,
    required this.url,
  });

  final String title;
  final Uri url;
}
