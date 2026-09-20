import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'package:vynody/player/library/library_insights_service.dart';
import '../widgets/library_ranked_song_list.dart';

class RecentlyAddedTab extends ConsumerStatefulWidget {
  final double contentTopPadding;
  final double contentLeftPadding;

  const RecentlyAddedTab({
    super.key,
    this.contentTopPadding = 0.0,
    this.contentLeftPadding = 0.0,
  });

  @override
  ConsumerState<RecentlyAddedTab> createState() => _RecentlyAddedTabState();
}

class _RecentlyAddedTabState extends ConsumerState<RecentlyAddedTab> {
  LibraryTimeRange _selectedRange = LibraryTimeRange.allTime;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncItems = ref.watch(recentlyAddedSongsProvider(_selectedRange));

    return asyncItems.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (items) => LibraryRankedSongList(
        contentTopPadding: widget.contentTopPadding,
        contentLeftPadding: widget.contentLeftPadding,
        title: l10n.recentlyAdded,
        subtitle: l10n.recentlyAddedDescription,
        items: items,
        selectedRange: _selectedRange,
        onRangeChanged: (value) {
          setState(() {
            _selectedRange = value;
          });
        },
        emptyText: _selectedRange == LibraryTimeRange.allTime
            ? l10n.noRecentlyAddedSongs
            : l10n.noRecentlyAddedInRange,
        trailingBuilder: (context, entry) => InsightMetricText(
          primary: formatInsightDate(context, entry.createdAt),
          secondary: l10n.addedOn,
        ),
      ),
    );
  }
}
