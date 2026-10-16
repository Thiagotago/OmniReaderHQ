import 'package:flutter_test/flutter_test.dart';
import 'package:omni_reader/src/domain/catalog_search.dart';
import 'package:omni_reader/src/domain/comic.dart';

void main() {
  const search = CatalogSearch();
  const comic = Comic(id: 'c1', title: 'A Última Floresta', description: 'Uma aventura fantástica');

  test('matches normalized title, description and category without accents', () {
    expect(search.matches(comic, 'ultima floresta'), isTrue);
    expect(search.matches(comic, 'aventura fantastica'), isTrue);
    expect(search.matches(comic, 'fantasia', categories: ['Fantasia']), isTrue);
    expect(search.matches(comic, 'batman', categories: ['Fantasia']), isFalse);
  });
}
