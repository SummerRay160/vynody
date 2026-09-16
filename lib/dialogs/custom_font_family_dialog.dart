import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Shows a dialog to enter a custom font family name with live preview.
Future<String?> showCustomFontFamilyDialog(
  BuildContext context, {
  required String initialFontFamily,
  required String title,
  String? hintText,
}) async {
  return showDialog<String?>(
    context: context,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext)!;
      return _CustomFontFamilyDialog(
        initialFontFamily: initialFontFamily,
        title: title,
        hintText: hintText ?? l10n.customFontDialogHint,
      );
    },
  );
}

class _CustomFontFamilyDialog extends StatefulWidget {
  const _CustomFontFamilyDialog({
    required this.initialFontFamily,
    required this.title,
    required this.hintText,
  });

  final String initialFontFamily;
  final String title;
  final String hintText;

  @override
  State<_CustomFontFamilyDialog> createState() =>
      _CustomFontFamilyDialogState();
}

class _CustomFontFamilyDialogState extends State<_CustomFontFamilyDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialFontFamily);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fontName = _controller.text.trim();

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: widget.title,
                  hintText: widget.hintText,
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _controller.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
              ),
              if (fontName.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preview / 预览:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'The quick brown fox jumps over the lazy dog.\n落霞与孤鹜齐飞，秋水共长天一色。0123456789',
                        style: TextStyle(
                          fontFamily: fontName,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
