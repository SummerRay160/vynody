import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:vynody/player/audio/audio_service.dart' as app; // To distinguish from package:audio_service
import 'package:vynody/player/audio/audio_handler.dart';
import 'package:vynody/models/music_file.dart';

class DarwinIntegrationService {
  final app.AudioService audioService;
  late MyAudioHandler _handler;
  bool _initialized = false;
  String? _lastMetadataKey;
  Duration _lastTimelineDuration = Duration.zero;
  bool _hasForwardedTimeline = false;
  DateTime _lastTimelineForwardedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Duration _lastTimelinePosition = Duration.zero;

  DarwinIntegrationService(this.audioService) {
    if (!Platform.isIOS && !Platform.isMacOS) return;
    _init();
  }

  Future<void> _init() async {
    try {
      if (Platform.isIOS) {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());

        // Listen to interruptions (phone calls, alarms, Siri, etc.)
        session.interruptionEventStream.listen((event) {
          if (event.begin) {
            switch (event.type) {
              case AudioInterruptionType.duck:
                // Lower the volume (ducking)
                audioService.playbackController.player.setVolume(audioService.volume / 200.0);
                break;
              case AudioInterruptionType.pause:
              case AudioInterruptionType.unknown:
                audioService.playbackController.player.pause();
                break;
            }
          } else {
            switch (event.type) {
              case AudioInterruptionType.duck:
                // Restore volume
                audioService.playbackController.player.setVolume(audioService.volume / 100.0);
                break;
              case AudioInterruptionType.pause:
              case AudioInterruptionType.unknown:
                // Do not automatically resume playback unless it's a transient interruption
                break;
            }
          }
        });

        // Listen to headphone unplugged events (becoming noisy)
        session.becomingNoisyEventStream.listen((_) {
          audioService.playbackController.player.pause();
        });
      }

      // Initialize the audio_service background handler
      _handler = await AudioService.init(
        builder: () => MyAudioHandler(audioService),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'app.vynody.player.channel.audio',
          androidNotificationChannelName: 'Vynody Playback',
          androidNotificationIcon: 'mipmap/launcher_icon',
        ),
      );
      _initialized = true;
      _updateInitialState();
    } catch (e, st) {
      debugPrint('Darwin audio service/session init failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  void _updateInitialState() {
    if (!_initialized) return;
    updatePlaybackStatus(audioService.isPlaying);
    updateMetadata(null);
  }

  void updateMetadata(MusicFile? song) {
    if ((!Platform.isIOS && !Platform.isMacOS) || !_initialized) return;

    final metadataKey = [
      song?.path ?? audioService.currentMusic?.path,
      audioService.currentMusic?.displayName,
      audioService.currentMusic?.artist,
      audioService.currentMusic?.album,
      audioService.currentMusic?.artworkPath ??
          audioService.currentMusic?.thumbnailPath,
      audioService.duration.inMilliseconds.toString(),
    ].join('|');
    if (_lastMetadataKey == metadataKey) return;
    _lastMetadataKey = metadataKey;
    _hasForwardedTimeline = false;

    _handler.onMetadataChanged();
  }

  bool? _lastIsPlaying;

  void updatePlaybackStatus(bool isPlaying) {
    if ((!Platform.isIOS && !Platform.isMacOS) || !_initialized) return;
    if (_lastIsPlaying == isPlaying) return;
    _lastIsPlaying = isPlaying;
    _lastTimelineForwardedAt = DateTime.now();
    _lastTimelinePosition = audioService.position;

    _handler.onPlaybackStatusChanged(isPlaying);

    if (Platform.isIOS) {
      final player = audioService.playbackController.player;
      if (isPlaying) {
        player.isAudioSessionTransitioning = true;
        AudioSession.instance.then((session) {
          return session.setActive(true);
        }).then((_) {
          player.isAudioSessionTransitioning = false;
        }).catchError((Object error) {
          debugPrint('Failed to update iOS audio session active state: $error');
          player.isAudioSessionTransitioning = false;
        });
      } else {
        // Do not call session.setActive(false) on pause on iOS.
        // The Rust audio engine (cpal) maintains an active AudioUnit stream.
        // Deactivating the session while the stream is active can deadlock the CoreAudio and main threads.
        player.isAudioSessionTransitioning = false;
      }
    }
  }

  void updateTimeline(Duration position, Duration duration) {
    if ((!Platform.isIOS && !Platform.isMacOS) || !_initialized) return;

    final durationChanged = duration != _lastTimelineDuration;
    if (durationChanged) {
      _lastTimelineDuration = duration;
      updateMetadata(null);
    }

    final now = DateTime.now();
    final elapsed = now.difference(_lastTimelineForwardedAt);

    // Apple MPNowPlayingInfoCenter automatically increments elapsed playback time
    // using the system clock and playbackRate = 1.0. Continual high-frequency setState
    // wakes up the isolate and platform channel pointlessly.
    // Forward when:
    // 1. First time for a track or metadata changed
    // 2. Duration changed
    // 3. Track rewind or position jump / seek (drift >= 800ms)
    // 4. Periodic drift recalibration (>= 15 seconds)
    // 5. Position changed while paused
    final expectedPosition = audioService.isPlaying
        ? _lastTimelinePosition + elapsed
        : _lastTimelinePosition;
    final drift = (position - expectedPosition).abs();

    final shouldForward =
        !_hasForwardedTimeline ||
        durationChanged ||
        position == Duration.zero ||
        drift >= const Duration(milliseconds: 800) ||
        elapsed >= const Duration(seconds: 15) ||
        (!audioService.isPlaying &&
            (position - _lastTimelinePosition).abs() >=
                const Duration(milliseconds: 500));

    if (!shouldForward) return;

    _hasForwardedTimeline = true;
    _lastTimelineForwardedAt = now;
    _lastTimelinePosition = position;

    _handler.onPositionChanged(position, duration);
  }
}
