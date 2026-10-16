import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omni_reader/src/domain/collection_store.dart';
import 'package:omni_reader/src/domain/comic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creates collections and toggles a comic in and out', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CollectionStore();
    const comic = Comic(id: 'c1', title: 'HQ Um');

    await store.create('Para ler');
    await store.toggleComic('Para ler', comic);
    expect((await store.load()).single.comics.single.id, 'c1');
    await store.toggleComic('Para ler', comic);
    expect((await store.load()).single.comics, isEmpty);
    await store.delete('Para ler');
    expect(await store.load(), isEmpty);
  });
}
