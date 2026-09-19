import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'custom_font_service.dart';

enum FontCategory {
  all,
  custom,
  recommended,
  cjk,
  latin,
}

class FontItem {
  final String family;
  final String displayName;
  final bool isCjk;
  final bool isRecommended;
  final bool isCustom;

  const FontItem({
    required this.family,
    required this.displayName,
    this.isCjk = false,
    this.isRecommended = false,
    this.isCustom = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FontItem &&
          runtimeType == other.runtimeType &&
          family == other.family;

  @override
  int get hashCode => family.hashCode;
}

class SystemFontsService {
  SystemFontsService._();
  static final SystemFontsService instance = SystemFontsService._();

  static const Map<String, String> _cjkDisplayNameMap = {
    'Microsoft YaHei': '微软雅黑 (Microsoft YaHei)',
    'Microsoft YaHei UI': '微软雅黑 UI (YaHei UI)',
    'PingFang SC': '苹方-简 (PingFang SC)',
    'PingFang TC': '苹方-繁 (PingFang TC)',
    'PingFang HK': '苹方-港 (PingFang HK)',
    'Songti SC': '宋体-简 (Songti SC)',
    'Songti TC': '宋体-繁 (Songti TC)',
    'Kaiti SC': '楷体-简 (Kaiti SC)',
    'Kaiti TC': '楷体-繁 (Kaiti TC)',
    'Heiti SC': '黑体-简 (Heiti SC)',
    'Heiti TC': '黑体-繁 (Heiti TC)',
    'Yuanti SC': '圆体-简 (Yuanti SC)',
    'Yuanti TC': '圆体-繁 (Yuanti TC)',
    'Baoli SC': '报隶-简 (Baoli SC)',
    'Xingkai SC': '行楷-简 (Xingkai SC)',
    'Wawati SC': '娃娃体-简 (Wawati SC)',
    'Weibei SC': '魏碑-简 (Weibei SC)',
    'Yuppy SC': '雅痞-简 (Yuppy SC)',
    'STSong': '华文宋体 (STSong)',
    'STHeiti': '华文黑体 (STHeiti)',
    'STKaiti': '华文楷体 (STKaiti)',
    'STFangsong': '华文仿宋 (STFangsong)',
    'KaiTi': '楷体 (KaiTi)',
    'SimSun': '宋体 (SimSun)',
    'FangSong': '仿宋 (FangSong)',
    'SimHei': '黑体 (SimHei)',
    'LXGW WenKai': '霞鹜文楷 (LXGW WenKai)',
    'LXGW WenKai Screen': '霞鹜文楷屏幕版 (LXGW WenKai Screen)',
    'Source Han Sans SC': '思源黑体 (Source Han Sans)',
    'Source Han Serif SC': '思源宋体 (Source Han Serif)',
    'Noto Sans SC': '思源黑体 (Noto Sans SC)',
    'Noto Serif SC': '思源宋体 (Noto Serif SC)',
    'Noto Sans CJK SC': '思源黑体 (Noto Sans CJK SC)',
    'Noto Serif CJK SC': '思源宋体 (Noto Serif CJK SC)',
    'HarmonyOS Sans SC': '鸿蒙黑体 (HarmonyOS Sans)',
    'Hiragino Sans GB': '冬青黑体 (Hiragino Sans GB)',
  };

  static const List<String> _recommendedCjk = [
    'Microsoft YaHei',
    'Microsoft YaHei UI',
    'PingFang SC',
    'LXGW WenKai',
    'Source Han Sans SC',
    'Source Han Serif SC',
    'HarmonyOS Sans SC',
    'KaiTi',
    'SimSun',
    'FangSong',
    'SimHei',
    'Songti SC',
    'Kaiti SC',
    'Hiragino Sans GB',
  ];

  static const List<String> _recommendedLatin = [
    'Segoe UI',
    'Inter',
    'Arial',
    'Helvetica',
    'SF Pro',
    'Roboto',
    'Georgia',
    'Cascadia Code',
    'Consolas',
    'Fira Code',
    'JetBrains Mono',
    'Times New Roman',
  ];

  List<FontItem>? _cachedFonts;
  bool _isLoading = false;

  void invalidateCache() {
    _cachedFonts = null;
  }

  /// Returns cached list immediately or default presets while async loading runs.
  List<FontItem> getAvailableFontsSync() {
    if (_cachedFonts != null && _cachedFonts!.isNotEmpty) {
      return _cachedFonts!;
    }
    _ensureLoaded();
    return _buildPresetFonts();
  }

  /// Asynchronously returns all system fonts.
  Future<List<FontItem>> getAvailableFonts() async {
    if (_cachedFonts != null && _cachedFonts!.isNotEmpty) {
      return _cachedFonts!;
    }
    await _ensureLoaded();
    return _cachedFonts ?? _buildPresetFonts();
  }

  Future<void> _ensureLoaded() async {
    if (_isLoading) {
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 30));
      }
      return;
    }

