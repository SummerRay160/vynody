import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vynody/models/music_file.dart';
import 'package:vynody/player/audio/app_playback_mode.dart';
import 'package:vynody/player/audio/playback_session_manager.dart';
import 'package:vynody/player/library/playlist_service.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;
  FakePathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationSupportPath() async => tempDir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testTempDir;
  late SharedPreferences prefs;

  setUp(() async {
    testTempDir = Directory.systemTemp.createTempSync('playback_session_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(testTempDir);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() {
    try {
      if (testTempDir.existsSync()) {
        testTempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('PlaybackSessionManager', () {
    final sampleMusic = MusicFile(
      path: '/test/music/song1.mp3',
      name: 'Song 1',
      title: 'Title 1',
      artist: 'Artist 1',
      album: 'Album 1',
      durationMillis: 180000,
    );

    final sampleSession = PlaybackSessionData(
      queue: [sampleMusic],
      currentIndex: 0,
      positionMs: 45000,
      playbackMode: AppPlaybackMode.queueLoop,
      randomPlayback: const RandomPlaybackData(
        enabled: false,
        history: [],
        historyCursor: null,
        deck: [],
        deckCursor: null,
        deckSignature: null,
        stashedNextTrackId: null,
        stashedForTrackId: null,
      ),
    );

    test('saves session to playback_session.json and removes legacy prefs key', () async {
      final manager = PlaybackSessionManager();

      // Pre-set legacy key
      await prefs.setString('playback_session_v1', '{"legacy": true}');

      await manager.saveToPrefs(prefs, sampleSession);

      final sessionFile = File(p.join(testTempDir.path, 'playback_session.json'));
      expect(await sessionFile.exists(), isTrue);

      // Verify file content
      final content = jsonDecode(await sessionFile.readAsString()) as Map<String, dynamic>;
      expect(content['version'], 1);
      expect(content['currentIndex'], 0);
      expect(content['positionMs'], 45000);

      // Verify legacy prefs key removed
      expect(prefs.containsKey('playback_session_v1'), isFalse);
    });

    test('loads session from playback_session.json', () async {
      final manager = PlaybackSessionManager();
      await manager.saveToPrefs(prefs, sampleSession);

      final loaded = await manager.loadFromPrefs(prefs);
      expect(loaded, isNotNull);
      expect(loaded!.queue.length, 1);
      expect(loaded.queue.first.path, sampleMusic.path);
      expect(loaded.currentIndex, 0);
      expect(loaded.positionMs, 45000);
      expect(loaded.playbackMode, AppPlaybackMode.queueLoop);
    });

    test('migrates legacy SharedPreferences data to JSON file and cleans prefs', () async {
      final manager = PlaybackSessionManager();

      // Write legacy session to prefs
      final legacyState = {
        'version': 1,
        'queue': [
          {
            'path': '/legacy/song.mp3',
            'name': 'Legacy Song',
            'title': 'Legacy Title',
            'artist': 'Legacy Artist',
          }
        ],
        'currentIndex': 0,
        'positionMs': 12000,
        'playbackMode': 'loop',
        'randomPlayback': {
          'enabled': false,
          'history': [],
          'historyCursor': null,
          'deck': [],
          'deckCursor': null,
          'deckSignature': null,
          'stashedNextTrackId': null,
          'stashedForTrackId': null,
        },
      };
      await prefs.setString('playback_session_v1', jsonEncode(legacyState));

      final sessionFile = File(p.join(testTempDir.path, 'playback_session.json'));
      expect(await sessionFile.exists(), isFalse);

      final loaded = await manager.loadFromPrefs(prefs);
      expect(loaded, isNotNull);
      expect(loaded!.queue.length, 1);
      expect(loaded.queue.first.path, '/legacy/song.mp3');
      expect(loaded.positionMs, 12000);

      // Verify file was written and prefs key removed
      expect(await sessionFile.exists(), isTrue);
      expect(prefs.containsKey('playback_session_v1'), isFalse);
    });

    test('clearFromPrefs deletes session file and clears legacy prefs key', () async {
      final manager = PlaybackSessionManager();
      await manager.saveToPrefs(prefs, sampleSession);
      await prefs.setString('playback_session_v1', 'legacy');

      final sessionFile = File(p.join(testTempDir.path, 'playback_session.json'));
      expect(await sessionFile.exists(), isTrue);

      await manager.clearFromPrefs(prefs);
      expect(await sessionFile.exists(), isFalse);
      expect(prefs.containsKey('playback_session_v1'), isFalse);
    });
  });

  group('PlaylistService file storage and migration', () {
    test('migrates legacy playlists from SharedPreferences to playlists.json', () async {
      final legacyPlaylists = [
        {
          'id': 'p1',
          'name': 'My Playlist',
          'songs': [
            {
              'path': '/test/music/song1.mp3',
              'name': 'Song 1',
            }
          ],
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        }
      ];
      await prefs.setString('playlists', jsonEncode(legacyPlaylists));

      final playlistService = PlaylistService();
      // Wait for _init to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final playlistsFile = File(p.join(testTempDir.path, 'playlists.json'));
      expect(await playlistsFile.exists(), isTrue);
      expect(prefs.containsKey('playlists'), isFalse);

      final hasCustom = playlistService.playlists.any((p) => p.id == 'p1');
      expect(hasCustom, isTrue);
    });
  });
}
