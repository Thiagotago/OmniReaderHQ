import 'package:flutter_test/flutter_test.dart';
import 'package:omni_reader/src/data/remote_archive_service.dart';

void main() {
  test('identifies supported file-host links', () {
    expect(
      identifyArchiveHost(Uri.parse('https://www.mediafire.com/file/id/name')),
      RemoteArchiveHost.mediaFire,
    );
    expect(
      identifyArchiveHost(Uri.parse('https://drive.google.com/file/d/id/view')),
      RemoteArchiveHost.googleDrive,
    );
    expect(
      identifyArchiveHost(Uri.parse('https://mega.nz/file/id#key')),
      RemoteArchiveHost.mega,
    );
    expect(
      identifyArchiveHost(Uri.parse('https://www.4shared.com/file/id/name')),
      RemoteArchiveHost.fourShared,
    );
    expect(
      identifyArchiveHost(Uri.parse('https://files.example/download/id')),
      isNull,
    );
  });

  test('extracts file IDs from supported Google Drive URL forms', () {
    expect(
      extractGoogleDriveFileId(
        Uri.parse('https://drive.google.com/file/d/path-id/view'),
      ),
      'path-id',
    );
    expect(
      extractGoogleDriveFileId(
        Uri.parse('https://drive.google.com/open?id=query-id'),
      ),
      'query-id',
    );
  });
}
