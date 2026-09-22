import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../audio/audio_riverpod.dart';
import '../../metadata/metadata_database.dart';
import '../clients/smb_client.dart';
import '../clients/webdav_client.dart';
import '../proxy/remote_media_resolver.dart';
import '../remote_server_models.dart';
import 'remote_scan_root.dart';
import 'webdav_metadata_helper.dart';

/// Progress state of a remote scan operation.
class RemoteScanProgress {
  final bool isScanning;
  final String? rootId;
  final String? serverName;
  final String? currentFolder;
  final String? currentFile;
  final int totalDiscovered;
  final int processedCount;
  final String? errorMessage;

  const RemoteScanProgress({
    this.isScanning = false,
    this.rootId,
    this.serverName,
    this.currentFolder,
    this.currentFile,
    this.totalDiscovered = 0,
    this.processedCount = 0,
    this.errorMessage,
  });

  RemoteScanProgress copyWith({
    bool? isScanning,
    String? rootId,
    String? serverName,
    String? currentFolder,
    String? currentFile,
    int? totalDiscovered,
    int? processedCount,
    String? errorMessage,
  }) {
    return RemoteScanProgress(
      isScanning: isScanning ?? this.isScanning,
      rootId: rootId ?? this.rootId,
      serverName: serverName ?? this.serverName,
      currentFolder: currentFolder ?? this.currentFolder,
      currentFile: currentFile ?? this.currentFile,
      totalDiscovered: totalDiscovered ?? this.totalDiscovered,
      processedCount: processedCount ?? this.processedCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class RemoteScanProgressNotifier extends Notifier<RemoteScanProgress> {
  @override
  RemoteScanProgress build() => const RemoteScanProgress();

  void update(RemoteScanProgress progress) => state = progress;

  void reset() => state = const RemoteScanProgress();
}

final remoteScanProgressProvider =
    NotifierProvider<RemoteScanProgressNotifier, RemoteScanProgress>(
  RemoteScanProgressNotifier.new,
);

class RemoteDirectoryScanner {
  final Ref _ref;
  final MetadataDatabase _db = MetadataDatabase();
  bool _cancelled = false;

  RemoteDirectoryScanner(this._ref);

  void cancel() {
    _cancelled = true;
  }

  /// Scans a single [RemoteScanRoot], indexes all audio files, extracts metadata and updates DB.
  Future<int> scanRoot({
    required RemoteServer server,
    required String password,
    required RemoteScanRoot root,
    void Function(RemoteScanProgress)? onProgress,
  }) async {
    _cancelled = false;
    final progressNotifier = _ref.read(remoteScanProgressProvider.notifier);

    void reportProgress(RemoteScanProgress progress) {
      progressNotifier.update(progress);
      onProgress?.call(progress);
    }

    reportProgress(RemoteScanProgress(
      isScanning: true,
      rootId: root.id,
      serverName: server.name,
      currentFolder: root.remotePath,
      currentFile: root.remotePath,
      totalDiscovered: 0,
      processedCount: 0,
    ));

    final RemoteDirectoryClient client = server.type == RemoteServerType.smb
        ? SmbClient(server: server, password: password)
        : WebDavClient(server: server, password: password);

    try {
      // 1. Recursively find all audio files in the remote folder
      final List<WebDavFile> discoveredAudios = [];
      final List<String> dirQueue = [normalizeRemotePath(root.remotePath)];
      final Set<String> visitedDirs = {};

      while (dirQueue.isNotEmpty && !_cancelled) {
        final currentDir = dirQueue.removeAt(0);
        if (!visitedDirs.add(currentDir)) continue;

        reportProgress(RemoteScanProgress(
          isScanning: true,
          rootId: root.id,
          serverName: server.name,
          currentFolder: currentDir,
          currentFile: currentDir,
          totalDiscovered: discoveredAudios.length,
          processedCount: 0,
        ));

        try {
          final items = await client.listFiles(currentDir);
          for (final item in items) {
            if (item.isDirectory) {
              dirQueue.add(item.path);
            } else if (item.isAudio) {
              discoveredAudios.add(item);
              reportProgress(RemoteScanProgress(
                isScanning: true,
                rootId: root.id,
                serverName: server.name,
                currentFolder: currentDir,
                currentFile: item.name,
                totalDiscovered: discoveredAudios.length,
                processedCount: 0,
              ));
            }
          }
        } catch (e) {
          debugPrint('[RemoteScanner] Error listing directory $currentDir: $e');
        }
      }

      if (_cancelled) {
        reportProgress(const RemoteScanProgress());
        return 0;
      }

      // 2. Fetch existing songs under this root from the local database
      final existingSongs = await _db.getSongsUnderPath(root.virtualUri);
      final Map<String, SongMetadata> existingByUri = {
        for (final s in existingSongs) s.path: s,
      };

      // 3. Compare timestamps to determine which need Range tag extraction
      final List<WebDavFile> filesToExtract = [];
      final Set<String> discoveredUris = {};

      for (final file in discoveredAudios) {
        final virtualUri = RemoteMediaResolver.buildRemoteUri(server, file.path);
        discoveredUris.add(virtualUri);

        final existing = existingByUri[virtualUri];
        final fileModified = file.lastModified?.millisecondsSinceEpoch ?? 0;

        if (existing == null ||
            existing.lastModifiedTime != fileModified ||
            existing.title == 'Unknown' ||
            existing.title.isEmpty) {
          filesToExtract.add(file);
        }
      }

      // 4. Concurrently process files needing metadata extraction
      int processed = discoveredAudios.length - filesToExtract.length;
      reportProgress(RemoteScanProgress(
        isScanning: true,
        rootId: root.id,
        serverName: server.name,
        currentFolder: root.remotePath,
        currentFile: filesToExtract.isNotEmpty ? filesToExtract.first.name : null,
        totalDiscovered: discoveredAudios.length,
        processedCount: processed,
      ));

      if (filesToExtract.isNotEmpty) {
        await RemoteMetadataHelper.processBatchMetadata(
          files: filesToExtract,
          server: server,
          password: password,
          concurrency: 3,
          isCancelled: () => _cancelled,
          onFileStart: (file) {
            reportProgress(RemoteScanProgress(
              isScanning: true,
              rootId: root.id,
              serverName: server.name,
              currentFolder: root.remotePath,
              currentFile: file.name,
              totalDiscovered: discoveredAudios.length,
              processedCount: processed,
            ));
          },
          onMetadataLoaded: (uri, meta, file) {
            processed++;
            reportProgress(RemoteScanProgress(
              isScanning: true,
              rootId: root.id,
              serverName: server.name,
              currentFolder: root.remotePath,
              currentFile: file.name,
              totalDiscovered: discoveredAudios.length,
              processedCount: processed,
            ));
          },
        );
      }

      if (_cancelled) {
        reportProgress(const RemoteScanProgress());
        return 0;
      }

      // 5. Remove any local DB records under this root that no longer exist on the remote server
      final List<String> urisToDelete = [];
      for (final oldUri in existingByUri.keys) {
        if (!discoveredUris.contains(oldUri)) {
          urisToDelete.add(oldUri);
        }
      }
      for (final deleteUri in urisToDelete) {
        await _db.deleteSongByPath(deleteUri);
      }

      // 6. Update RemoteScanRoot info
      final totalIndexed = discoveredUris.length;
      final updatedRoot = root.copyWith(
        songCount: totalIndexed,
        lastScannedAt: DateTime.now().millisecondsSinceEpoch,
        serverName: server.name,
      );
      await _ref.read(remoteScanRootsProvider.notifier).updateRoot(updatedRoot);
      final currentRoots = _ref.read(remoteScanRootsProvider).asData?.value ?? [];
      _ref.read(scannerServiceProvider).setRemoteRoots(currentRoots);

      reportProgress(const RemoteScanProgress());
      return totalIndexed;
    } catch (e, st) {
      debugPrint('[RemoteScanner] Scan root failed: $e\n$st');
      reportProgress(RemoteScanProgress(
        isScanning: false,
        rootId: root.id,
        errorMessage: e.toString(),
      ));
      return 0;
    }
  }

  /// Removes all song metadata and thumbnail records belonging to [root] from the database.
  Future<void> removeRootFromDatabase(RemoteScanRoot root) async {
    final songs = await _db.getSongsUnderPath(root.virtualUri);
    for (final song in songs) {
      await _db.deleteSongByPath(song.path);
    }
    await _ref.read(remoteScanRootsProvider.notifier).removeRoot(root.id);
    final currentRoots = _ref.read(remoteScanRootsProvider).asData?.value ?? [];
    _ref.read(scannerServiceProvider).setRemoteRoots(currentRoots);
  }
}

final remoteDirectoryScannerProvider = Provider<RemoteDirectoryScanner>((ref) {
  return RemoteDirectoryScanner(ref);
});
