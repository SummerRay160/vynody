import 'package:flutter/material.dart';
import 'package:vynody/models/album_summary.dart';
import 'package:vynody/widgets/song_thumbnail.dart';

/// A reusable album cover artwork widget.
///
/// Encapsulates [SongThumbnail.fromAlbum], default rounded corners,
/// and optional [Hero] animation tagging.
class AlbumCover extends StatelessWidget {
  const AlbumCover({
    super.key,
    required this.album,
    this.size = 120.0,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.enableHero = false,
    this.heroTag,
  });

  /// The album data.
  final AlbumSummary album;

  /// Square dimensions if [width] and [height] are omitted.
  final double size;

  /// Custom width override.
  final double? width;

  /// Custom height override.
  final double? height;

  /// Corner radius of the album cover.
  final BorderRadius? borderRadius;

  /// Whether to wrap this cover in a [Hero] widget for page transitions.
  final bool enableHero;

  /// Custom hero tag. Defaults to `'album-cover-${album.id}'` when [enableHero] is true.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    Widget cover = SongThumbnail.fromAlbum(
      album,
      size: size,
      width: width,
      height: height,
      borderRadius: borderRadius,
    );

    if (enableHero) {
      final tag = heroTag ?? 'album-cover-${album.id}';
      cover = Hero(
        tag: tag,
        child: cover,
      );
    }

    return cover;
  }
}
