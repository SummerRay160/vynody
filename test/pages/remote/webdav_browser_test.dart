import 'package:flutter_test/flutter_test.dart';
import 'package:vynody/player/remote/remote_server_models.dart';

import 'package:vynody/player/remote/clients/webdav_client.dart';
import 'package:vynody/player/remote/proxy/remote_media_resolver.dart';
import 'package:vynody/player/remote/services/remote_scan_root.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testServer = RemoteServer(
    id: 'webdav_test',
    name: 'WebDAV NAS',
    type: RemoteServerType.webdav,
    url: 'http://127.0.0.1:8080/dav',
    username: 'admin',
    createdAt: DateTime.now(),
  );

  test('WebDavFile identifies audio, image, lyric extensions correctly', () {
    const audioFile = WebDavFile(
      path: '/Music/Track.flac',
      name: 'Track.flac',
      isDirectory: false,
      contentLength: 10485760,
    );
    expect(audioFile.isAudio, isTrue);
    expect(audioFile.isImage, isFalse);
    expect(audioFile.isLyric, isFalse);

    const webmFile = WebDavFile(
      path: '/Music/Track.webm',
      name: 'Track.webm',
      isDirectory: false,
      contentLength: 5242880,
    );
    expect(webmFile.isAudio, isTrue);
    expect(webmFile.isImage, isFalse);
    expect(webmFile.isLyric, isFalse);

    const lrcFile = WebDavFile(
      path: '/Music/Track.lrc',
      name: 'Track.lrc',
      isDirectory: false,
      contentLength: 1024,
    );
    expect(lrcFile.isAudio, isFalse);
    expect(lrcFile.isLyric, isTrue);

    const folder = WebDavFile(
      path: '/Music/Pop',
      name: 'Pop',
      isDirectory: true,
      contentLength: 0,
    );
    expect(folder.isAudio, isFalse);
    expect(folder.isDirectory, isTrue);
  });

  test('WebDav virtual URI generation and conversion', () {
    const audioFile = WebDavFile(
      path: '/Music/Rock/Song.mp3',
      name: 'Song.mp3',
      isDirectory: false,
      contentLength: 5000000,
    );

    final musicFile = RemoteMediaResolver.buildMusicFileFromWebDav(audioFile, testServer);
    expect(musicFile.path, 'webdav://webdav_test/Music/Rock/Song.mp3');
    expect(musicFile.title, 'Song');
    expect(musicFile.name, 'Song.mp3');
  });

  test('RemoteScanRoot model, normalization and URI matching', () {
    expect(normalizeRemotePath('/Music/Rock/'), '/Music/Rock');
    expect(normalizeRemotePath('Music/Rock'), '/Music/Rock');
    expect(normalizeRemotePath(''), '/');

    final rootId = RemoteScanRoot.generateId(testServer.id, '/Music/Rock/');
    expect(rootId, 'webdav_test:/Music/Rock');

    final virtualUri = RemoteScanRoot.generateVirtualUri(testServer, '/Music/Rock');
    expect(virtualUri, 'webdav://webdav_test/Music/Rock');

    final root = RemoteScanRoot(
      id: rootId,
      serverId: testServer.id,
      serverType: testServer.type,
      serverName: testServer.name,
      remotePath: '/Music/Rock',
      virtualUri: virtualUri,
      addedAt: 100000,
      songCount: 5,
    );

    expect(root.containsSong('webdav://webdav_test/Music/Rock/track1.mp3'), isTrue);
    expect(root.containsSong('webdav://webdav_test/Music/Rock/Sub/track2.flac'), isTrue);
    expect(root.containsSong('webdav://webdav_test/Music/Jazz/track3.mp3'), isFalse);
    expect(root.containsSong('webdav://other_server/Music/Rock/track1.mp3'), isFalse);

    final json = root.toJson();
    final restored = RemoteScanRoot.fromJson(json);
    expect(restored.id, root.id);
    expect(restored.serverId, root.serverId);
    expect(restored.serverType, root.serverType);
    expect(restored.serverName, root.serverName);
    expect(restored.remotePath, root.remotePath);
    expect(restored.virtualUri, root.virtualUri);
    expect(restored.songCount, 5);
  });
}
