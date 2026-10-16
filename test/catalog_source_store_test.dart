import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omni_reader/src/data/catalog_source_store.dart';
import 'package:omni_reader/src/domain/catalog_source_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts empty and persists configured sources', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CatalogSourceStore();
    final defaults = await store.load();
    expect(defaults, isEmpty);

    final catalog =
        CatalogSourceConfig.fromUrl('Catalog', 'https://catalog.example');
    await store.save([catalog]);
    final loaded = await store.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.name, 'Catalog');
  });

  test('consolidates duplicate source URLs saved by earlier app versions',
      () async {
    SharedPreferences.setMockInitialValues({
      'catalog_sources_v1': '''[
        {"id":"https://catalog.example/","name":"Catalog","baseUrl":"https://catalog.example/","enabled":true,"isPrimary":true},
        {"id":"https://catalog.example","name":"Catalog","baseUrl":"https://catalog.example","enabled":true,"isPrimary":false}
      ]''',
    });

    final sources = await CatalogSourceStore().load();

    expect(sources, hasLength(1));
    expect(sources.single.id, 'https://catalog.example');
    expect(sources.single.isPrimary, isTrue);
  });
}
