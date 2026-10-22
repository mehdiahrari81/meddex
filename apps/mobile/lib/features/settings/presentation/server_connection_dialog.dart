import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/localization/localization_extension.dart';
import '../../../core/network/development_server.dart';
import '../../../design_system/widgets/overlays.dart';
import '../../auth/application/auth_controller.dart';
import '../../prescription/application/prescription_workflow_controller.dart';
import '../application/settings_controller.dart';

final developmentServerCheckProvider = Provider<Future<void> Function(Uri)>(
  (ref) =>
      (uri) => checkDevelopmentServer(uri),
);

Future<void> showServerConnectionDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final bundled = ref.read(bundledAppConfigProvider);
  final automaticUrl =
      bundled.environment == AppEnvironment.development &&
          bundled.apiBaseUrl.host.endsWith('.local')
      ? bundled.apiBaseUrl.toString()
      : null;
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _ServerConnectionDialog(
      initialUrl: ref.read(appConfigProvider).apiBaseUrl.toString(),
      automaticUrl: automaticUrl,
      automatic:
          automaticUrl != null &&
          (ref
                  .read(settingsControllerProvider)
                  .valueOrNull
                  ?.automaticServerConnection ??
              true),
    ),
  );
  if (saved == true && context.mounted) {
    AppOverlays.showMessage(context, context.l10n.serverConnectionSaved);
  }
}

class _ServerConnectionDialog extends ConsumerStatefulWidget {
  const _ServerConnectionDialog({
    required this.initialUrl,
    required this.automaticUrl,
    required this.automatic,
  });
  final String initialUrl;
  final String? automaticUrl;
  final bool automatic;
  @override
  ConsumerState<_ServerConnectionDialog> createState() =>
      _ServerConnectionDialogState();
}

class _ServerConnectionDialogState
    extends ConsumerState<_ServerConnectionDialog> {
  late final _address = TextEditingController(text: widget.initialUrl);
  late bool _automatic = widget.automatic;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    Uri uri;
    try {
      uri = validateDevelopmentServerUrl(
        _automatic ? widget.automaticUrl! : _address.text,
      );
    } on FormatException {
      setState(() => _error = context.l10n.serverAddressInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(developmentServerCheckProvider)(uri);
      if (!mounted) return;
      ref
          .read(prescriptionWorkflowControllerProvider.notifier)
          .cancelProcessing();
      await ref
          .read(settingsControllerProvider.notifier)
          .setDevelopmentServerUrl(
            _automatic ? '' : uri.toString(),
            automatic: _automatic,
          );
      if (mounted) Navigator.pop(context, true);
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.l10n.serverConnectionFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(context.l10n.serverConnection),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.serverConnectionHelp),
            if (widget.automaticUrl != null)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.automaticServerConnection),
                subtitle: Text(context.l10n.automaticServerConnectionHelp),
                value: _automatic,
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _automatic = value;
                        if (value) _address.text = widget.automaticUrl!;
                        _error = null;
                      }),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _address,
              enabled: !_busy && !_automatic,
              keyboardType: TextInputType.url,
              autocorrect: false,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: context.l10n.serverAddress,
                hintText: 'http://192.168.1.20:8000/api/v1/',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.l10n.testAndSave),
        ),
      ],
    ),
  );
}
