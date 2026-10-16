import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:rar/rar.dart';

import '../domain/comic.dart';
import '../domain/comic_archive_provider.dart';

enum RemoteArchiveHost { mediaFire, googleDrive, mega, fourShared }

RemoteArchiveHost? identifyArchiveHost(Uri uri) {
  final host = uri.host.toLowerCase();
  if (host == 'mediafire.com' || host.endsWith('.mediafire.com')) {
    return RemoteArchiveHost.mediaFire;
  }
  if (host == 'drive.google.com' || host == 'www.drive.google.com') {
    return RemoteArchiveHost.googleDrive;
  }
  if (host == 'mega.nz' || host == 'www.mega.nz') {
    return RemoteArchiveHost.mega;
  }
  if (host == '4shared.com' || host.endsWith('.4shared.com')) {
    return RemoteArchiveHost.fourShared;
  }
  return null;
}

String? extractGoogleDriveFileId(Uri uri) {
  final pathSegments = uri.pathSegments;
  final fileIndex = pathSegments.indexOf('file');
  if (fileIndex >= 0 && pathSegments.length > fileIndex + 2) {
    final idIndex = pathSegments.indexOf('d', fileIndex + 1);
    if (idIndex >= 0 && pathSegments.length > idIndex + 1) {
      return pathSegments[idIndex + 1];
    }
  }
  return uri.queryParameters['id'];
}

/// Downloads archives from supported public file hosts and prepares pages.
class RemoteArchiveService implements ComicArchiveProvider {
  const RemoteArchiveService();

