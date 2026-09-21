import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vynody/models/music_file.dart';
import 'package:vynody/player/library/playlist_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Playlist Sorting & Reordering Tests', () {
    test('PlaylistService reorderPlaylist changes custom order', () async {
      final service = PlaylistService();
      final plA = Playlist(id: 'pl-a', name: 'Alpha');
      final plB = Playlist(id: 'pl-b', name: 'Beta');
      final plC = Playlist(id: 'pl-c', name: 'Gamma');

      await service.addPlaylist(plA);
      await service.addPlaylist(plB);
      await service.addPlaylist(plC);

      final initialCustom =
          service.playlists.where((p) => p.id.startsWith('pl-')).map((p) => p.id).toList();
      expect(initialCustom, equals(['pl-a', 'pl-b', 'pl-c']));

      // Find indices of pl-a and pl-c
      final indexA = service.playlists.indexWhere((p) => p.id == 'pl-a');
      final indexC = service.playlists.indexWhere((p) => p.id == 'pl-c');

      // Move pl-a to after pl-c
      await service.reorderPlaylist(indexA, indexC + 1);

      final reordered =
          service.playlists.where((p) => p.id.startsWith('pl-')).map((p) => p.id).toList();
      expect(reordered, equals(['pl-b', 'pl-c', 'pl-a']));
    });

    test('PlaylistService sortPlaylists sorts by name ascending and descending', () async {
      final service = PlaylistService();
      final pl1 = Playlist(id: 'pl-1', name: 'Zebra');
      final pl2 = Playlist(id: 'pl-2', name: 'Apple');
      final pl3 = Playlist(id: 'pl-3', name: 'Mango');

      await service.addPlaylist(pl1);
      await service.addPlaylist(pl2);
      await service.addPlaylist(pl3);

      // Sort by Name Ascending
      await service.sortPlaylists(
        field: PlaylistSortField.name,
        ascending: true,
      );

      final sortedAsc = service.playlists
          .where((p) => p.id.startsWith('pl-'))
          .map((p) => p.name)
          .toList();
      expect(sortedAsc, equals(['Apple', 'Mango', 'Zebra']));

      // Built-in favorites & default should still be at top
      expect(service.playlists.first.id, equals('default'));
      expect(service.playlists[1].id, equals(PlaylistService.favoritePlaylistId));

      // Sort by Name Descending
      await service.sortPlaylists(
        field: PlaylistSortField.name,
        ascending: false,
      );

      final sortedDesc = service.playlists
          .where((p) => p.id.startsWith('pl-'))
          .map((p) => p.name)
          .toList();
      expect(sortedDesc, equals(['Zebra', 'Mango', 'Apple']));
    });

    test('PlaylistService sortPlaylists sorts by trackCount', () async {
      final service = PlaylistService();
      final song1 = const MusicFile(path: '/music/1.mp3', name: '1.mp3');
      final song2 = const MusicFile(path: '/music/2.mp3', name: '2.mp3');
      final song3 = const MusicFile(path: '/music/3.mp3', name: '3.mp3');

      final plFew = Playlist(id: 'pl-few', name: 'Few', songs: [song1]);
      final plMany = Playlist(id: 'pl-many', name: 'Many', songs: [song1, song2, song3]);
      final plMedium = Playlist(id: 'pl-med', name: 'Medium', songs: [song1, song2]);

      await service.addPlaylist(plFew);
      await service.addPlaylist(plMany);
      await service.addPlaylist(plMedium);

      // Sort by trackCount Descending (most songs first)
      await service.sortPlaylists(
        field: PlaylistSortField.trackCount,
        ascending: false,
      );

      final sortedCounts = service.playlists
          .where((p) => p.id.startsWith('pl-'))
          .map((p) => p.songs.length)
          .toList();
      expect(sortedCounts, equals([3, 2, 1]));
    });

    test('PlaylistService sortPlaylists sorts by updatedAt and createdAt', () async {
      final service = PlaylistService();
      final now = DateTime.now();

      final plOld = Playlist(
        id: 'pl-old',
        name: 'Old',
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 5)),
      );
      final plRecent = Playlist(
        id: 'pl-recent',
        name: 'Recent',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
      );

      await service.addPlaylist(plOld);
      await service.addPlaylist(plRecent);

      // Sort by updatedAt descending (most recently updated first)
      await service.sortPlaylists(
        field: PlaylistSortField.updatedAt,
        ascending: false,
      );

      final sortedUpdated = service.playlists
          .where((p) => p.id.startsWith('pl-'))
          .map((p) => p.id)
          .toList();
      expect(sortedUpdated, equals(['pl-recent', 'pl-old']));
    });
  });
}
