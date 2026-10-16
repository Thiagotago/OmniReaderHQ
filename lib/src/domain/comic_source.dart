import 'comic.dart';

/// Replace this class with a repository-backed implementation to change
/// where comic metadata and chapter lists come from.
abstract class ComicSource {
  Future<List<Comic>> getComics();

  Future<List<ComicChapter>> getChapters(String comicId);
}
