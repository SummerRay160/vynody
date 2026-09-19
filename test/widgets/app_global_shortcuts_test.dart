import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vynody/main.dart' show navigatorKey;
import 'package:vynody/player/audio/audio_riverpod.dart';
import 'package:vynody/player/audio/audio_service.dart';
import 'package:vynody/player/settings/settings_service.dart';
import 'package:vynody/player/settings/shortcut_bindings.dart';
import 'package:vynody/widgets/app_global_shortcuts.dart';

class _FakeAudioService extends AudioService {
  bool togglePlayCalled = false;

  @override
  Future<void> togglePlay() async {
    togglePlayCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppGlobalShortcuts', () {
    late SettingsService settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      settings = SettingsService(prefs);
    });

    test('buildAppShortcutMap creates mappings for all default actions and escape', () {
      final map = buildAppShortcutMap(settings);
      expect(map.isNotEmpty, isTrue);

      // Space -> PlayPauseIntent
      expect(map.values.whereType<PlayPauseIntent>().isNotEmpty, isTrue);

      // Escape -> ExitFullScreenIntent
      expect(map.values.whereType<ExitFullScreenIntent>().isNotEmpty, isTrue);
    });

    test('Space key displays as Space instead of 0x20', () {
      final spaceBinding = AppShortcutAction.playPause.defaultBinding;
      expect(spaceBinding.displayLabel, 'Space');
    });

    testWidgets('AppGlobalShortcuts wraps child with Shortcuts and Actions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsServiceProvider.overrideWith((ref) => settings),
            audioServiceProvider.overrideWith((ref) => _FakeAudioService()),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const AppGlobalShortcuts(
              child: Scaffold(
                body: Text('Test Child'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test Child'), findsOneWidget);
      expect(find.byType(Shortcuts), findsWidgets);
      expect(find.byType(Actions), findsWidgets);
    });

    testWidgets('Shortcuts bubble up from within pushed Dialog/ModalRoute', (tester) async {
      final fakeAudio = _FakeAudioService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsServiceProvider.overrideWith((ref) => settings),
            audioServiceProvider.overrideWith((ref) => fakeAudio),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) {
              return AppGlobalShortcuts(
                child: child!,
              );
            },
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    showGeneralDialog(
                      context: context,
                      pageBuilder: (dialogCtx, _, _) {
                        return const Center(
                          child: Material(
                            child: Text('Dialog Content'),
                          ),
                        );
                      },
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Dialog Content'), findsOneWidget);
      expect(fakeAudio.togglePlayCalled, isFalse);

      // Simulate Space key press while Dialog is open
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      // Action should be successfully triggered from inside Dialog
      expect(fakeAudio.togglePlayCalled, isTrue);
    });

    testWidgets('ESC closes Dialog when Dialog is open', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsServiceProvider.overrideWith((ref) => settings),
            audioServiceProvider.overrideWith((ref) => _FakeAudioService()),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) {
              return AppGlobalShortcuts(
                child: child!,
              );
            },
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => const AlertDialog(
                        title: Text('Test Dialog'),
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Test Dialog'), findsOneWidget);

      // Press ESC
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Test Dialog'), findsNothing);
    });
  });
}
