import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'package:http/http.dart' as http;
import '../domain/comic.dart';
import '../domain/catalog_source.dart';
import 'smart_chapter_link_extractor.dart';

/// Generic adapter for public blogs using the standard Blogger template.
class BloggerSource implements CatalogSource {
  BloggerSource({required this.baseUrl})
      : sourceName = Uri.tryParse(baseUrl)?.host ?? 'Fonte';

  final String baseUrl;
  final String sourceName;
  // Shared by source instances so changing/rebuilding the source selector does
  // not discard catalog metadata already fetched during this app session.
  static final Map<String, List<String>> _categoriesCache = {};
  static final Map<String, List<Comic>> _catalogCache = {};
  static final Map<String, List<ComicChapter>> _chaptersCache = {};
  final Map<String, Set<String>> _comicCategories = {};

  @override
  bool get supportsChapters => true;

  @override
  String? get chaptersUnavailableMessage => null;

  /// Invalidates this source's in-memory metadata when the user explicitly
  /// refreshes the catalog. Normal source switching keeps the cached results.
  void clearCatalogCache() {
    final key = baseUrl.toLowerCase();
    _categoriesCache.remove(key);
    _catalogCache.removeWhere((cacheKey, _) => cacheKey.startsWith('$key|'));
    _chaptersCache.removeWhere((cacheKey, _) => cacheKey.startsWith('$key|'));
    _comicCategories.removeWhere((comicId, _) {
      final uri = Uri.tryParse(comicId);
      return uri != null &&
          uri.host.toLowerCase() ==
              (Uri.tryParse(baseUrl)?.host.toLowerCase() ?? '');
    });
  }

  Future<List<String>> getCategories() async {
    final cacheKey = baseUrl.toLowerCase();
    final cached = _categoriesCache[cacheKey];
    if (cached != null) return List.unmodifiable(cached);
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode != 200) return [];
      var document = parser.parse(response.body);
      List<String> categories = [];

