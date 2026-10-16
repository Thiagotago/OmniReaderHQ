import 'dart:io';
import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/comic.dart';
import '../domain/comic_archive_provider.dart';

/// Creates a local sample CBZ and extracts it into the app's support folder.
/// Replace this service with a permitted file-provider implementation later.
class MockArchiveService implements ComicArchiveProvider {
  @override
  Future<List<String>> getOrCreatePages(
    Comic comic,
    ComicChapter chapter,
  ) async {
    final supportDirectory = await getApplicationSupportDirectory();
    final chapterDirectory = Directory(
      '${supportDirectory.path}/omni_reader_v1/${comic.id}/${chapter.id}',
    );
    final pagesDirectory = Directory('${chapterDirectory.path}/pages');
    final cachedPages = await _listPages(pagesDirectory);
    if (cachedPages.isNotEmpty) return cachedPages;

    await pagesDirectory.create(recursive: true);
    final archiveFile = File('${chapterDirectory.path}/${chapter.id}.cbz');
    final archive = Archive();
    for (var page = 0; page < chapter.mockPageCount; page++) {
      final bytes = await _renderSamplePage(comic, chapter, page);
      archive.addFile(ArchiveFile(
        'page_${(page + 1).toString().padLeft(2, '0')}.png',
        bytes.length,
        bytes,
      ));
    }

    // This writes only generated fixture pages; there is no network request.
    final encodedArchive = ZipEncoder().encode(archive);
    if (encodedArchive == null) {
      throw StateError('Não foi possível gerar o arquivo de demonstração.');
    }
    await archiveFile.writeAsBytes(encodedArchive);
    final decoded = ZipDecoder().decodeBytes(await archiveFile.readAsBytes());
    for (final entry in decoded.files) {
      if (!entry.isFile || !_isSafePageName(entry.name)) continue;
      final bytes = entry.content as List<int>;
      await File('${pagesDirectory.path}/${entry.name}').writeAsBytes(bytes);
    }
    return _listPages(pagesDirectory);
  }

  Future<List<String>> _listPages(Directory directory) async {
    if (!await directory.exists()) return const [];
    final files = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.png'))
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files.map((file) => file.path).toList(growable: false);
  }

  bool _isSafePageName(String name) {
    return RegExp(r'^page_[0-9]{2}\.png$').hasMatch(name);
  }

  Future<List<int>> _renderSamplePage(
    Comic comic,
    ComicChapter chapter,
    int pageIndex,
  ) async {
    const width = 900;
    const height = 1300;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final pageNumber = pageIndex + 1;
    final background = Paint()..color = const Color(0xFFF2E9D8);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      background,
    );

    final ink = Paint()..color = const Color(0xFF252331);
    _drawCaption(canvas, '${comic.title.toUpperCase()}  ·  ${chapter.title}',
        54, 38, 30, ink.color);

    const panels = <Rect>[
      const Rect.fromLTWH(54, 112, 792, 330),
      const Rect.fromLTWH(54, 476, 380, 330),
      const Rect.fromLTWH(466, 476, 380, 330),
      const Rect.fromLTWH(54, 840, 792, 330),
    ];
    for (var index = 0; index < panels.length; index++) {
      final panel = panels[index];
      canvas.drawRect(panel, ink);
      final inset = panel.deflate(8);
      canvas.drawRect(inset, Paint()..color = const Color(0xFFFFFCF5));
      final scenePaint = Paint()
        ..color = index.isEven ? comic.coverColor : const Color(0xFFB8A7C9);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(inset.left + 28, inset.top + 32, inset.width - 56,
              inset.height * .49),
          const Radius.circular(12),
        ),
        scenePaint,
      );
      canvas.drawCircle(
        Offset(inset.center.dx, inset.top + inset.height * .45),
        inset.width * .105,
        Paint()..color = const Color(0xFFFFD166),
      );
      _drawCaption(
        canvas,
        'QUADRO ${index + 1}  —  PÁGINA $pageNumber',
        inset.left + 24,
        inset.top + inset.height * .69,
        21,
        ink.color,
      );
      _drawCaption(
        canvas,
        'Página de amostra criada localmente para o protótipo.',
        inset.left + 24,
        inset.top + inset.height * .82,
        16,
        ink.color,
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    picture.dispose();
    return _encodeRgbaPng(data!.buffer.asUint8List(), width, height);
  }

  void _drawCaption(
    Canvas canvas,
    String text,
    double x,
    double y,
    double fontSize,
    Color color,
  ) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: fontSize, maxLines: 2),
    )..pushStyle(ui.TextStyle(color: color, fontSize: fontSize));
    builder.addText(text);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 790));
    canvas.drawParagraph(paragraph, Offset(x, y));
  }
}

Uint8List _encodeRgbaPng(Uint8List pixels, int width, int height) {
  final rowBytes = width * 4;
  final stride = rowBytes + 1;
  final scanlines = Uint8List(stride * height);
  for (var row = 0; row < height; row++) {
    final destination = row * stride;
    scanlines[destination] = 0;
    scanlines.setRange(
      destination + 1,
      destination + stride,
      pixels,
      row * rowBytes,
    );
  }

  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 6)
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);

  final png = BytesBuilder()..add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  _addPngChunk(png, 'IHDR', header.buffer.asUint8List());
  _addPngChunk(png, 'IDAT', Uint8List.fromList(io.zlib.encode(scanlines)));
  _addPngChunk(png, 'IEND', Uint8List(0));
  return png.takeBytes();
}

void _addPngChunk(BytesBuilder output, String type, Uint8List data) {
  final typeBytes = Uint8List.fromList(type.codeUnits);
  final length = ByteData(4)..setUint32(0, data.length);
  final checksumInput = Uint8List(typeBytes.length + data.length)
    ..setRange(0, typeBytes.length, typeBytes)
    ..setRange(typeBytes.length, typeBytes.length + data.length, data);
  final checksum = ByteData(4)..setUint32(0, _crc32(checksumInput));
  output
    ..add(length.buffer.asUint8List())
    ..add(typeBytes)
    ..add(data)
    ..add(checksum.buffer.asUint8List());
}

int _crc32(Uint8List bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
