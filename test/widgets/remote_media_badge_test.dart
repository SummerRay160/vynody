import 'package:flutter_test/flutter_test.dart';
import 'package:vynody/models/music_file.dart';
import 'package:vynody/widgets/remote_media_badge.dart';

void main() {
  group('RemoteMediaHelper', () {
    MusicFile createSong(String path) {
      return MusicFile(
        path: path,
        name: 'Track',
      );
    }

    test('isRemote identifies remote scheme URIs', () {
      expect(RemoteMediaHelper.isRemote(createSong('subsonic://srv1/123')), isTrue);
      expect(RemoteMediaHelper.isRemote(createSong('webdav://srv2/music.mp3')), isTrue);
      expect(RemoteMediaHelper.isRemote(createSong('smb://share/song.flac')), isTrue);
      expect(RemoteMediaHelper.isRemote(createSong('jellyfin://jf/456')), isTrue);
      expect(RemoteMediaHelper.isRemote(createSong('C:\\Music\\local.mp3')), isFalse);
      expect(RemoteMediaHelper.isRemote(createSong('/storage/emulated/0/local.mp3')), isFalse);
    });

    test('isAllRemote returns true only when all songs are remote', () {
      final allRemote = [
        createSong('subsonic://srv1/1'),
        createSong('webdav://srv2/2'),
      ];
      final mixed = [
        createSong('subsonic://srv1/1'),
        createSong('C:\\Music\\2.mp3'),
      ];
      final allLocal = [
        createSong('C:\\Music\\1.mp3'),
        createSong('C:\\Music\\2.mp3'),
      ];

      expect(RemoteMediaHelper.isAllRemote(allRemote), isTrue);
      expect(RemoteMediaHelper.isAllRemote(mixed), isFalse);
      expect(RemoteMediaHelper.isAllRemote(allLocal), isFalse);
      expect(RemoteMediaHelper.isAllRemote([]), isFalse);
    });

    test('isMixed returns true only when both local and remote songs are present', () {
      final allRemote = [
        createSong('subsonic://srv1/1'),
        createSong('webdav://srv2/2'),
      ];
      final mixed = [
        createSong('subsonic://srv1/1'),
        createSong('C:\\Music\\2.mp3'),
      ];
      final allLocal = [
        createSong('C:\\Music\\1.mp3'),
        createSong('C:\\Music\\2.mp3'),
      ];

      expect(RemoteMediaHelper.isMixed(mixed), isTrue);
      expect(RemoteMediaHelper.isMixed(allRemote), isFalse);
      expect(RemoteMediaHelper.isMixed(allLocal), isFalse);
      expect(RemoteMediaHelper.isMixed([]), isFalse);
    });
  });
}