      var links = document.querySelectorAll('a');
      for (var link in links) {
        String href = link.attributes['href'] ?? '';
        if (href.contains('/search/label/')) {
          String catName = link.text.trim();
          if (catName.isNotEmpty &&
              !categories.contains(catName) &&
              !catName.toLowerCase().contains('postagens') &&
              !catName.toLowerCase().contains('coment')) {
            categories.add(catName);
          }
        }
      }
      categories.sort();
      _categoriesCache[cacheKey] = List.unmodifiable(categories);
      return categories;
    } catch (e) {
      return [];
    }
  }

  String? _extractRealCover(dom.Element post) {
    var imgs = post.querySelectorAll('img');
    for (var img in imgs) {
      String? src = img.attributes['data-src'] ?? img.attributes['src'];
      if (src != null &&
          src.isNotEmpty &&
          !src.contains('blank.gif') &&
          !src.contains('1x1')) {
        return src;
      }
    }
    return null;
  }

  // Uses the blog's indexed search endpoint; callers should locally rank/filter
  // its results against their loaded catalog for predictable matches.
  Future<List<Comic>> searchComics(String query) async {
    if (query.trim().isEmpty) return getComics();

    List<Comic> searchedComics = [];
    String searchUrl = '$baseUrl/search?q=${Uri.encodeComponent(query)}';

    try {
      final response = await http.get(Uri.parse(searchUrl));
      if (response.statusCode != 200) return [];

      var document = parser.parse(response.body);
      var posts = document.querySelectorAll('.post-outer');

      for (var post in posts) {
        var titleElement = post.querySelector('.post-title a');
        if (titleElement != null) {
          String title = titleElement.text.trim();
          String postUrl = titleElement.attributes['href'] ?? '';
          String? coverSrc = _extractRealCover(post);

          if (postUrl.isNotEmpty) {
            if (!searchedComics.any((c) => c.id == postUrl)) {
              searchedComics.add(Comic(
                id: postUrl,
                title: title,
                coverUrl: coverSrc != null ? Uri.tryParse(coverSrc) : null,
                sourceNames: [sourceName],
              ));
              _comicCategories.putIfAbsent(postUrl, () => <String>{});
            }
          }
        }
      }
    } catch (e) {
      // Retorna vazio em caso de falha na rede
    }

    return searchedComics;
  }

  Future<List<Comic>> getComicsByCategory(
      [String? category, int page = 1]) async {
    if (page < 1 || page > 100) return const [];
    final cacheKey =
        '${baseUrl.toLowerCase()}|${category?.toLowerCase() ?? '*'}|$page';
    final cached = _catalogCache[cacheKey];
    if (cached != null) {
      for (final comic in cached) {
        if (category != null) {
          _comicCategories
              .putIfAbsent(comic.id, () => <String>{})
              .add(category);
        }
      }
      return List.unmodifiable(cached);
    }
    List<Comic> allComics = [];
    String? currentUrl = category != null
        ? Uri.parse(baseUrl)
            .resolve('/search/label/${Uri.encodeComponent(category)}')
            .toString()
        : baseUrl;

    var pagesFetched = 1;
    while (
        currentUrl != null && currentUrl.isNotEmpty && pagesFetched <= page) {
      final response = await http.get(Uri.parse(currentUrl));
      if (response.statusCode != 200) break;

      var document = parser.parse(response.body);
      var posts = document.querySelectorAll('.post-outer');

      if (pagesFetched == page)
        for (var post in posts) {
          var titleElement = post.querySelector('.post-title a');
          if (titleElement != null) {
            String title = titleElement.text.trim();
            String postUrl = titleElement.attributes['href'] ?? '';
            String? coverSrc = _extractRealCover(post);

            if (postUrl.isNotEmpty) {
              if (!allComics.any((c) => c.id == postUrl)) {
                allComics.add(Comic(
                  id: postUrl,
                  title: title,
                  coverUrl: coverSrc != null ? Uri.tryParse(coverSrc) : null,
                  sourceNames: [sourceName],
                ));
              }
              _comicCategories.putIfAbsent(postUrl, () => <String>{});
              if (category != null) _comicCategories[postUrl]!.add(category);
            }
          }
        }

      var olderPostsLink = document.querySelector('.blog-pager-older-link');
      if (olderPostsLink != null) {
        final olderHref = olderPostsLink.attributes['href'];
        currentUrl = olderHref == null
            ? null
            : Uri.parse(currentUrl).resolve(olderHref).toString();
      } else {
        currentUrl = null;
      }
      if (pagesFetched < page && currentUrl == null) break;
      pagesFetched++;
    }

    _catalogCache[cacheKey] = List.unmodifiable(allComics);
    return allComics;
  }

  Set<String> categoriesForComic(String comicId) =>
      Set.unmodifiable(_comicCategories[comicId] ?? const <String>{});

  @override
  Future<List<Comic>> getComics() async {
    return getComicsByCategory();
  }

  @override
  Future<List<ComicChapter>> getChapters(String comicId) async {
    final cacheKey = '${baseUrl.toLowerCase()}|$comicId';
    if (_chaptersCache.containsKey(cacheKey)) {
      return List.unmodifiable(_chaptersCache[cacheKey]!);
    }

    final summaryUri = Uri.tryParse(comicId);
    if (summaryUri == null || !_isOnSourceHost(summaryUri)) return const [];
    final response = await SmartChapterLinkExtractor.fetchSameHostPage(
      summaryUri,
      summaryUri,
    );
    if (response == null || response.statusCode != 200) {
      throw Exception('Falha ao carregar a postagem da HQ');
    }

    final chapters = await SmartChapterLinkExtractor.extract(
      html: response.body,
      comicId: comicId,
      postUri: summaryUri,
      bloggerMarkup: true,
    );
    _chaptersCache[cacheKey] = List.unmodifiable(chapters);
    return chapters;
  }

  /// Blogger posts can contain chapter links inline. The visible
  /// chapter number (e.g. "01") links directly to an external file host; only
  /// that link metadata is extracted here, never its target content.
  @visibleForTesting
  static List<ComicChapter> extractChaptersFromPost(
    String html, {
    required String comicId,
    required Uri postUri,
  }) {
    return SmartChapterLinkExtractor.extractDirectChapters(
      html,
      comicId: comicId,
      postUri: postUri,
      bloggerMarkup: true,
    );
  }

  @visibleForTesting
  static List<Uri> extractRawArchiveUrls(String rawHtml) =>
      SmartChapterLinkExtractor.extractRawArchiveUrls(rawHtml);

  bool _isOnSourceHost(Uri uri) =>
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.toLowerCase() ==
          (Uri.tryParse(baseUrl)?.host.toLowerCase() ?? '');
}
