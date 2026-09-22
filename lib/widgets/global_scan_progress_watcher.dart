import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import '../pages/main_layout_riverpod.dart';
import '../player/audio/audio_riverpod.dart';
import '../player/remote/services/remote_directory_scanner.dart';
import '../player/scanner/scanner_service.dart';
import '../utils/app_snack_bar.dart';
import 'scan_progress_toast.dart';

class GlobalScanProgressWatcher extends ConsumerStatefulWidget {
  final Widget child;

  const GlobalScanProgressWatcher({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<GlobalScanProgressWatcher> createState() =>
      _GlobalScanProgressWatcherState();
}

class _GlobalScanProgressWatcherState
    extends ConsumerState<GlobalScanProgressWatcher> {
  StreamSubscription<ScanProgress>? _localScanProgressSubscription;
  ToastFuture? _scanToast;
  final ValueNotifier<ScanToastState?> _scanToastState =
      ValueNotifier<ScanToastState?>(null);

  Timer? _updateTimer;
  Timer? _autoDismissTimer;

  ScanProgress? _pendingLocalProgress;
  RemoteScanProgress? _pendingRemoteProgress;
  DateTime? _lastUpdateAt;

  String _currentToastLabel = '';
  bool _wasLocalScanning = false;
  bool _wasRemoteScanning = false;
  ScannerService? _localScanner;

  @override
  void initState() {
    super.initState();
    final localScanner = ref.read(scannerServiceProvider);
    _localScanner = localScanner;
    _wasLocalScanning = localScanner.isScanning;
    localScanner.addListener(_handleLocalScannerChanged);
    _localScanProgressSubscription =
        localScanner.scanProgressStream.listen(_handleLocalScanProgress);
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _autoDismissTimer?.cancel();
    _localScanProgressSubscription?.cancel();
    _localScanner?.removeListener(_handleLocalScannerChanged);
    _localScanner = null;
    _dismissScanToast(notifyListeners: false);
    _scanToastState.dispose();
    super.dispose();
  }

  bool _isToastBlocked(WidgetRef ref) {
    final isSettingsActive = ref.read(isSettingsPageActiveProvider);
    final currentTabIndex = ref.read(mainTabIndexProvider);
    return isSettingsActive || currentTabIndex == 1; // Tab 1 is playback page
  }

  bool _isAnyScanning() {
    final isLocalScanning = ref.read(scannerServiceProvider).isScanning;
    final isRemoteScanning = ref.read(remoteScanProgressProvider).isScanning;
    return isLocalScanning || isRemoteScanning;
  }

  void _handleLocalScannerChanged() {
    final localScanner = ref.read(scannerServiceProvider);
    final isScanning = localScanner.isScanning;
    if (_wasLocalScanning && !isScanning && !_isAnyScanning()) {
      _scheduleAutoDismiss();
    }
    _wasLocalScanning = isScanning;
  }

  void _handleLocalScanProgress(ScanProgress progress) {
    if (!mounted) return;
    if (!ref.read(settingsServiceProvider).showScanProgressToast) return;
    if (_isToastBlocked(ref)) return;

    _pendingLocalProgress = progress;
    _scheduleFlush();
  }

  void _handleRemoteScanProgress(
    RemoteScanProgress? previous,
    RemoteScanProgress next,
  ) {
    if (!mounted) return;
    final isScanning = next.isScanning;
    if (_wasRemoteScanning && !isScanning && !_isAnyScanning()) {
      _scheduleAutoDismiss();
    }
    _wasRemoteScanning = isScanning;

    if (!isScanning) return;
    if (!ref.read(settingsServiceProvider).showScanProgressToast) return;
    if (_isToastBlocked(ref)) return;

    _pendingRemoteProgress = next;
    _scheduleFlush();
  }

  void _scheduleFlush() {
    final now = DateTime.now();
    final lastUpdate = _lastUpdateAt;
    final elapsed = lastUpdate == null ? null : now.difference(lastUpdate);

    if (_updateTimer?.isActive ?? false) {
      return;
    }

    if (elapsed == null || elapsed >= const Duration(milliseconds: 600)) {
      _flushPendingProgress();
      return;
    }

    _updateTimer = Timer(const Duration(milliseconds: 600) - elapsed, () {
      _updateTimer = null;
      if (!mounted) return;
      _flushPendingProgress();
    });
  }

  void _flushPendingProgress() {
    if (_isToastBlocked(ref)) {
      _dismissScanToast();
      return;
    }

    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    // Prioritize remote progress if active, or local progress
    if (_pendingRemoteProgress != null &&
        ref.read(remoteScanProgressProvider).isScanning) {
      final remote = _pendingRemoteProgress!;
      _pendingRemoteProgress = null;

      final serverName = remote.serverName;
      final label = (serverName != null && serverName.isNotEmpty)
          ? '${l10n.scanningDirectory} ($serverName)'
          : l10n.scanningDirectory;

      final currentFile = remote.currentFile ?? remote.currentFolder ?? '';
      final fileName = currentFile.isNotEmpty ? p.basename(currentFile) : '';

      _ensureScanToastVisible(label);
      _scanToastState.value = ScanToastState(
        fileName: fileName,
        discoveredLabelText: l10n.filesDiscovered(remote.totalDiscovered),
        preprocessedLabelText: '',
        completedLabelText: l10n.filesFullyProcessed(remote.processedCount),
      );
      _lastUpdateAt = DateTime.now();
      _scheduleAutoDismiss();
      return;
    }

    if (_pendingLocalProgress != null &&
        ref.read(scannerServiceProvider).isScanning) {
      final progress = _pendingLocalProgress!;
      _pendingLocalProgress = null;

      _ensureScanToastVisible(l10n.scanningDirectory);
      _scanToastState.value = ScanToastState(
        fileName: p.basename(progress.filePath),
        discoveredLabelText: l10n.filesDiscovered(progress.discoveredCount),
        preprocessedLabelText: l10n.filesPreprocessed(progress.preprocessedCount),
        completedLabelText: l10n.filesFullyProcessed(progress.completedCount),
      );
      _lastUpdateAt = DateTime.now();
      _scheduleAutoDismiss();
    }
  }

  void _ensureScanToastVisible(String label) {
    if (!ref.read(settingsServiceProvider).showScanProgressToast) return;
    if (_isToastBlocked(ref)) return;

    if (_scanToast?.mounted == true && _currentToastLabel == label) return;

    _currentToastLabel = label;
    _scanToast?.dismiss(showAnim: false);

    _scanToastState.value ??= const ScanToastState(
      fileName: '',
      discoveredLabelText: '',
      preprocessedLabelText: '',
      completedLabelText: '',
    );

    _scanToast = showToastWidget(
      ScanProgressToast(
        stateListenable: _scanToastState,
        label: label,
        onClose: () {
          _dismissScanToast();
          ref.read(settingsServiceProvider).showScanProgressToast = false;
          final currentL10n = AppLocalizations.of(context);
          if (currentL10n != null) {
            AppSnackBar.show(
              context,
              ref,
              SnackBar(content: Text(currentL10n.scanToastHiddenHint)),
            );
          }
        },
      ),
      position: ToastPosition.top.copyWith(offset: 28),
      duration: const Duration(days: 1),
      dismissOtherToast: true,
      animationDuration: const Duration(milliseconds: 180),
      handleTouch: true,
    );
  }

  void _dismissScanToast({bool notifyListeners = true}) {
    _updateTimer?.cancel();
    _updateTimer = null;
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    _pendingLocalProgress = null;
    _pendingRemoteProgress = null;
    _lastUpdateAt = null;
    _currentToastLabel = '';
    _scanToast?.dismiss(showAnim: false);
    _scanToast = null;
    if (notifyListeners) {
      _scanToastState.value = null;
    }
  }

  void _scheduleAutoDismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 2), () {
      _autoDismissTimer = null;
      if (!mounted) return;

      if (_isAnyScanning()) {
        _scheduleAutoDismiss();
        return;
      }

      _dismissScanToast();
    });
  }

  void _onNavigationOrSettingsChanged() {
    if (_isToastBlocked(ref)) {
      _dismissScanToast();
    } else {
      // Resumed to a visible page; if scanning is active, re-show
      if (_isAnyScanning()) {
        final remote = ref.read(remoteScanProgressProvider);
        if (remote.isScanning) {
          _pendingRemoteProgress = remote;
        }
        _flushPendingProgress();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RemoteScanProgress>(
      remoteScanProgressProvider,
      _handleRemoteScanProgress,
    );

    ref.listen<int>(
      mainTabIndexProvider,
      (prev, next) => _onNavigationOrSettingsChanged(),
    );

    ref.listen<bool>(
      isSettingsPageActiveProvider,
      (prev, next) => _onNavigationOrSettingsChanged(),
    );

    return widget.child;
  }
}
