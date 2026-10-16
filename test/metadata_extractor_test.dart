import 'package:flutter_test/flutter_test.dart';

import 'package:omni_reader/src/catalog/metadata_extractor.dart';

void main() {
  test('indexes title, cover and chapter metadata without downloading files', () {
    const html = '''
      <html>
        <head>
          <title>Fallback title</title>
          <meta property="og:title" content="Minha HQ &amp; coleção">
          <meta property="og:image" content="/covers/one.jpg">
        </head>
        <body>
          <a href="/chapter/1">Capítulo 1</a>
          <a href="/about">Sobre o site</a>
          <a href="chapter/2">Chapter 2</a>
        </body>
      </html>
    ''';

    final entry = const MetadataExtractor().extract(
      sourceUrl: Uri.parse('https://example.test/library/'),
      html: html,
    );

    expect(entry.title, 'Minha HQ & coleção');
    expect(entry.coverUrl.toString(), 'https://example.test/covers/one.jpg');
    expect(entry.chapters.map((chapter) => chapter.title).toList(), [
      'Capítulo 1',
      'Chapter 2',
    ]);
    expect(entry.chapters[1].url.toString(),
        'https://example.test/library/chapter/2');
  });
}
