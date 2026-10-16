import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omni_reader/src/domain/comic.dart';
import 'package:omni_reader/src/domain/favorites_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists favorites and toggling removes an existing favorite', () async {
    const comic = Comic(id: 'one', title: 'HQ Um');
    final store = FavoritesStore();

    await store.toggle(comic);
    expect((await store.load()).map((item) => item.id), ['one']);

    await store.toggle(comic);
    expect(await store.load(), isEmpty);
  });
}
