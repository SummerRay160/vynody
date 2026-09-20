import 'package:flutter_test/flutter_test.dart';
import 'package:vynody/l10n/app_localizations.dart';

void main() {
  test('All supported locales provide non-empty values for newly added font & model keys', () async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(l10n.selectLyricsFont, isNotEmpty, reason: '${locale.languageCode}: selectLyricsFont');
      expect(l10n.systemFonts, isNotEmpty, reason: '${locale.languageCode}: systemFonts');
      expect(l10n.recommendedFonts, isNotEmpty, reason: '${locale.languageCode}: recommendedFonts');
      expect(l10n.cjkFonts, isNotEmpty, reason: '${locale.languageCode}: cjkFonts');
      expect(l10n.latinFonts, isNotEmpty, reason: '${locale.languageCode}: latinFonts');
      expect(l10n.allFonts, isNotEmpty, reason: '${locale.languageCode}: allFonts');
      expect(l10n.searchFontHint, isNotEmpty, reason: '${locale.languageCode}: searchFontHint');
      expect(l10n.lyricsFontPreview, isNotEmpty, reason: '${locale.languageCode}: lyricsFontPreview');
      expect(l10n.defaultFontOption, isNotEmpty, reason: '${locale.languageCode}: defaultFontOption');
      expect(l10n.importFontFile, isNotEmpty, reason: '${locale.languageCode}: importFontFile');
      expect(l10n.importedFonts, isNotEmpty, reason: '${locale.languageCode}: importedFonts');
      expect(l10n.noImportedFontsHint, isNotEmpty, reason: '${locale.languageCode}: noImportedFontsHint');
      expect(l10n.deleteFontConfirm('TestFont'), contains('TestFont'), reason: '${locale.languageCode}: deleteFontConfirm');
      expect(l10n.fontImportSuccess, isNotEmpty, reason: '${locale.languageCode}: fontImportSuccess');
      expect(l10n.fontImportFailed, isNotEmpty, reason: '${locale.languageCode}: fontImportFailed');
      expect(l10n.lyricsKaraokeModel, isNotEmpty, reason: '${locale.languageCode}: lyricsKaraokeModel');
      expect(l10n.lyricsKaraokeModelDescription, isNotEmpty, reason: '${locale.languageCode}: lyricsKaraokeModelDescription');
    }
  });
}
