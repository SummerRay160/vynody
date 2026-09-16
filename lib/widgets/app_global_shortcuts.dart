import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/app_localizations.dart';
import '../main.dart' show navigatorKey;
import '../pages/main_layout_riverpod.dart';
import '../player/audio/audio_riverpod.dart';
import '../player/pro/pro_license_service.dart';
import '../player/pro/pro_models.dart';
import '../player/settings/settings_service.dart';
import '../player/settings/shortcut_bindings.dart';
import '../utils/app_snack_bar.dart';

class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class NextIntent extends Intent {
  const NextIntent();
}

class PreviousIntent extends Intent {
  const PreviousIntent();
}

class VolumeUpIntent extends Intent {
  const VolumeUpIntent();
}

class VolumeDownIntent extends Intent {
  const VolumeDownIntent();
}

class MuteIntent extends Intent {
  const MuteIntent();
}

class SeekForwardIntent extends Intent {
  const SeekForwardIntent();
}

class SeekBackwardIntent extends Intent {
  const SeekBackwardIntent();
}

class ToggleFullScreenIntent extends Intent {
  const ToggleFullScreenIntent();
}

class ToggleWasapiExclusiveIntent extends Intent {
  const ToggleWasapiExclusiveIntent();
}

class ExitFullScreenIntent extends Intent {
  const ExitFullScreenIntent();
}

class ExitFullScreenAction extends Action<ExitFullScreenIntent> {
  final WidgetRef ref;
  ExitFullScreenAction(this.ref);

  @override
  bool isEnabled(Intent intent) {
    return ref.read(isWindowFullScreenProvider);
  }

  @override
  Object? invoke(ExitFullScreenIntent intent) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.setFullScreen(false);
      ref.read(isWindowFullScreenProvider.notifier).state = false;
    }
    return null;
  }
}

class AppShortcutManager extends ShortcutManager {
  @override
  KeyEventResult handleKeypress(BuildContext context, KeyEvent event) {
    if (_isTextInputFocused()) {
      return KeyEventResult.ignored;
    }
    // 当存在模态弹窗或可回退的路由时，忽略 ESC，优先让弹窗/页面回退关闭
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      final nav = navigatorKey.currentState;
      if (nav != null && nav.canPop()) {
        return KeyEventResult.ignored;
      }
    }
    return super.handleKeypress(context, event);
  }

  bool _isTextInputFocused() {
    final focusNode = FocusManager.instance.primaryFocus;
    if (focusNode == null) return false;

    final context = focusNode.context;
    if (context == null) return false;

    final widget = context.widget;
    if (widget is EditableText ||
        widget is TextField ||
        widget is TextFormField) {
      return true;
    }
    return context.findAncestorWidgetOfExactType<EditableText>() != null ||
        context.findAncestorWidgetOfExactType<TextField>() != null ||
        context.findAncestorWidgetOfExactType<TextFormField>() != null;
  }
}

Map<ShortcutActivator, Intent> buildAppShortcutMap(SettingsService settings) {
  final bindings = <AppShortcutAction, Intent>{
    AppShortcutAction.playPause: const PlayPauseIntent(),
    AppShortcutAction.next: const NextIntent(),
    AppShortcutAction.previous: const PreviousIntent(),
    AppShortcutAction.volumeUp: const VolumeUpIntent(),
    AppShortcutAction.volumeDown: const VolumeDownIntent(),
    AppShortcutAction.mute: const MuteIntent(),
    AppShortcutAction.seekForward: const SeekForwardIntent(),
    AppShortcutAction.seekBackward: const SeekBackwardIntent(),
    AppShortcutAction.toggleFullScreen: const ToggleFullScreenIntent(),
    AppShortcutAction.toggleWasapiExclusive:
        const ToggleWasapiExclusiveIntent(),
  };

  final shortcuts = <ShortcutActivator, Intent>{};
  for (final entry in bindings.entries) {
    final activator = settings.shortcutBinding(entry.key).toActivator();
    if (activator == null) {
      continue;
    }
    shortcuts[activator] = entry.value;
  }
  shortcuts[const SingleActivator(LogicalKeyboardKey.escape)] =
      const ExitFullScreenIntent();
  return shortcuts;
}

