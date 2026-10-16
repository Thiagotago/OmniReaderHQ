import 'package:flutter_test/flutter_test.dart';
import 'package:omni_reader/src/domain/catalog_source_config.dart';

void main() {
  test('normalizes a public source URL', () {
    final source =
        CatalogSourceConfig.fromUrl('Catalog', 'https://CATALOG.example/');
    expect(source.name, 'Catalog');
    expect(source.baseUrl, 'https://CATALOG.example');
    expect(source.isPrimary, isFalse);
  });

  test('rejects invalid and local addresses', () {
    expect(() => CatalogSourceConfig.fromUrl('Local', 'http://localhost:8080'),
        throwsFormatException);
    expect(() => CatalogSourceConfig.fromUrl('Invalid', 'file:///tmp/site'),
        throwsFormatException);
  });

  test('ignores legacy adapter metadata and restores a generic URL source', () {
    final restored = CatalogSourceConfig.fromJson({
      'id': 'legacy',
      'name': 'Acervo autorizado',
      'baseUrl': 'https://catalogo.exemplo.com',
      'type': 'legacyAdapter',
    });
    expect(restored.baseUrl, 'https://catalogo.exemplo.com');
    expect(restored.name, 'Acervo autorizado');
    expect(restored.toJson(), isNot(contains('type')));
  });
}
