import 'comic.dart';

class CatalogDeduplicator {
  const CatalogDeduplicator();

  List<Comic> merge(Iterable<List<Comic>> catalogs) {
    final merged = <String, Comic>{};
    for (final catalog in catalogs) {
      for (final comic in catalog) {
        final key = normalizeTitle(comic.title);
        if (key.isEmpty) continue;
        final existing = merged[key];
        if (existing == null) {
          merged[key] = comic;
          continue;
        }
        final sourceNames = {...existing.sourceNames, ...comic.sourceNames}.toList();
        final alsoFoundAt = {...existing.alsoFoundAt, ...comic.alsoFoundAt, ...comic.sourceNames}
            .where((source) => !existing.sourceNames.contains(source))
            .toList();
        merged[key] = Comic(
          id: existing.id,
          title: existing.title,
          description: existing.description,
          coverColor: existing.coverColor,
          coverIcon: existing.coverIcon,
          coverUrl: existing.coverUrl ?? comic.coverUrl,
          sourceNames: sourceNames,
          alsoFoundAt: alsoFoundAt,
        );
      }
    }
    return merged.values.toList(growable: false);
  }

  String normalizeTitle(String title) => title
      .toLowerCase()
      .replaceAll(RegExp('[áàâãä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[íìîï]'), 'i')
      .replaceAll(RegExp('[óòôõö]'), 'o')
      .replaceAll(RegExp('[úùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}
