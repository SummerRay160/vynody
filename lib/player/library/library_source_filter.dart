import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../remote/proxy/remote_media_resolver.dart';
import '../remote/remote_server_models.dart';
import '../remote/services/remote_scan_root.dart';

enum LibrarySourceType {
  all,
  local,
  remote,
}

class LibrarySourceFilter {
  final LibrarySourceType type;
  final String? serverId;
  final String? serverName;
  final RemoteServerType? serverType;

  const LibrarySourceFilter({
    this.type = LibrarySourceType.all,
    this.serverId,
    this.serverName,
    this.serverType,
  });

  static const all = LibrarySourceFilter(type: LibrarySourceType.all);
  static const local = LibrarySourceFilter(type: LibrarySourceType.local);

  factory LibrarySourceFilter.remote({
    required String serverId,
    required String serverName,
    required RemoteServerType serverType,
  }) {
    return LibrarySourceFilter(
      type: LibrarySourceType.remote,
      serverId: serverId,
      serverName: serverName,
      serverType: serverType,
    );
  }

  bool matchesSongPath(String path) {
    if (type == LibrarySourceType.all) return true;
    final isRemote = RemoteMediaResolver.isRemoteUri(path);
    if (type == LibrarySourceType.local) {
      return !isRemote;
    }
    if (type == LibrarySourceType.remote) {
      if (!isRemote) return false;
      final info = RemoteMediaResolver.parseUri(path);
      if (info != null) {
        return info.serverId == serverId;
      }
      final uri = Uri.tryParse(path);
      return uri?.host == serverId;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibrarySourceFilter &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          serverId == other.serverId;

  @override
  int get hashCode => type.hashCode ^ (serverId?.hashCode ?? 0);
}

class LibrarySourceFilterNotifier extends Notifier<LibrarySourceFilter> {
  @override
  LibrarySourceFilter build() => LibrarySourceFilter.all;

  void setFilter(LibrarySourceFilter filter) {
    state = filter;
  }

  void reset() {
    state = LibrarySourceFilter.all;
  }
}

final librarySourceFilterProvider =
    NotifierProvider<LibrarySourceFilterNotifier, LibrarySourceFilter>(
  LibrarySourceFilterNotifier.new,
);

class RemoteServerSummary {
  final String serverId;
  final String serverName;
  final RemoteServerType serverType;
  final int totalSongs;
  final List<RemoteScanRoot> roots;

  const RemoteServerSummary({
    required this.serverId,
    required this.serverName,
    required this.serverType,
    required this.totalSongs,
    required this.roots,
  });
}

/// Aggregates registered remote scan roots by server
final remoteIndexedServersProvider = Provider<List<RemoteServerSummary>>((ref) {
  final roots = ref.watch(remoteScanRootsProvider).asData?.value ?? [];
  final map = <String, List<RemoteScanRoot>>{};

  for (final root in roots) {
    map.putIfAbsent(root.serverId, () => []).add(root);
  }

  return map.entries.map((entry) {
    final serverRoots = entry.value;
    final first = serverRoots.first;
    final totalSongs = serverRoots.fold<int>(0, (sum, r) => sum + r.songCount);
    return RemoteServerSummary(
      serverId: entry.key,
      serverName: first.serverName,
      serverType: first.serverType,
      totalSongs: totalSongs,
      roots: serverRoots,
    );
  }).toList();
});
