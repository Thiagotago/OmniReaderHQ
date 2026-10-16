import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;

import '../domain/comic.dart';

/// Shared depth-one DOM + raw-HTML chapter link extractor.
class SmartChapterLinkExtractor {
  const SmartChapterLinkExtractor._();

  static const int maxIntermediatePages = 8;
  static const Duration pageRequestTimeout = Duration(seconds: 7);
  static const Duration crawlBatchTimeout = Duration(seconds: 8);

  static const _navigationTerms = <String>[
    'direto',
    'download',
    'capitulo',
    'capítulo',
    'baixar',
    'volume',
    'leitura',
    'ler',
    'link',
    'arquivo',
    'acessar',
  ];

  static Future<http.Response?> fetchSameHostPage(
    Uri target,
    Uri sourcePage,
  ) async {
    if (!_sameHost(target, sourcePage) ||
        (target.scheme != 'https' && target.scheme != 'http')) {
      return null;
    }
    final client = http.Client();
    try {
      var request = http.Request('GET', target)..followRedirects = false;
      var response = await client.send(request).timeout(pageRequestTimeout);
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers['location'];
        if (location == null) return null;
        final redirected = target.resolve(location);
        if (!_sameHost(redirected, sourcePage)) return null;
        request = http.Request('GET', redirected)..followRedirects = false;
        response = await client.send(request).timeout(pageRequestTimeout);
      }
      final body =
          await response.stream.bytesToString().timeout(pageRequestTimeout);
      return http.Response(body, response.statusCode,
          headers: response.headers, request: response.request);
    } finally {
      client.close();
    }
  }

  static Future<List<ComicChapter>> extract({
    required String html,
    required String comicId,
    required Uri postUri,
    bool bloggerMarkup = false,
  }) async {
    final direct = extractDirectChapters(
      html,
      comicId: comicId,
      postUri: postUri,
      bloggerMarkup: bloggerMarkup,
    );
    if (direct.length >= 2) return direct;

    final candidates =
        _intermediateLinks(html, postUri, bloggerMarkup: bloggerMarkup)
            .take(maxIntermediatePages)
            .toList(growable: false);
    final results = await Future.wait(candidates.map((candidate) async {
      try {
        final response = await fetchSameHostPage(candidate.uri, postUri);
        if (response == null || response.statusCode != 200) {
          return <ComicChapter>[];
        }
        return _extractHostedChapters(
          response.body,
          comicId: comicId,
          pageUri: candidate.uri,
          fallbackTitle: candidate.label,
        );
      } on Object {
        return <ComicChapter>[];
      }
    })).timeout(crawlBatchTimeout, onTimeout: () => <List<ComicChapter>>[]);

    final unique = <String, ComicChapter>{};
    for (final chapter in [...direct, ...results.expand((items) => items)]) {
      unique.putIfAbsent(chapter.id, () => chapter);
    }
    return unique.values.toList(growable: false);
  }

  static List<ComicChapter> extractDirectChapters(
    String html, {
    required String comicId,
    required Uri postUri,
    bool bloggerMarkup = false,
  }) {
    final document = parser.parse(html);
    final seen = <String>{};
    final chapters = <ComicChapter>[];
    final chapterLabel = RegExp(
      r'^(?:\d{1,4}(?:[.,]\d{1,3})?|(?:cap(?:ítulo)?|chapter|vol(?:ume)?|ed(?:ição)?|pack)\s*[-.#:]?\s*[\w.-]+|anual\s*\d{0,4})$',
      caseSensitive: false,
    );

    final linkSelector =
        bloggerMarkup ? '.post-body a[href], .post a[href]' : 'a[href]';
    for (final link in document.querySelectorAll(linkSelector)) {
      final href = link.attributes['href']?.trim();
      if (href == null || href.isEmpty) continue;
      final uri = postUri.resolve(href);
      if (!_isHttp(uri) || uri == postUri || _sameHost(uri, postUri)) continue;
      if (!_isKnownArchiveHost(uri)) continue;

      var title = link.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (title.isEmpty) {
        title = (link.attributes['title'] ??
                link.querySelector('img')?.attributes['alt'] ??
                '')
            .trim();
      }
      if (!chapterLabel.hasMatch(title) || !seen.add(uri.toString())) continue;
      chapters.add(ComicChapter(
        id: uri.toString(),
        comicId: comicId,
        title: title,
      ));
    }

    var rawIndex = 0;
    final rawScope = bloggerMarkup
        ? document.querySelector('.post-body')?.innerHtml ??
            document.querySelector('.post')?.innerHtml ??
            html
        : html;
    for (final uri in extractRawArchiveUrls(rawScope)) {
      if (!seen.add(uri.toString())) continue;
      rawIndex++;
      chapters.add(ComicChapter(
        id: uri.toString(),
        comicId: comicId,
        title: 'Capítulo $rawIndex',
      ));
    }
    return chapters;
  }

  static List<Uri> extractRawArchiveUrls(String rawHtml) {
    final pattern = RegExp(
      r'''https?://(?:www\.)?(?:mediafire\.com|drive\.google\.com|mega\.nz|4shared\.com)(?=[/:?#]|$)[^\s<>"']*''',
      caseSensitive: false,
    );
    final unique = <String, Uri>{};
    for (final match in pattern.allMatches(rawHtml)) {
      var candidate = (match.group(0) ?? '').trim().replaceAll('&amp;', '&');
      candidate = candidate.replaceFirst(RegExp(r'[.,;:!?\)\]\}]+$'), '');
      final uri = Uri.tryParse(candidate);
      if (uri == null || !_isKnownArchiveHost(uri)) continue;
      unique.putIfAbsent(uri.toString(), () => uri);
    }
    return unique.values.toList(growable: false);
  }

  static List<({Uri uri, String label})> _intermediateLinks(
    String html,
    Uri postUri, {
    required bool bloggerMarkup,
  }) {
    final document = parser.parse(html);
    final unique = <String, ({Uri uri, String label})>{};
    final linkSelector =
        bloggerMarkup ? '.post-body a[href], .post a[href]' : 'a[href]';
    for (final link in document.querySelectorAll(linkSelector)) {
      final href = link.attributes['href']?.trim();
      if (href == null || href.isEmpty) continue;
      final uri = postUri.resolve(href);
      if (!_sameHost(uri, postUri) || uri == postUri || !_isHttp(uri)) continue;
      final label = [
        link.text,
        link.attributes['title'] ?? '',
        link.querySelector('img')?.attributes['alt'] ?? '',
      ].join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      final normalized = _normalizeHeuristicText(label);
      if (!_navigationTerms.any(normalized.contains)) continue;
      unique.putIfAbsent(uri.toString(), () => (uri: uri, label: label));
    }
    return unique.values.toList(growable: false);
  }

  static List<ComicChapter> _extractHostedChapters(
    String html, {
    required String comicId,
    required Uri pageUri,
    required String fallbackTitle,
  }) {
    final document = parser.parse(html);
    final heading = document.querySelector('h1')?.text.trim();
    final title = heading?.isNotEmpty == true
        ? heading
        : document.querySelector('title')?.text.trim();
    final pageLabel = (title?.isNotEmpty == true ? title! : fallbackTitle)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final found = <String, ComicChapter>{};

    for (final link in document.querySelectorAll('a[href]')) {
      final href = link.attributes['href']?.trim();
      if (href == null || href.isEmpty) continue;
      final uri = pageUri.resolve(href);
      if (!_isKnownArchiveHost(uri)) continue;
      final label = [
        link.text,
        link.attributes['title'] ?? '',
        link.querySelector('img')?.attributes['alt'] ?? '',
      ].firstWhere((text) => text.trim().isNotEmpty, orElse: () => '').trim();
      found.putIfAbsent(
          uri.toString(),
          () => ComicChapter(
                id: uri.toString(),
                comicId: comicId,
                title: label.isNotEmpty ? label : pageLabel,
              ));
    }
    for (final uri in extractRawArchiveUrls(html)) {
      found.putIfAbsent(
          uri.toString(),
          () => ComicChapter(
                id: uri.toString(),
                comicId: comicId,
                title: pageLabel,
              ));
    }
    return found.values.toList(growable: false);
  }

  static bool _isHttp(Uri uri) => uri.scheme == 'https' || uri.scheme == 'http';

  static bool _sameHost(Uri left, Uri right) =>
      left.host.toLowerCase() == right.host.toLowerCase();

  static bool _isKnownArchiveHost(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'mediafire.com' ||
        host.endsWith('.mediafire.com') ||
        host == 'drive.google.com' ||
        host == 'mega.nz' ||
        host.endsWith('.mega.nz') ||
        host == '4shared.com' ||
        host.endsWith('.4shared.com');
  }

  static String _normalizeHeuristicText(String text) => text
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u');
}