class AppGlobalShortcuts extends ConsumerStatefulWidget {
  const AppGlobalShortcuts({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppGlobalShortcuts> createState() => _AppGlobalShortcutsState();
}

class _AppGlobalShortcutsState extends ConsumerState<AppGlobalShortcuts> {
  late final AppShortcutManager _shortcutManager;

  @override
  void initState() {
    super.initState();
    _shortcutManager = AppShortcutManager();
  }

  @override
  void dispose() {
    _shortcutManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsServiceProvider);
    _shortcutManager.shortcuts = buildAppShortcutMap(settings);

    return Shortcuts.manager(
      manager: _shortcutManager,
      child: Actions(
        actions: <Type, Action<Intent>>{
          PlayPauseIntent: CallbackAction<PlayPauseIntent>(
            onInvoke: (_) => ref.read(audioServiceProvider).togglePlay(),
          ),
          NextIntent: CallbackAction<NextIntent>(
            onInvoke: (_) => ref.read(audioServiceProvider).next(),
          ),
          PreviousIntent: CallbackAction<PreviousIntent>(
            onInvoke: (_) => ref.read(audioServiceProvider).previous(),
          ),
          VolumeUpIntent: CallbackAction<VolumeUpIntent>(
            onInvoke: (_) {
              ref
                  .read(mainLayoutUiControllerProvider.notifier)
                  .setVolumeHudVisible(true);
              final audio = ref.read(audioServiceProvider);
              audio.setVolume((audio.volume + 5).roundToDouble());
              return null;
            },
          ),
          VolumeDownIntent: CallbackAction<VolumeDownIntent>(
            onInvoke: (_) {
              ref
                  .read(mainLayoutUiControllerProvider.notifier)
                  .setVolumeHudVisible(true);
              final audio = ref.read(audioServiceProvider);
              audio.setVolume((audio.volume - 5).roundToDouble());
              return null;
            },
          ),
          MuteIntent: CallbackAction<MuteIntent>(
            onInvoke: (_) {
              ref.read(audioServiceProvider).toggleMute();
              return null;
            },
          ),
          SeekForwardIntent: CallbackAction<SeekForwardIntent>(
            onInvoke: (_) => ref
                .read(audioServiceProvider)
                .seekRelative(const Duration(seconds: 5)),
          ),
          SeekBackwardIntent: CallbackAction<SeekBackwardIntent>(
            onInvoke: (_) => ref
                .read(audioServiceProvider)
                .seekRelative(const Duration(seconds: -5)),
          ),
          ToggleFullScreenIntent: CallbackAction<ToggleFullScreenIntent>(
            onInvoke: (_) async {
              if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
                final isFullScreen = await windowManager.isFullScreen();
                final next = !isFullScreen;
                await windowManager.setFullScreen(next);
                ref.read(isWindowFullScreenProvider.notifier).state = next;
              }
              return null;
            },
          ),
          ExitFullScreenIntent: ExitFullScreenAction(ref),
          ToggleWasapiExclusiveIntent:
              CallbackAction<ToggleWasapiExclusiveIntent>(
            onInvoke: (_) async {
              if (!Platform.isWindows) return null;
              final settings = ref.read(settingsServiceProvider);
              if (!settings.hasUsedWasapiExclusive) {
                return null;
              }

              final isProUnlocked = ref.read(isProUnlockedProvider);
              final isCurrentlyExclusive =
                  settings.windowsAudioOutputMode == 'wasapi_exclusive' &&
                      isProUnlocked;
              final audio = ref.read(audioServiceProvider);
              final activeContext = navigatorKey.currentContext ?? context;

              if (!isCurrentlyExclusive) {
                if (!isProUnlocked) {
                  if (activeContext.mounted) {
                    final allowed = await checkProGate(
                      activeContext,
                      ref,
                      feature: ProFeature.wasapiExclusive,
                    );
                    if (!allowed) return null;
                  } else {
                    return null;
                  }
                }
                await audio.updateWindowsAudioOutput(
                  mode: 'wasapi_exclusive',
                );
                if (activeContext.mounted) {
                  AppSnackBar.show(
                    activeContext,
                    ref,
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(activeContext)!
                            .wasapiExclusiveEnabledNotice,
                      ),
                    ),
                  );
                }
              } else {
                await audio.updateWindowsAudioOutput(mode: 'shared');
                if (activeContext.mounted) {
                  AppSnackBar.show(
                    activeContext,
                    ref,
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(activeContext)!
                            .audioSharedModeEnabledNotice,
                      ),
                    ),
                  );
                }
              }
              return null;
            },
          ),
        },
        child: widget.child,
      ),
    );
  }
}
