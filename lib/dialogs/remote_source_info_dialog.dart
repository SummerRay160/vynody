import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:oktoast/oktoast.dart';
import '../l10n/app_localizations.dart';
import '../models/music_file.dart';
import '../player/remote/proxy/remote_media_resolver.dart';
import '../player/remote/remote_server_models.dart';
import '../player/remote/remote_server_riverpod.dart';
import '../utils/app_snack_bar.dart';

/// Shows a dialog displaying detailed remote media source information
/// (channel type, server name, remote folder path, and file name).
Future<void> showRemoteSourceInfoDialog(
  BuildContext context, {
  MusicFile? song,
  List<MusicFile>? songs,
  String? title,
}) async {
  final targetSongs = (song != null ? [song] : (songs ?? const <MusicFile>[]))
      .where((s) => RemoteMediaResolver.isRemoteUri(s.path))
      .toList();

  if (targetSongs.isEmpty) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _RemoteSourceInfoDialog(
      songs: targetSongs,
      itemTitle: title,
    ),
  );
}

class _RemoteSourceInfoDialog extends ConsumerWidget {
  const _RemoteSourceInfoDialog({
    required this.songs,
    this.itemTitle,
  });

  final List<MusicFile> songs;
  final String? itemTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final servers = ref.watch(remoteServersProvider).asData?.value ?? [];

    final firstSong = songs.first;
    final remoteInfo = RemoteMediaResolver.parseUri(firstSong.path);
    final server = remoteInfo != null
        ? servers.firstWhereOrNull((s) => s.id == remoteInfo.serverId)
        : null;

    final channelType = remoteInfo?.type.displayName ??
        server?.type.displayName ??
        (firstSong.path.startsWith('webdav://')
            ? 'WebDAV'
            : (firstSong.path.startsWith('smb://') ? 'Samba / SMB' : 'Remote'));

    final serverName = server?.name ??
        (remoteInfo != null ? 'Server (${remoteInfo.serverId})' : channelType);

    final serverAddress = server?.url;

    String? folderPath;
    String? fileName;
    if (remoteInfo != null && remoteInfo.trackIdOrPath.isNotEmpty) {
      folderPath = p.posix.dirname(remoteInfo.trackIdOrPath);
      fileName = p.posix.basename(remoteInfo.trackIdOrPath);
      if (folderPath.isEmpty || folderPath == '.') {
        folderPath = '/';
      }
    }

    final isSingleSong = songs.length == 1;
    final copyTarget = folderPath ?? firstSong.path;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.cloud_rounded,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.remoteSourceTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (itemTitle != null && itemTitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    itemTitle!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Server / Channel card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.dns_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.remoteServer,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          channelType,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    serverName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (serverAddress != null && serverAddress.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      serverAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Folder & Location Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 18,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.remoteFolder,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!isSingleSong) ...[
                        const Spacer(),
                        Text(
                          l10n.songCount(songs.length),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (folderPath != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      child: SelectableText(
                        folderPath,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                  if (isSingleSong && fileName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: copyTarget));
            showToast(l10n.pathCopied);
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: Text(l10n.copyPath),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
