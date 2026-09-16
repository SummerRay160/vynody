import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vynody/l10n/app_localizations.dart';
import 'package:vynody/utils/app_proxy_manager.dart';

final class CustomProxyConfig {
  const CustomProxyConfig({
    required this.host,
    required this.port,
    required this.bypass,
  });

  final String host;
  final int port;
  final String bypass;
}

Future<CustomProxyConfig?> showCustomProxyDialog(
  BuildContext context, {
  required String initialHost,
  required int initialPort,
  required String initialBypass,
}) async {
  return showDialog<CustomProxyConfig>(
    context: context,
    builder: (dialogContext) {
      return CustomProxyConfigDialog(
        initialHost: initialHost,
        initialPort: initialPort,
        initialBypass: initialBypass,
      );
    },
  );
}

class CustomProxyConfigDialog extends StatefulWidget {
  const CustomProxyConfigDialog({
    super.key,
    required this.initialHost,
    required this.initialPort,
    required this.initialBypass,
  });

  final String initialHost;
  final int initialPort;
  final String initialBypass;

  @override
  State<CustomProxyConfigDialog> createState() =>
      _CustomProxyConfigDialogState();
}

class _CustomProxyConfigDialogState extends State<CustomProxyConfigDialog> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _bypassController;
  bool _isTesting = false;
  String _statusText = '';
  bool _statusSuccess = false;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.initialHost);
    _portController = TextEditingController(
      text: widget.initialPort > 0 ? widget.initialPort.toString() : '7890',
    );
    _bypassController = TextEditingController(text: widget.initialBypass);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _bypassController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final l10n = AppLocalizations.of(context)!;
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 0;

    if (host.isEmpty || port <= 0 || port > 65535) {
      setState(() {
        _statusText = l10n.proxyHostPortInvalid;
        _statusSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _statusText = '';
    });

    final success = await AppProxyManager.instance.testProxyConnection(
      host,
      port,
    );

    if (!mounted) return;

    setState(() {
      _isTesting = false;
      _statusSuccess = success;
      _statusText = success ? l10n.proxyTestSuccess : l10n.proxyTestFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.proxySettingsTitle),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: theme.hintColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.proxyModeCustomDesc,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextField(
                controller: _hostController,
                decoration: InputDecoration(
                  labelText: l10n.proxyHost,
                  hintText: l10n.proxyHostHint,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.dns_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.proxyPort,
                  hintText: l10n.proxyPortHint,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.numbers_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bypassController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.proxyBypass,
                  hintText: l10n.proxyBypassHint,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.alt_route_rounded),
                ),
              ),
              if (_statusText.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      _statusSuccess
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      size: 18,
                      color: _statusSuccess ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusText,
                        style: TextStyle(
                          fontSize: 13,
                          color: _statusSuccess ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isTesting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _isTesting ? null : _testConnection,
          child: _isTesting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.proxyTestConnection),
        ),
        FilledButton(
          onPressed: () {
            final host = _hostController.text.trim();
            final port = int.tryParse(_portController.text.trim()) ?? 7890;
            final bypass = _bypassController.text.trim();
            Navigator.of(context).pop(
              CustomProxyConfig(
                host: host.isEmpty ? '127.0.0.1' : host,
                port: port <= 0 ? 7890 : port,
                bypass: bypass,
              ),
            );
          },
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
