import 'package:flutter_test/flutter_test.dart';
import 'package:vynody/player/lyrics/system_fonts_service.dart';

void main() {
  group('SystemFontsService Tests', () {
    test('getAvailableFonts loads system fonts and getAvailableFontsSync returns cached list', () async {
      final fonts = await SystemFontsService.instance.getAvailableFonts();
      expect(fonts, isNotEmpty);

      final cached = SystemFontsService.instance.getAvailableFontsSync();
      expect(cached, isNotEmpty);
      expect(cached.length, fonts.length);
    });

    test('getAvailableFonts returns system fonts with display names and categories', () async {
      final fonts = await SystemFontsService.instance.getAvailableFonts();
      expect(fonts, isNotEmpty);

      // Check for CJK font item
      final pingFang = fonts.firstWhere(
        (f) => f.family == 'PingFang SC',
        orElse: () => fonts.firstWhere((f) => f.isCjk),
      );
      expect(pingFang.isCjk, isTrue);

      // Check for Latin font item
      final latinFont = fonts.firstWhere(
        (f) => f.family == 'Segoe UI' || f.family == 'Arial',
        orElse: () => fonts.firstWhere((f) => !f.isCjk),
      );
      expect(latinFont.isCjk, isFalse);
    });

    test('displayName mapping works for common fonts', () async {
      final fonts = await SystemFontsService.instance.getAvailableFonts();
      final yahei = fonts.where((f) => f.family == 'Microsoft YaHei').toList();
      if (yahei.isNotEmpty) {
        expect(yahei.first.displayName, contains('微软雅黑'));
      }
    });
  });
}
