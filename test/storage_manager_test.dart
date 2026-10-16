import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omni_reader/src/data/storage_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('measures and clears only files under the comics directory', () async {
    SharedPreferences.setMockInitialValues({});
    final root = await Directory.systemTemp.createTemp('comic-storage-test');
    addTearDown(() => root.delete(recursive: true));
    final comics = Directory('${root.path}/comics')..createSync();
    final archive = File('${comics.path}/page.jpg');
    await archive.writeAsBytes(List.filled(128, 7));
    final chapter = Directory('${comics.path}/HQ_Dois/Capitulo_1')..createSync(recursive: true);
    await File('${chapter.path}/page.png').writeAsBytes(List.filled(64, 9));

    final manager = StorageManager(rootProvider: () async => root);
    await manager.recordChapter(folderId: 'HQ_Dois', comicTitle: 'HQ Dois', chapterId: 'Capitulo_1', completed: true);
    expect((await manager.loadChapterIndex())['HQ_Dois'], {'Capitulo_1'});
    expect((await manager.loadCompletedChapterIndex())['HQ_Dois'], {'Capitulo_1'});
    expect(await manager.getUsedBytes(), 192);
    final stored = await manager.listStoredComics();
    expect(stored.single.title, 'HQ Dois');
    expect(stored.single.bytes, 64);
    expect(stored.single.chapters.single.id, 'Capitulo_1');
    await manager.deleteChapter('HQ_Dois', 'Capitulo_1');
    expect((await manager.loadChapterIndex())['HQ_Dois'], isEmpty);
    expect((await manager.loadCompletedChapterIndex())['HQ_Dois'], isEmpty);
    expect((await manager.listStoredComics()).single.bytes, 0);
    await manager.deleteComic(stored.single.id);
    expect(await manager.listStoredComics(), isEmpty);
    expect(await manager.getUsedBytes(), 128);
    await manager.clear();
    expect(await manager.getUsedBytes(), 0);
    expect(await comics.exists(), isTrue);
  });
}
