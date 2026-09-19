import 'dart:io';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../player/lyrics/custom_font_service.dart';
import '../player/lyrics/system_fonts_service.dart';
import '../utils/app_snack_bar.dart';
import 'custom_font_family_dialog.dart';

/// Shows a comprehensive font picker dialog with live preview and system font listing.
Future<String?> showLyricsFontPickerDialog(
  BuildContext context, {
  required String initialFont,
  required String title,
  bool isCjkMode = false,
  ValueChanged<String>? onFontPreview,
}) async {
  return showDialog<String?>(
    context: context,
    builder: (dialogContext) => _LyricsFontPickerDialog(
      initialFont: initialFont,
      title: title,
      isCjkMode: isCjkMode,
      onFontPreview: onFontPreview,
    ),
  );
}

class _LyricsFontPickerDialog extends StatefulWidget {
  const _LyricsFontPickerDialog({
    required this.initialFont,
    required this.title,
    required this.isCjkMode,
    this.onFontPreview,
  });

  final String initialFont;
  final String title;
  final bool isCjkMode;
  final ValueChanged<String>? onFontPreview;

  @override
  State<_LyricsFontPickerDialog> createState() => _LyricsFontPickerDialogState();
}

class _LyricsFontPickerDialogState extends State<_LyricsFontPickerDialog> {
  late String _selectedFont;
  late TextEditingController _searchController;
  FontCategory _category = FontCategory.recommended;
  List<FontItem> _allFonts = [];
  bool _isLoading = true;

  bool get _isAndroid => Platform.isAndroid;
  bool get _hasCustomFonts => _allFonts.any((f) => f.isCustom);

  @override
  void initState() {
    super.initState();
    _selectedFont = widget.initialFont.trim();
    _searchController = TextEditingController();
    _category = _isAndroid ? FontCategory.all : FontCategory.recommended;

    // Load initial sync presets first, then await full scan
    _allFonts = SystemFontsService.instance.getAvailableFontsSync();
    _loadSystemFonts();
  }

