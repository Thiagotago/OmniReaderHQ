import 'package:flutter_test/flutter_test.dart';
import 'package:omni_reader/src/data/blogger_source.dart';

void main() {
  group('BloggerSource.extractChaptersFromPost', () {
    final postUri = Uri.parse(
      'https://catalog.example/2026/01/sample-post.html',
    );

    test('reads numbered links embedded in the Blogger post', () {
      const html = '''
        <div class="post-body">
          <img src="cover.jpg" alt="Rainha de Preto">
          <p>Descrição da HQ</p>
          <a href="https://www.mediafire.com/file/one">01</a>
          <a href="https://drive.google.com/file/d/two/view">02</a>
          <a href="https://mega.nz/file/three">03</a>
        </div>
      ''';

      final chapters = BloggerSource.extractChaptersFromPost(
        html,
        comicId: postUri.toString(),
        postUri: postUri,
      );

      expect(chapters.map((chapter) => chapter.title), ['01', '02', '03']);
      expect(chapters.first.id, contains('mediafire.com/file/one'));
      expect(chapters.first.comicId, postUri.toString());
      expect(chapters.every((chapter) => chapter.archiveUri == null), isTrue);
    });

    test('ignores labels and links outside the post body', () {
      const html = '''
        <a href="https://www.mediafire.com/file/nope">04</a>
        <div class="post-body">
          <a href="https://catalog.example/search/label/Category">Category</a>
          <a href="https://catalog.example/2026/01/other.html">05</a>
          <a href="https://www.mediafire.com/file/good">05</a>
        </div>
      ''';

      final chapters = BloggerSource.extractChaptersFromPost(
        html,
        comicId: postUri.toString(),
        postUri: postUri,
      );

      expect(chapters.map((chapter) => chapter.title), ['05']);
    });

    test('finds raw text and malformed embed URLs and cleans punctuation', () {
      const html = '''
        <div class="post-body">
          Link direto: https://www.mediafire.com/file/raw-file,
          <iframe src="https://drive.google.com/file/d/drive-id/view."></iframe>
          https://mega.nz/file/mega-id#key!
          https://www.4shared.com/zip/raw-archive.zip),
          https://mediafire.com.evil.example/file/not-a-match
        </div>
      ''';

      final chapters = BloggerSource.extractChaptersFromPost(
        html,
        comicId: postUri.toString(),
        postUri: postUri,
      );

      expect(chapters.map((chapter) => chapter.id), [
        'https://www.mediafire.com/file/raw-file',
        'https://drive.google.com/file/d/drive-id/view',
        'https://mega.nz/file/mega-id#key',
        'https://www.4shared.com/zip/raw-archive.zip',
      ]);
    });

    test('deduplicates raw URL matches and decodes HTML query separators', () {
      final urls = BloggerSource.extractRawArchiveUrls('''
        https://drive.google.com/uc?id=file-id&amp;export=download,
        <a href="https://drive.google.com/uc?id=file-id&amp;export=download">Drive</a>
      ''');

      expect(urls, hasLength(1));
      expect(urls.single.queryParameters, {
        'id': 'file-id',
        'export': 'download',
      });
    });
  });
}
