import 'comic.dart';

class CatalogSearch {
  const CatalogSearch();

  String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[áàâãä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[íìîï]'), 'i')
      .replaceAll(RegExp('[óòôõö]'), 'o')
      .replaceAll(RegExp('[úùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  bool matches(Comic comic, String query, {Iterable<String> categories = const []}) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) return true;
    final searchable = normalize('${comic.title} ${comic.description} ${categories.join(' ')}');
    return searchable.contains(normalizedQuery);
  }
}
