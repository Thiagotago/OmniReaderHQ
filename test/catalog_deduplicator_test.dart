import 'package:flutter_test/flutter_test.dart';
import 'package:omni_reader/src/domain/catalog_deduplicator.dart';
import 'package:omni_reader/src/domain/comic.dart';

void main() {
  const deduplicator = CatalogDeduplicator();

  test('merges exact normalized titles and keeps primary source entry', () {
    const primary = Comic(
        id: 'https://catalog-a.example/a',
        title: 'A Última Floresta',
        sourceNames: ['Catalog A']);
    const secondary = Comic(
        id: 'https://dc.example/a',
        title: 'a ultima floresta!',
        sourceNames: ['DC Blog']);

    final result = deduplicator.merge([
      [primary],
      [secondary]
    ]);
    expect(result, hasLength(1));
    expect(result.single.id, primary.id);
    expect(result.single.sourceNames, containsAll(['Catalog A', 'DC Blog']));
    expect(result.single.alsoFoundAt, ['DC Blog']);
  });

  test('keeps different issue titles separate', () {
    final result = deduplicator.merge([
      const [Comic(id: 'one', title: 'Batman 1')],
      const [Comic(id: 'two', title: 'Batman 2')],
    ]);
    expect(result, hasLength(2));
  });

  test('keeps distinct editions with year or format markers separate', () {
    final result = deduplicator.merge([
      const [Comic(id: 'one', title: 'Batman 01 (2024)')],
      const [Comic(id: 'two', title: 'Batman 01 (2025)')],
      const [Comic(id: 'three', title: 'Batman 01 - Edição especial')],
    ]);
    expect(result, hasLength(3));
  });
}
