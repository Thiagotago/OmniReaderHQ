import 'comic.dart';

abstract interface class ComicArchiveProvider {
  Future<List<String>> getOrCreatePages(Comic comic, ComicChapter chapter);
}
