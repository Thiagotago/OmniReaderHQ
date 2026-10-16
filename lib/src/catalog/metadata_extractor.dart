import 'catalog_entry.dart';

/// Extracts catalog metadata from HTML that the caller already has.
///
/// This class deliberately does not perform HTTP requests and does not
/// resolve or download comic files. It is safe to exercise with fixtures.
class MetadataExtractor {
  const MetadataExtractor();

  CatalogEntry extract({required Uri sourceUrl, required String html}) {
    final title = _metaContent(html, 'og:title') ??
        _titleElement(html) ??
        'Sem título';
    final cover = _metaContent(html, 'og:image');
    final chapters = _chapterLinks(html, sourceUrl);

    return CatalogEntry(
      title: _decode(title.trim()),
      sourceUrl: sourceUrl,
      coverUrl: cover == null ? null : _resolve(sourceUrl, cover),
      chapters: chapters,
    );
  }

  String? _metaContent(String html, String property) {
    final pattern = RegExp(
      r'''<meta\s+[^>]*property=["']''' +
          RegExp.escape(property) +
          r'''["'][^>]*content=["']([^"']+)["'][^>]*>''',
      caseSensitive: false,
    );
    return pattern.firstMatch(html)?.group(1);
  }

  String? _titleElement(String html) {
    final match = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    return match?.group(1);
  }

  List<CatalogChapter> _chapterLinks(String html, Uri sourceUrl) {
    final linkPattern = RegExp(
      r'''<a\s+[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>''',
      caseSensitive: false,
      dotAll: true,
    );
    final chapters = <CatalogChapter>[];

    for (final match in linkPattern.allMatches(html)) {
      final label = _stripTags(match.group(2) ?? '').trim();
      final href = match.group(1);
      if (href == null || label.isEmpty || !_looksLikeChapter(label)) {
        continue;
      }
      chapters.add(
        CatalogChapter(
          title: _decode(label),
          url: _resolve(sourceUrl, href),
        ),
      );
    }
    return List.unmodifiable(chapters);
  }

  bool _looksLikeChapter(String label) {
    return RegExp(r'\b(cap(?:ítulo)?|chapter|vol(?:ume)?|#)\s*[-\w.]*',
            caseSensitive: false)
        .hasMatch(label);
  }

  Uri _resolve(Uri base, String value) {
    return base.resolve(value.trim());
  }

  String _stripTags(String value) {
    return value.replaceAll(RegExp(r'<[^>]+>'), ' ');
  }

  String _decode(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}
