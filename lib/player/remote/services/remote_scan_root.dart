import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../proxy/remote_media_resolver.dart';
import '../remote_server_models.dart';

/// Represents a remote directory (SMB or WebDAV) registered into the local media library index.
class RemoteScanRoot {
  final String id;
  final String serverId;
  final RemoteServerType serverType;
  final String serverName;
  final String remotePath;
  final String virtualUri;
  final int addedAt;
  final int? lastScannedAt;
  final int songCount;

  const RemoteScanRoot({
    required this.id,
    required this.serverId,
    required this.serverType,
    required this.serverName,
    required this.remotePath,
    required this.virtualUri,
    required this.addedAt,
    this.lastScannedAt,
    this.songCount = 0,
  });

  static String generateId(String serverId, String remotePath) {
    final cleanPath = normalizeRemotePath(remotePath);
    return '$serverId:$cleanPath';
  }

  static String generateVirtualUri(RemoteServer server, String remotePath) {
    return RemoteMediaResolver.buildRemoteUri(server, remotePath);
  }

  /// Checks if a song's virtual URI is inside this remote root.
  bool containsSong(String songVirtualUri) {
    if (!songVirtualUri.startsWith('$virtualUri/') && songVirtualUri != virtualUri) {
      return false;
    }
    return true;
  }

  RemoteScanRoot copyWith({
    int? lastScannedAt,
    int? songCount,
    String? serverName,
  }) {
    return RemoteScanRoot(
      id: id,
      serverId: serverId,
      serverType: serverType,
      serverName: serverName ?? this.serverName,
      remotePath: remotePath,
      virtualUri: virtualUri,
      addedAt: addedAt,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      songCount: songCount ?? this.songCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'serverId': serverId,
        'serverType': serverType.name,
        'serverName': serverName,
        'remotePath': remotePath,
        'virtualUri': virtualUri,
        'addedAt': addedAt,
        'lastScannedAt': lastScannedAt,
        'songCount': songCount,
      };

  factory RemoteScanRoot.fromJson(Map<String, dynamic> json) => RemoteScanRoot(
        id: json['id'] as String,
        serverId: json['serverId'] as String,
        serverType: RemoteServerType.fromString(json['serverType'] as String?),
        serverName: json['serverName'] as String? ?? 'Remote Server',
        remotePath: json['remotePath'] as String,
        virtualUri: json['virtualUri'] as String,
        addedAt: json['addedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        lastScannedAt: json['lastScannedAt'] as int?,
        songCount: json['songCount'] as int? ?? 0,
      );
}

const String _kRemoteScanRootsKey = 'remote_scan_roots_list';

class RemoteScanRootsNotifier extends AsyncNotifier<List<RemoteScanRoot>> {
  @override
  Future<List<RemoteScanRoot>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRemoteScanRootsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(RemoteScanRoot.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[RemoteScanRootsNotifier] Error decoding remote roots: $e');
      return [];
    }
  }

  Future<void> _persist(List<RemoteScanRoot> roots) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(roots.map((r) => r.toJson()).toList());
    await prefs.setString(_kRemoteScanRootsKey, data);
    state = AsyncData(roots);
  }

  /// Adds a new remote root. If it already exists, does nothing and returns false.
  Future<bool> addRoot(RemoteScanRoot root) async {
    final current = state.asData?.value ?? [];
    if (current.any((r) => r.id == root.id)) {
      return false;
    }
    final updated = [...current, root];
    await _persist(updated);
    return true;
  }

  /// Removes a remote root by ID.
  Future<void> removeRoot(String rootId) async {
    final current = state.asData?.value ?? [];
    final updated = current.where((r) => r.id != rootId).toList();
    await _persist(updated);
  }

  /// Updates an existing root with scanned info (song count, last scanned time).
  Future<void> updateRoot(RemoteScanRoot updatedRoot) async {
    final current = state.asData?.value ?? [];
    final updated = current
        .map((r) => r.id == updatedRoot.id ? updatedRoot : r)
        .toList();
    await _persist(updated);
  }

  /// Checks whether a remote folder is directly or indirectly (by ancestor) indexed.
  bool isFolderIndexed(String serverId, String remotePath) {
    final current = state.asData?.value ?? [];
    final cleanPath = normalizeRemotePath(remotePath);
    for (final root in current) {
      if (root.serverId != serverId) continue;
      final rootClean = normalizeRemotePath(root.remotePath);
      if (cleanPath == rootClean) return true;
      if (cleanPath.startsWith('$rootClean/')) return true;
    }
    return false;
  }

  /// Finds the exact registered root for a serverId and remotePath, if any.
  RemoteScanRoot? findExactRoot(String serverId, String remotePath) {
    final current = state.asData?.value ?? [];
    final id = RemoteScanRoot.generateId(serverId, remotePath);
    return current.where((r) => r.id == id).firstOrNull;
  }
}

final remoteScanRootsProvider =
    AsyncNotifierProvider<RemoteScanRootsNotifier, List<RemoteScanRoot>>(
  RemoteScanRootsNotifier.new,
);
