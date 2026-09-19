import 'package:flutter_test/flutter_test.dart';
import 'package:vynody/player/lyrics/custom_font_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CustomFontService Tests', () {
    test('initial state has empty or unmodifiable fonts list', () {
      final service = CustomFontService.instance;
      expect(service.fonts, isA<List<CustomFontItem>>());
    });

    test('CustomFontItem equality and properties', () {
      const item1 = CustomFontItem(family: 'TestFont', filePath: '/path/to/TestFont.ttf');
      const item2 = CustomFontItem(family: 'TestFont', filePath: '/different/path.ttf');
      const item3 = CustomFontItem(family: 'OtherFont', filePath: '/path/to/OtherFont.ttf');

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));
      expect(item1, isNot(equals(item3)));
      expect(item1.family, 'TestFont');
      expect(item1.filePath, '/path/to/TestFont.ttf');
    });
  });
}
