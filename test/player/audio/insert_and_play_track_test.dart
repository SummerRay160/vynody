import 'package:audio_core/audio_core.dart';
import 'package:audio_core/src/audio_engine/audio_engine_interface.dart';
import 'package:audio_core/src/player_models.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAudioParent implements AudioVisualizerParent {
  AudioTrack? lastLoadedTrack;
  bool? lastAutoPlay;

  @override
  AudioEngine get engine => throw UnimplementedError();

  @override
  Future<void> clearPlayback() async {}

  @override
  Future<void> loadTrack({
    required bool autoPlay,
    Duration? position,
    PlaybackReason reason = PlaybackReason.playlistChanged,
    FadeSettings? fadeSetting,
  }) async {
    lastAutoPlay = autoPlay;
  }

  @override
  Future<bool> handlePlayRequested() async => false;

  @override
  Future<bool> canPlayTrack(AudioTrack track) async => true;

  @override
  Future<String> resolvePlayableUri(String rawUri) async => rawUri;

  @override
  void notifyListeners() {}
}

void main() {
  late FakeAudioParent parent;
  late PlaylistController playlist;

  setUp(() {
    parent = FakeAudioParent();
    playlist = PlaylistController(parent: parent);
  });

  test('insertAndPlayTrack into empty queue inserts and sets currentIndex to 0', () async {
    const track = AudioTrack(id: '/path/song1.mp3', uri: '/path/song1.mp3', title: 'Song 1');

    await playlist.insertAndPlayTrack(track);

    expect(playlist.items.length, 1);
    expect(playlist.items.first.id, track.id);
    expect(playlist.currentIndex, 0);
    expect(playlist.currentTrack?.id, track.id);
    expect(parent.lastAutoPlay, isTrue);
  });

  test('insertAndPlayTrack appends to end when index is null', () async {
    const track1 = AudioTrack(id: '/path/song1.mp3', uri: '/path/song1.mp3', title: 'Song 1');
    const track2 = AudioTrack(id: '/path/song2.mp3', uri: '/path/song2.mp3', title: 'Song 2');
    const track3 = AudioTrack(id: '/path/song3.mp3', uri: '/path/song3.mp3', title: 'Song 3');

    await playlist.addTracks([track1, track2]);
    expect(playlist.currentIndex, 0);

    await playlist.insertAndPlayTrack(track3);

    expect(playlist.items.length, 3);
    expect(playlist.items[0].id, track1.id);
    expect(playlist.items[1].id, track2.id);
    expect(playlist.items[2].id, track3.id);
    expect(playlist.currentIndex, 2);
    expect(playlist.currentTrack?.id, track3.id);
    expect(parent.lastAutoPlay, isTrue);
  });

  test('insertAndPlayTrack inserts at specific index and plays it', () async {
    const track1 = AudioTrack(id: '/path/song1.mp3', uri: '/path/song1.mp3', title: 'Song 1');
    const track2 = AudioTrack(id: '/path/song2.mp3', uri: '/path/song2.mp3', title: 'Song 2');
    const newTrack = AudioTrack(id: '/path/new.mp3', uri: '/path/new.mp3', title: 'New Song');

    await playlist.addTracks([track1, track2]);
    expect(playlist.currentIndex, 0);

    // Insert at index 1 (between track1 and track2)
    await playlist.insertAndPlayTrack(newTrack, index: 1);

    expect(playlist.items.length, 3);
    expect(playlist.items[0].id, track1.id);
    expect(playlist.items[1].id, newTrack.id);
    expect(playlist.items[2].id, track2.id);
    expect(playlist.currentIndex, 1);
    expect(playlist.currentTrack?.id, newTrack.id);
    expect(parent.lastAutoPlay, isTrue);
  });
}