    _isLoading = true;
    try {
      final rawFamilies = await _scanSystemFamilies();
      final items = <FontItem>[];
      final seen = <String>{};

      // 1. Process imported custom fonts first
      for (final customFont in CustomFontService.instance.fonts) {
        final fam = customFont.family;
        if (fam.isNotEmpty && seen.add(fam.toLowerCase())) {
          items.add(FontItem(
            family: fam,
            displayName: fam,
            isCjk: _isCjkFont(fam),
            isRecommended: true,
            isCustom: true,
          ));
        }
      }

      // 2. Process real system fonts actually found on the OS
      for (final raw in rawFamilies) {
        final fam = raw.trim();
        if (fam.isEmpty || !seen.add(fam.toLowerCase())) continue;

        final isCjk = _isCjkFont(fam);
        final isRec = _recommendedCjk.contains(fam) || _recommendedLatin.contains(fam);
        final displayName = _cjkDisplayNameMap[fam] ?? fam;

        items.add(FontItem(
          family: fam,
          displayName: displayName,
          isCjk: isCjk,
          isRecommended: isRec,
          isCustom: false,
        ));
      }

      // Sort: custom fonts first, then alphabetically by display name
      items.sort((a, b) {
        if (a.isCustom != b.isCustom) {
          return a.isCustom ? -1 : 1;
        }
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });
      _cachedFonts = items;
    } catch (_) {
      _cachedFonts ??= _buildPresetFonts();
    } finally {
      _isLoading = false;
    }
  }

  List<FontItem> _buildPresetFonts() {
    final list = <FontItem>[];
    for (final customFont in CustomFontService.instance.fonts) {
      list.add(FontItem(
        family: customFont.family,
        displayName: customFont.family,
        isCjk: _isCjkFont(customFont.family),
        isRecommended: true,
        isCustom: true,
      ));
    }
    return list;
  }

  static bool _isCjkFont(String familyName) {
    if (_cjkDisplayNameMap.containsKey(familyName)) return true;
    final lower = familyName.toLowerCase();
    const cjkKeywords = [
      'sc',
      'tc',
      'hk',
      'cjk',
      'song',
      'hei',
      'kai',
      'yuan',
      'ming',
      'yahei',
      'pingfang',
      'fangsong',
      'kaiti',
      'simsun',
      'simhei',
      'gothic',
      'mincho',
      'wenkai',
      'han',
      'wawati',
      'weibei',
      'yuppy',
      'baoli',
    ];
    for (final kw in cjkKeywords) {
      if (lower.contains(kw)) return true;
    }
    // Check if contains non-ascii Chinese chars
    for (final rune in familyName.runes) {
      if (rune >= 0x4E00 && rune <= 0x9FFF) return true;
    }
    return false;
  }

  Future<List<String>> _scanSystemFamilies() async {
    try {
      if (Platform.isMacOS || Platform.isIOS) {
        return _scanMacFonts();
      } else if (Platform.isWindows) {
        return await _scanWindowsFonts();
      } else if (Platform.isLinux) {
        return await _scanLinuxFonts();
      } else if (Platform.isAndroid) {
        return await _scanAndroidFonts();
      }
    } catch (_) {}
    return [];
  }

  List<String> _scanMacFonts() {
    try {
      final dylib = DynamicLibrary.process();

      final copyFontFamilies = dylib.lookupFunction<
          Pointer Function(),
          Pointer Function()>('CTFontManagerCopyAvailableFontFamilyNames');

      final cfArrayGetCount = dylib.lookupFunction<
          IntPtr Function(Pointer),
          int Function(Pointer)>('CFArrayGetCount');

      final cfArrayGetValueAtIndex = dylib.lookupFunction<
          Pointer Function(Pointer, IntPtr),
          Pointer Function(Pointer, int)>('CFArrayGetValueAtIndex');

      final cfStringGetCString = dylib.lookupFunction<
          Bool Function(Pointer, Pointer<Utf8>, IntPtr, Uint32),
          bool Function(Pointer, Pointer<Utf8>, int, int)>('CFStringGetCString');

      final cfRelease = dylib.lookupFunction<
          Void Function(Pointer),
          void Function(Pointer)>('CFRelease');

      final array = copyFontFamilies();
      if (array == nullptr) return [];

      final count = cfArrayGetCount(array);
      final buffer = calloc<Uint8>(512).cast<Utf8>();
      const kCFStringEncodingUTF8 = 0x08000100;

      final result = <String>[];
      for (var i = 0; i < count; i++) {
        final strRef = cfArrayGetValueAtIndex(array, i);
        if (strRef != nullptr &&
            cfStringGetCString(strRef, buffer, 512, kCFStringEncodingUTF8)) {
          result.add(buffer.toDartString());
        }
      }
      calloc.free(buffer);
      cfRelease(array);

      return result;
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> _scanWindowsFonts() async {
    final result = <String>{};
    try {
      // Query HKLM
      final hklmResult = await Process.run('reg', [
        'query',
        r'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
      ]);
      _parseWindowsRegOutput(hklmResult.stdout as String, result);
    } catch (_) {}

    try {
      // Query HKCU for user installed fonts
      final hkcuResult = await Process.run('reg', [
        'query',
        r'HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
      ]);
      _parseWindowsRegOutput(hkcuResult.stdout as String, result);
    } catch (_) {}

    return result.toList();
  }

  void _parseWindowsRegOutput(String stdout, Set<String> result) {
    final lines = stdout.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || !trimmed.contains('REG_SZ')) continue;

      final parts = trimmed.split(RegExp(r'\s+REG_SZ\s+'));
      if (parts.isNotEmpty) {
        var rawName = parts[0].trim();
        // Remove trailing (TrueType), (OpenType), etc.
        rawName = rawName.replaceAll(RegExp(r'\s*\([^)]*\)$'), '').trim();
        // Split multi-names if joined by '&'
        if (rawName.contains('&')) {
          for (final sub in rawName.split('&')) {
            final cleaned = sub.trim();
            if (cleaned.isNotEmpty) result.add(cleaned);
          }
        } else if (rawName.isNotEmpty) {
          result.add(rawName);
        }
      }
    }
  }

  Future<List<String>> _scanLinuxFonts() async {
    final result = <String>{};
    try {
      final res = await Process.run('fc-list', [':', 'family']);
      if (res.exitCode == 0) {
        final lines = (res.stdout as String).split('\n');
        for (final line in lines) {
          for (final part in line.split(',')) {
            final trimmed = part.trim();
            if (trimmed.isNotEmpty) result.add(trimmed);
          }
        }
      }
    } catch (_) {}
    return result.toList();
  }

  Future<List<String>> _scanAndroidFonts() async {
    final result = <String>{};
    try {
      const fontsXmlPaths = [
        '/system/etc/fonts.xml',
        '/system/etc/font_fallback.xml',
        '/etc/fonts.xml',
      ];
      for (final path in fontsXmlPaths) {
        final file = File(path);
        if (await file.exists()) {
          final content = await file.readAsString();
          final matches = RegExp(r'<family name="([^"]+)"').allMatches(content);
          for (final match in matches) {
            final name = match.group(1)?.trim();
            if (name != null && name.isNotEmpty) {
              result.add(name);
            }
          }
        }
      }
    } catch (_) {}
    return result.toList();
  }
}
