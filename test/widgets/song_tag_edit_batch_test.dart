import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:vynody/dialogs/song_tag_edit_dialog.dart';
import 'package:vynody/l10n/app_localizations.dart';
import 'package:vynody/models/music_file.dart';

void main() {
  testWidgets('SongTagEditSheet displays <keep> for differing fields in batch mode', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const song1 = MusicFile(
      path: '/local/music/song1.mp3',
      name: 'song1.mp3',
      title: 'Song One',
      artist: 'Artist A',
      albumArtist: 'Shared Album Artist',
      album: 'Shared Album',
      trackNumber: 1,
      durationMillis: 180000,
    );

    const song2 = MusicFile(
      path: '/local/music/song2.mp3',
      name: 'song2.mp3',
      title: 'Song Two',
      artist: 'Artist B',
      albumArtist: 'Shared Album Artist',
      album: 'Shared Album',
      trackNumber: 2,
      durationMillis: 200000,
    );

    await tester.pumpWidget(
      const OKToast(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: Scaffold(
            body: SizedBox(
              height: 1200,
              width: 600,
              child: SongTagEditSheet(songs: [song1, song2]),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Differing fields should show <keep>
    expect(find.text('<keep>'), findsNWidgets(3)); // title, artist, trackNumber

    // Common fields should show the shared text
    expect(find.text('Shared Album Artist'), findsOneWidget);
    expect(find.text('Shared Album'), findsOneWidget);

    // Header should mention batch edit count
    expect(find.textContaining('批量编辑歌曲标签 (2)'), findsOneWidget);
  });
}
