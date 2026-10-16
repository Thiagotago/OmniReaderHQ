import 'comic.dart';
import 'comic_source.dart';

/// A source that can provide catalog metadata and browse categories.
abstract class CatalogSource implements ComicSource {
  String get baseUrl;

  bool get supportsChapters;

  String? get chaptersUnavailableMessage;

  Future<List<String>> getCategories();

  Future<List<Comic>> getComicsByCategory([String? category, int page = 1]);

  Set<String> categoriesForComic(String comicId);
}