  Future<void> _loadSystemFonts() async {
    final fonts = await SystemFontsService.instance.getAvailableFonts();
    if (!mounted) return;
    setState(() {
      _allFonts = fonts;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectFont(String font) {
    setState(() {
      _selectedFont = font.trim();
    });
    widget.onFontPreview?.call(_selectedFont);
  }

  Future<void> _handleImportFont() async {
    final l10n = AppLocalizations.of(context)!;
    final imported = await CustomFontService.instance.importFontFile();
    if (imported == null) return;
    if (!mounted) return;

    SystemFontsService.instance.invalidateCache();
    await _loadSystemFonts();
    _selectFont(imported.family);

    if (mounted) {
      AppSnackBar.show(context, null, SnackBar(content: Text(l10n.fontImportSuccess)));
    }
  }

  Future<void> _handleDeleteFont(FontItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteFontConfirm(item.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await CustomFontService.instance.deleteFont(item.family);
    SystemFontsService.instance.invalidateCache();
    await _loadSystemFonts();

    if (_selectedFont == item.family) {
      _selectFont('');
    }
  }

  List<FontItem> _getFilteredFonts() {
    final query = _searchController.text.trim().toLowerCase();

    return _allFonts.where((item) {
      // 1. Category check
      switch (_category) {
        case FontCategory.custom:
          if (!item.isCustom) return false;
          break;
        case FontCategory.recommended:
          if (!item.isRecommended) return false;
          if (widget.isCjkMode && !item.isCjk) return false;
          if (!widget.isCjkMode && item.isCjk) return false;
          break;
        case FontCategory.cjk:
          if (!item.isCjk) return false;
          break;
        case FontCategory.latin:
          if (item.isCjk) return false;
          break;
        case FontCategory.all:
          break;
      }

      // 2. Query search
      if (query.isNotEmpty) {
        final matchFamily = item.family.toLowerCase().contains(query);
        final matchDisplay = item.displayName.toLowerCase().contains(query);
        if (!matchFamily && !matchDisplay) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final filteredFonts = _getFilteredFonts();
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = (screenSize.width * 0.7).clamp(380.0, 560.0);
    final dialogHeight = (screenSize.height * 0.8).clamp(480.0, 680.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: dialogHeight,
        ),
        child: Column(
          children: [
            // Title Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: l10n.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Live Preview Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildPreviewCard(theme, colorScheme, l10n),
            ),

            const SizedBox(height: 12),

            // Search and Category Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l10n.searchFontHint,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (!_isAndroid) ...[
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCategoryChip(
                            label: l10n.recommendedFonts,
                            category: FontCategory.recommended,
                            colorScheme: colorScheme,
                          ),
                          if (_hasCustomFonts) ...[
                            const SizedBox(width: 8),
                            _buildCategoryChip(
                              label: '${l10n.importedFonts} (${_allFonts.where((f) => f.isCustom).length})',
                              category: FontCategory.custom,
                              colorScheme: colorScheme,
                            ),
                          ],
                          const SizedBox(width: 8),
                          _buildCategoryChip(
                            label: l10n.cjkFonts,
                            category: FontCategory.cjk,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(width: 8),
                          _buildCategoryChip(
                            label: l10n.latinFonts,
                            category: FontCategory.latin,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(width: 8),
                          _buildCategoryChip(
                            label: '${l10n.allFonts} (${_allFonts.length})',
                            category: FontCategory.all,
                            colorScheme: colorScheme,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 16),

            // Font List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: filteredFonts.isEmpty && _isAndroid
                    ? 2 // index 0: default, index 1: empty hint
                    : filteredFonts.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Default / Follow System
                    final isSelected = _selectedFont.isEmpty;
                    return _buildFontTile(
                      title: l10n.defaultFontOption,
                      subtitle: widget.isCjkMode
                          ? '落霞与孤鹜齐飞，秋水共长天一色'
                          : 'The quick brown fox jumps over the lazy dog',
                      fontFamily: '',
                      isSelected: isSelected,
                      isCustom: false,
                      colorScheme: colorScheme,
                      theme: theme,
                      onTap: () => _selectFont(''),
                    );
                  }

                  if (filteredFonts.isEmpty && _isAndroid) {
                    return Container(
                      margin: const EdgeInsets.only(top: 24, left: 16, right: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.font_download_outlined, size: 40, color: colorScheme.outline),
                          const SizedBox(height: 10),
                          Text(
                            l10n.noImportedFontsHint,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final item = filteredFonts[index - 1];
                  final isSelected = _selectedFont == item.family;
                  final sampleText = widget.isCjkMode
                      ? '落霞与孤鹜齐飞，秋水共长天一色。0123456789'
                      : 'The quick brown fox jumps over the lazy dog. 0123456789';

                  return _buildFontTile(
                    title: item.displayName,
                    subtitle: sampleText,
                    fontFamily: item.family,
                    isSelected: isSelected,
                    isCustom: item.isCustom,
                    colorScheme: colorScheme,
                    theme: theme,
                    onTap: () => _selectFont(item.family),
                    onDelete: item.isCustom ? () => _handleDeleteFont(item) : null,
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Bottom Action Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    label: Text(l10n.importFontFile),
                    onPressed: _handleImportFont,
                  ),
                  if (!_isAndroid) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: Text(l10n.customFontOption),
                      onPressed: () async {
                        final entered = await showCustomFontFamilyDialog(
                          context,
                          initialFontFamily: _selectedFont,
                          title: widget.title,
                        );
                        if (entered != null) {
                          _selectFont(entered);
                        }
                      },
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selectedFont),
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    final effectiveFont = _selectedFont.isNotEmpty ? _selectedFont : null;
    final fontLabel = _selectedFont.isEmpty ? l10n.followSystemLanguage : _selectedFont;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_rounded, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                '${l10n.lyricsFontPreview} · $fontLabel',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.isCjkMode
                ? '落霞与孤鹜齐飞，秋水共长天一色。'
                : 'The quick brown fox jumps over the lazy dog.',
            style: TextStyle(
              fontFamily: effectiveFont,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            widget.isCjkMode
                ? 'The quick brown fox jumps over the lazy dog. 0123456789'
                : '落霞与孤鹜齐飞，秋水共长天一色。0123456789',
            style: TextStyle(
              fontFamily: effectiveFont,
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required FontCategory category,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _category == category;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _category = category;
          });
        }
      },
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
      ),
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      side: BorderSide(
        color: isSelected ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildFontTile({
    required String title,
    required String subtitle,
    required String fontFamily,
    required bool isSelected,
    required bool isCustom,
    required ColorScheme colorScheme,
    required ThemeData theme,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.45) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        dense: true,
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? colorScheme.primary : null,
                ),
              ),
            ),
            if (isCustom)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  AppLocalizations.of(context)!.importedFonts,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontFamily: fontFamily.isNotEmpty ? fontFamily : null,
            fontSize: 13,
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.8)
                : colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                color: colorScheme.error.withValues(alpha: 0.7),
                onPressed: onDelete,
              ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 20),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