  @override
  Future<List<String>> getOrCreatePages(
    Comic comic,
    ComicChapter chapter,
  ) async {
    final chapterUri = Uri.tryParse(chapter.id);
    if (chapterUri == null ||
        (chapterUri.scheme != 'https' && chapterUri.scheme != 'http')) {
      throw Exception('Falha ao extrair as páginas: URL inválida.');
    }

    final host = identifyArchiveHost(chapterUri);
    if (host == null) {
      throw Exception('Falha ao extrair as páginas: host não reconhecido.');
    }
    if (host == RemoteArchiveHost.mega) {
      throw Exception(
        'Falha ao extrair as páginas: este host ainda não está integrado.',
      );
    }

    final appDir = await getApplicationDocumentsDirectory();
    final comicFolder = _safeName(comic.title);
    final chapterFolder = _safeName(chapter.title);
    final extractDir = Directory(
      '${appDir.path}/comics/$comicFolder/$chapterFolder',
    );
    if (await extractDir.exists()) {
      final cachedPages = _getSortedImages(extractDir);
      if (cachedPages.isNotEmpty) return cachedPages;
    }
    await extractDir.create(recursive: true);

    final tempFile = File(
      '${appDir.path}/archive_${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      if (host == RemoteArchiveHost.mediaFire) {
        await _downloadMediaFire(chapterUri, tempFile);
      } else if (host == RemoteArchiveHost.googleDrive) {
        await _downloadGoogleDrive(chapterUri, tempFile);
      } else if (host == RemoteArchiveHost.fourShared) {
        await _downloadFourShared(chapterUri, tempFile);
      } else {
        throw Exception('Este host ainda não está integrado.');
      }
      await _extractArchive(tempFile, extractDir);
      final pages = _getSortedImages(extractDir);
      if (pages.isEmpty) {
        throw Exception('Falha ao extrair as páginas do arquivo.');
      }
      return pages;
    } catch (error) {
      if (error.toString().contains('Falha ao extrair as páginas')) rethrow;
      throw Exception('Falha ao extrair as páginas: $error');
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  Future<void> _downloadMediaFire(Uri pageUri, File destination) async {
    final response = await http.get(pageUri);
    if (response.statusCode != 200) {
      throw Exception('O host retornou HTTP ${response.statusCode}.');
    }
    final document = html_parser.parse(response.body);
    final directUrl =
        document.querySelector('#downloadButton')?.attributes['href'];
    final directUri = directUrl == null ? null : Uri.tryParse(directUrl);
    if (directUri == null ||
        (directUri.scheme != 'http' && directUri.scheme != 'https')) {
      throw Exception('Não foi possível encontrar o link direto do arquivo.');
    }
    await Dio().download(directUri.toString(), destination.path);
  }

  Future<void> _downloadFourShared(Uri pageUri, File destination) async {
    final response = await http.get(pageUri).timeout(
          const Duration(seconds: 8),
          onTimeout: () =>
              throw TimeoutException('A página 4shared demorou demais.'),
        );
    if (response.statusCode != 200) {
      throw Exception('O host retornou HTTP ${response.statusCode}.');
    }

    final directUri = _findFourSharedArchiveUrl(response.body, pageUri);
    if (directUri == null) {
      throw Exception(
        'Não foi possível encontrar o link direto do arquivo no 4shared. O arquivo pode exigir acesso ou confirmação no site.',
      );
    }

    await Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(minutes: 3),
    )).download(directUri.toString(), destination.path);
  }

  Uri? _findFourSharedArchiveUrl(String body, Uri pageUri) {
    final document = html_parser.parse(body);
    final candidates = <Uri>[];

    void addCandidate(String? raw) {
      if (raw == null || raw.trim().isEmpty) return;
      final cleaned = raw
          .trim()
          .replaceAll('&amp;', '&')
          .replaceFirst(RegExp(r'[.,;:!?\)\]\}]+$'), '');
      final uri = Uri.tryParse(cleaned);
      if (uri == null) return;
      final resolved = pageUri.resolveUri(uri);
      if (resolved.scheme == 'https' || resolved.scheme == 'http') {
        candidates.add(resolved);
      }
    }

    for (final element in document.querySelectorAll(
        'a[href], iframe[src], form[action], input[value], button[data-url], [data-href]')) {
      for (final attribute in const [
        'href',
        'src',
        'action',
        'value',
        'data-url',
        'data-href',
      ]) {
        final value = element.attributes[attribute];
        if (attribute == 'value' &&
            (Uri.tryParse(value ?? '')?.hasAuthority != true)) {
          continue;
        }
        addCandidate(value);
      }
    }

    final rawArchivePattern = RegExp(
      r'''https?://[^\s<>"']+\.(?:rar|zip|cbz|cbr)(?:\?[^\s<>"']*)?''',
      caseSensitive: false,
    );
    for (final match in rawArchivePattern.allMatches(body)) {
      addCandidate(match.group(0));
    }

    for (final candidate in candidates) {
      if (_looksLikeArchiveUrl(candidate)) return candidate;
    }
    return null;
  }

  bool _looksLikeArchiveUrl(Uri uri) {
    return RegExp(r'\.(?:rar|zip|cbz|cbr)(?:[?&#]|$)', caseSensitive: false)
        .hasMatch(uri.toString());
  }

  Future<void> _downloadGoogleDrive(Uri pageUri, File destination) async {
    final fileId = extractGoogleDriveFileId(pageUri);
    if (fileId == null || fileId.isEmpty) {
      throw Exception(
          'Não foi possível identificar o arquivo no Google Drive.');
    }
    final downloadUri = Uri.https(
      'drive.google.com',
      '/uc',
      {'export': 'download', 'id': fileId},
    );
    final dio = Dio();
    final firstResponse = await dio.get<ResponseBody>(
      downloadUri.toString(),
      options: Options(responseType: ResponseType.stream),
    );
    if (firstResponse.statusCode != 200 || firstResponse.data == null) {
      throw Exception('O host retornou HTTP ${firstResponse.statusCode}.');
    }
    final firstHeaders = _flattenHeaders(firstResponse.headers.map);
    final firstBody = await _writeStreamOrReadHtml(
      firstResponse.data!.stream,
      firstHeaders,
      destination,
    );
    if (firstBody == null) {
      return;
    }

    final document = html_parser.parse(utf8.decode(
      firstBody,
      allowMalformed: true,
    ));
    final confirmation = _googleDriveConfirmation(document, downloadUri);
    if (confirmation == null) {
      throw Exception(
        'O Drive pediu confirmação, mas não foi possível ler um token confiável. Verifique as permissões do link.',
      );
    }
    final cookies = (firstHeaders['set-cookie'] ?? '')
        .split(RegExp(r',\s*(?=[^;,\s=]+=)'))
        .map((cookie) => cookie.split(';').first.trim())
        .where((cookie) => cookie.contains('='))
        .join('; ');
    final confirmedResponse = await dio.get<ResponseBody>(
      confirmation.toString(),
      options: Options(
        responseType: ResponseType.stream,
        headers: {if (cookies.isNotEmpty) 'cookie': cookies},
      ),
    );
    if (confirmedResponse.statusCode != 200 || confirmedResponse.data == null) {
      throw Exception(
        'O Drive não entregou o arquivo após a confirmação. Verifique se o link está acessível publicamente.',
      );
    }
    final confirmedBody = await _writeStreamOrReadHtml(
      confirmedResponse.data!.stream,
      _flattenHeaders(confirmedResponse.headers.map),
      destination,
    );
    if (confirmedBody != null) {
      throw Exception(
        'O Drive não entregou o arquivo após a confirmação. Verifique se o link está acessível publicamente.',
      );
    }
  }

  Uri? _googleDriveConfirmation(
    dom.Document document,
    Uri defaultUri,
  ) {
    for (final link in document.querySelectorAll('a[href]')) {
      final href = link.attributes['href'];
      if (href == null) continue;
      final uri = defaultUri.resolve(href);
      if (uri.queryParameters.containsKey('confirm')) return uri;
    }
    for (final form in document.querySelectorAll('form')) {
      final values = <String, String>{};
      for (final input in form.querySelectorAll('input[name]')) {
        final name = input.attributes['name'];
        final value = input.attributes['value'];
        if (name != null && value != null) values[name] = value;
      }
      if (!values.containsKey('confirm')) continue;
      final action = form.attributes['action'];
      final actionUri = action == null || action.isEmpty
          ? defaultUri
          : defaultUri.resolve(action);
      return actionUri.replace(
        queryParameters: {...actionUri.queryParameters, ...values},
      );
    }
    return null;
  }

  Map<String, String> _flattenHeaders(Map<String, List<String>> headers) =>
      headers.map(
          (name, values) => MapEntry(name.toLowerCase(), values.join(',')));

  Future<List<int>?> _writeStreamOrReadHtml(
    Stream<List<int>> stream,
    Map<String, String> headers,
    File destination,
  ) async {
    final iterator = StreamIterator<List<int>>(stream);
    final buffered = BytesBuilder(copy: false);
    while (buffered.length < 128 && await iterator.moveNext()) {
      buffered.add(iterator.current);
    }
    final prefix = buffered.takeBytes();
    if (_looksHtml(headers, prefix)) {
      buffered.add(prefix);
      while (await iterator.moveNext()) {
        buffered.add(iterator.current);
      }
      await iterator.cancel();
      return buffered.takeBytes();
    }

    final sink = destination.openWrite();
    sink.add(prefix);
    while (await iterator.moveNext()) {
      sink.add(iterator.current);
    }
    await sink.flush();
    await sink.close();
    await iterator.cancel();
    return null;
  }

  bool _looksHtml(Map<String, String> headers, List<int> bytes) {
    final contentType = headers['content-type']?.toLowerCase() ?? '';
    if (contentType.contains('text/html')) return true;
    final prefix = utf8
        .decode(
          bytes.take(128).toList(),
          allowMalformed: true,
        )
        .trimLeft()
        .toLowerCase();
    return prefix.startsWith('<!doctype html') || prefix.startsWith('<html');
  }

  Future<void> _extractArchive(File archiveFile, Directory extractDir) async {
    var extracted = false;
    try {
      final archive = ZipDecoder().decodeBytes(await archiveFile.readAsBytes());
      for (final entry in archive) {
        if (!entry.isFile ||
            !_isSafeArchivePath(entry.name) ||
            !_isImage(entry.name)) {
          continue;
        }
        final output = File('${extractDir.path}/${entry.name}');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(entry.content as List<int>);
        extracted = true;
      }
    } on Object {
      // If the payload is not ZIP, try the RAR decoder below.
    }
    if (extracted) return;

    try {
      final result = await Rar.extractRarFile(
        rarFilePath: archiveFile.path,
        destinationPath: extractDir.path,
      );
      extracted = result['success'] == true;
    } on Object {
      // The common error below is shown for unsupported or invalid archives.
    }
    if (!extracted)
      throw Exception('Formato compactado inválido ou não suportado.');
  }

  bool _isSafeArchivePath(String filename) {
    final normalized = filename.replaceAll('\\', '/');
    return !normalized.startsWith('/') &&
        !normalized.split('/').any((part) => part == '..');
  }

  String _safeName(String value) {
    final safe = value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return safe.isEmpty ? 'item' : safe;
  }

  bool _isImage(String filename) {
    final lower = filename.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  int _extractPageNumber(String filename) {
    final matches = RegExp(r'\d+').allMatches(filename);
    return matches.isEmpty ? 0 : int.parse(matches.last.group(0)!);
  }

  List<String> _getSortedImages(Directory directory) {
    if (!directory.existsSync()) return const [];
    final files = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => _isImage(file.path) && file.lengthSync() > 5000)
        .toList();
    files.sort((left, right) {
      final nameA = left.uri.pathSegments.last;
      final nameB = right.uri.pathSegments.last;
      final numberCompare =
          _extractPageNumber(nameA).compareTo(_extractPageNumber(nameB));
      return numberCompare == 0
          ? left.path.compareTo(right.path)
          : numberCompare;
    });
    return files.map((file) => file.path).toList();
  }
}
