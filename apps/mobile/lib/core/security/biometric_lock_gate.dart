import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/settings_controller.dart';
import 'biometric_lock.dart';

class BiometricLockGate extends ConsumerStatefulWidget {
  const BiometricLockGate({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends ConsumerState<BiometricLockGate>
    with WidgetsBindingObserver {
  bool _locked = true;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(settingsControllerProvider, (previous, next) {
      final enabled = next.valueOrNull?.biometricLockEnabled ?? false;
      final previouslyEnabled =
          previous?.valueOrNull?.biometricLockEnabled ?? false;
      if (!enabled) {
        if (mounted) setState(() => _locked = false);
      } else if (!previouslyEnabled) {
        if (mounted) setState(() => _locked = true);
        _unlockIfRequired();
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final enabled =
        ref
            .read(settingsControllerProvider)
            .valueOrNull
            ?.biometricLockEnabled ??
        false;
    if (enabled &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden)) {
      setState(() => _locked = true);
    }
    if (state == AppLifecycleState.resumed) _unlockIfRequired();
  }

  Future<void> _unlockIfRequired() async {
    final enabled =
        ref
            .read(settingsControllerProvider)
            .valueOrNull
            ?.biometricLockEnabled ??
        false;
    if (!enabled) {
      if (mounted) setState(() => _locked = false);
      return;
    }
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final unlocked = await ref.read(biometricLockProvider).authenticate();
      if (mounted) setState(() => _locked = !unlocked);
    } on Object {
      if (mounted) setState(() => _locked = true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        ref
            .watch(settingsControllerProvider)
            .valueOrNull
            ?.biometricLockEnabled ??
        false;
    if (!enabled || !_locked) return widget.child;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Semantics(
          liveRegion: true,
          label: 'MediExplain is locked',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 56),
              const SizedBox(height: 16),
              Text(
                'MediExplain is locked',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _checking ? null : _unlockIfRequired,
                icon: const Icon(Icons.fingerprint_rounded),
                label: Text(_checking ? 'Checking…' : 'Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
