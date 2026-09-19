import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../utils/app_log.dart';
import '../../utils/file_selector_helper.dart';

class CustomFontItem {
  final String family;
  final String filePath;

  const CustomFontItem({
    required this.family,
    required this.filePath,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomFontItem &&
          runtimeType == other.runtimeType &&
          family == other.family;

  @override
  int get hashCode => family.hashCode;
}

class CustomFontService {
  CustomFontService._();
  static final CustomFontService instance = CustomFontService._();

  final List<CustomFontItem> _fonts = [];
  final Set<String> _loadedFamilies = {};
  bool _initialized = false;

  List<CustomFontItem> get fonts => List.unmodifiable(_fonts);

  Future<String> _getFontsDir() async {
    final supportDir = await getApplicationSupportDirectory();
    final fontsDir = Directory(p.join(supportDir.path, 'custom_fonts'));
    if (!await fontsDir.exists()) {
      await fontsDir.create(recursive: true);
    }
    return fontsDir.path;
  }

  /// Initialize and load all previously imported fonts at app launch.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final dirPath = await _getFontsDir();
      final dir = Directory(dirPath);
      final entries = dir.listSync();

      for (final entry in entries) {
        if (entry is File) {
          final ext = p.extension(entry.path).toLowerCase();
          if (ext == '.ttf' || ext == '.otf' || ext == '.ttc') {
            final family = p.basenameWithoutExtension(entry.path).trim();
            if (family.isNotEmpty) {
              await _loadFont(family, entry.path);
              _fonts.add(CustomFontItem(family: family, filePath: entry.path));
            }
          }
        }
      }
      _fonts.sort((a, b) => a.family.toLowerCase().compareTo(b.family.toLowerCase()));
      AppLog.log('[CustomFontService] Loaded ${_fonts.length} custom fonts on startup');
    } catch (e) {
      AppLog.log('[CustomFontService] Error initializing custom fonts: $e');
    }
  }

  Future<bool> _loadFont(String family, String filePath) async {
    try {
      if (_loadedFamilies.contains(family)) return true;
      final file = File(filePath);
      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();
      final fontLoader = FontLoader(family);
      fontLoader.addFont(Future.value(ByteData.sublistView(bytes)));
      await fontLoader.load();
      _loadedFamilies.add(family);
      return true;
    } catch (e) {
      AppLog.log('[CustomFontService] Failed to load font "$family": $e');
      return false;
    }
  }

  /// Prompts the user to pick a font file (.ttf / .otf / .ttc), copies it to
  /// local support storage, and dynamically registers it via [FontLoader].
  Future<CustomFontItem?> importFontFile() async {
    try {
      final path = await FileSelectorHelper.pickFile(
        label: 'Font Files (*.ttf, *.otf, *.ttc)',
        extensions: ['ttf', 'otf', 'ttc'],
      );
      if (path == null || path.isEmpty) return null;

      final srcFile = File(path);
      if (!await srcFile.exists()) return null;

      final baseName = p.basenameWithoutExtension(path).trim();
      final ext = p.extension(path);
      if (baseName.isEmpty) return null;

      final dirPath = await _getFontsDir();
      final destPath = p.join(dirPath, '$baseName$ext');

      // Copy file to persistent app storage
      await srcFile.copy(destPath);

      // Dynamically load font into Flutter engine
      final success = await _loadFont(baseName, destPath);
      if (!success) {
        try {
          await File(destPath).delete();
        } catch (_) {}
        return null;
      }

      // Add to list or replace existing
      final existingIndex = _fonts.indexWhere((f) => f.family == baseName);
      final newItem = CustomFontItem(family: baseName, filePath: destPath);
      if (existingIndex >= 0) {
        _fonts[existingIndex] = newItem;
      } else {
        _fonts.add(newItem);
        _fonts.sort((a, b) => a.family.toLowerCase().compareTo(b.family.toLowerCase()));
      }

      AppLog.log('[CustomFontService] Imported custom font "$baseName" successfully');
      return newItem;
    } catch (e) {
      AppLog.log('[CustomFontService] Error importing font: $e');
      return null;
    }
  }

  /// Deletes an imported custom font from local storage and in-memory list.
  Future<bool> deleteFont(String family) async {
    try {
      final index = _fonts.indexWhere((f) => f.family == family);
      if (index < 0) return false;

      final item = _fonts[index];
      final file = File(item.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      _fonts.removeAt(index);
      AppLog.log('[CustomFontService] Deleted custom font "$family"');
      return true;
    } catch (e) {
      AppLog.log('[CustomFontService] Error deleting font "$family": $e');
      return false;
    }
  }
}
