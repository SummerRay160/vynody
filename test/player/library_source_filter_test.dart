import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vynody/player/library/library_source_filter.dart';
import 'package:vynody/player/remote/remote_server_models.dart';
import 'package:vynody/player/remote/services/remote_scan_root.dart';

class MockRemoteScanRootsNotifier extends RemoteScanRootsNotifier {
  final List<RemoteScanRoot> _roots;
  MockRemoteScanRootsNotifier(this._roots);

  @override
  Future<List<RemoteScanRoot>> build() async => _roots;
}

void main() {
  group('LibrarySourceFilter matchesSongPath', () {
    const localPath = 'C:\\Music\\song.mp3';
    const webdavPath1 = 'webdav://srv-1/Music/Track1.mp3';
    const webdavPath2 = 'webdav://srv-2/Audio/Track2.flac';

    test('LibrarySourceFilter.all matches all songs', () {
      const filter = LibrarySourceFilter.all;
      expect(filter.matchesSongPath(localPath), isTrue);
      expect(filter.matchesSongPath(webdavPath1), isTrue);
      expect(filter.matchesSongPath(webdavPath2), isTrue);
    });

    test('LibrarySourceFilter.local matches only local files', () {
      const filter = LibrarySourceFilter.local;
      expect(filter.matchesSongPath(localPath), isTrue);
      expect(filter.matchesSongPath(webdavPath1), isFalse);
      expect(filter.matchesSongPath(webdavPath2), isFalse);
    });

    test('LibrarySourceFilter.remote matches only specific server', () {
      final filterSrv1 = LibrarySourceFilter.remote(
        serverId: 'srv-1',
        serverName: 'NAS-1',
        serverType: RemoteServerType.webdav,
      );

      expect(filterSrv1.matchesSongPath(localPath), isFalse);
      expect(filterSrv1.matchesSongPath(webdavPath1), isTrue);
      expect(filterSrv1.matchesSongPath(webdavPath2), isFalse);
    });

    test('equality and hash code check', () {
      final filter1 = LibrarySourceFilter.remote(
        serverId: 'srv-1',
        serverName: 'NAS-1',
        serverType: RemoteServerType.webdav,
      );
      final filter2 = LibrarySourceFilter.remote(
        serverId: 'srv-1',
        serverName: 'NAS-1',
        serverType: RemoteServerType.webdav,
      );
      expect(filter1, equals(filter2));
      expect(filter1.hashCode, equals(filter2.hashCode));
      expect(
        LibrarySourceFilter.all,
        equals(const LibrarySourceFilter(type: LibrarySourceType.all)),
      );
    });
  });

  group('remoteIndexedServersProvider', () {
    test('groups multiple roots of same server into single summary', () async {
      final dummyRoots = [
        const RemoteScanRoot(
          id: 'root-1',
          serverId: 'nas',
          serverName: 'Home NAS',
          serverType: RemoteServerType.webdav,
          remotePath: '/Music',
          virtualUri: 'webdav://nas/Music',
          addedAt: 1000,
          songCount: 100,
        ),
        const RemoteScanRoot(
          id: 'root-2',
          serverId: 'nas',
          serverName: 'Home NAS',
          serverType: RemoteServerType.webdav,
          remotePath: '/Lossless',
          virtualUri: 'webdav://nas/Lossless',
          addedAt: 1000,
          songCount: 50,
        ),
        const RemoteScanRoot(
          id: 'root-3',
          serverId: 'smb-server',
          serverName: 'Office SMB',
          serverType: RemoteServerType.smb,
          remotePath: '/Shared/Songs',
          virtualUri: 'smb://smb-server/Shared/Songs',
          addedAt: 1000,
          songCount: 80,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          remoteScanRootsProvider.overrideWith(
            () => MockRemoteScanRootsNotifier(dummyRoots),
          ),
        ],
      );

      addTearDown(container.dispose);

      // Await future to let AsyncNotifier finish
      await container.read(remoteScanRootsProvider.future);

      final summaries = container.read(remoteIndexedServersProvider);
      expect(summaries.length, 2);

      final nas = summaries.firstWhere((s) => s.serverId == 'nas');
      expect(nas.serverName, 'Home NAS');
      expect(nas.serverType, RemoteServerType.webdav);
      expect(nas.totalSongs, 150);
      expect(nas.roots.length, 2);

      final smb = summaries.firstWhere((s) => s.serverId == 'smb-server');
      expect(smb.serverName, 'Office SMB');
      expect(smb.serverType, RemoteServerType.smb);
      expect(smb.totalSongs, 80);
      expect(smb.roots.length, 1);
    });
  });
}
