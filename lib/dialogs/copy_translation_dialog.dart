import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

enum CopyTranslationMode { plain, withTimestamps }

class CopyTranslationDialog extends StatefulWidget {
  const CopyTranslationDialog({super.key, required this.hasTimedLyrics});

  final bool hasTimedLyrics;

  @override
  State<CopyTranslationDialog> createState() => _CopyTranslationDialogState();
}

class _CopyTranslationDialogState extends State<CopyTranslationDialog> {
  CopyTranslationMode _mode = CopyTranslationMode.plain;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.copyTranslationResults),
      content: SizedBox(
        width: 320,
        child: RadioGroup<CopyTranslationMode>(
          groupValue: _mode,
          onChanged: (val) {
            if (val != null) setState(() => _mode = val);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<CopyTranslationMode>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(l10n.copyTranslation),
                value: CopyTranslationMode.plain,
              ),
              if (widget.hasTimedLyrics)
                RadioListTile<CopyTranslationMode>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(l10n.copyTranslationWithTimestamps),
                  value: CopyTranslationMode.withTimestamps,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_mode),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

Future<CopyTranslationMode?> showCopyTranslationDialog(
  BuildContext context, {
  required bool hasTimedLyrics,
}) {
  return showDialog<CopyTranslationMode>(
    context: context,
    builder: (_) => CopyTranslationDialog(hasTimedLyrics: hasTimedLyrics),
  );
}
