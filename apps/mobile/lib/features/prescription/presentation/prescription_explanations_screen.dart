import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../application/prescription_workflow_controller.dart';
import '../domain/prescription_models.dart';
import '../data/api_medicine_batch_overview.dart';
import '../application/prescription_error_message.dart';
import 'medicine_overview_card.dart';
import 'prescription_field_display.dart';

class PrescriptionExplanationsScreen extends ConsumerStatefulWidget {
  const PrescriptionExplanationsScreen({
    required this.prescriptionId,
    super.key,
  });
  final String prescriptionId;

  @override
  ConsumerState<PrescriptionExplanationsScreen> createState() =>
      _PrescriptionExplanationsScreenState();
}

class _PrescriptionExplanationsScreenState
    extends ConsumerState<PrescriptionExplanationsScreen> {
  bool _loaded = false;
  bool _failed = false;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant PrescriptionExplanationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prescriptionId != widget.prescriptionId) _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final version = ++_loadVersion;
    setState(() {
      _loaded = false;
      _failed = false;
    });
    try {
      await ref
          .read(prescriptionWorkflowControllerProvider.notifier)
          .loadDraft(widget.prescriptionId);
      if (mounted && version == _loadVersion) setState(() => _loaded = true);
    } on Object {
      if (mounted && version == _loadVersion) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prescription = ref
        .watch(prescriptionWorkflowControllerProvider)
        .prescription;
    final reviewPath = '/prescriptions/${widget.prescriptionId}/review';
    Widget body;
    if (_failed) {
      body = AppEmptyState(
        title: 'Could not load medicines',
        message: 'Your prescription is saved. Please retry.',
        icon: Icons.refresh_rounded,
        action: AppPrimaryButton(label: 'Retry', onPressed: _load),
      );
    } else if (!_loaded) {
      body = const AppLoadingState(label: 'Loading confirmed medicines…');
    } else {
      final items = prescription?.id == widget.prescriptionId
          ? prescription!.items
                .where((item) => item.state != PrescriptionItemState.rejected)
                .toList(growable: false)
          : <PrescriptionItem>[];
      final ready =
          items.isNotEmpty &&
          items.every(
            (item) =>
                item.state == PrescriptionItemState.readyForLookup &&
                item.field(PrescriptionFieldType.medicationName).hasValue &&
                !item.fields.values.any(prescriptionFieldNeedsCheck),
          );
      if (!ready) {
        body = AppEmptyState(
          title: 'Review your medicines first',
          message:
              'Confirm every medicine before loading explanations. If details have changed, review them again.',
          icon: Icons.fact_check_outlined,
          action: AppPrimaryButton(
            label: 'Review medicines',
            onPressed: () => context.go(reviewPath),
          ),
        );
      } else {
        final language = Localizations.localeOf(context).languageCode == 'ur'
            ? 'ur'
            : 'en';
        final queries = [for (final item in items) _query(item, language)];
        final bodyJson = jsonEncode({
          'language': language,
          'medicines': [
            for (var i = 0; i < items.length; i++)
              {
                'item_id': items[i].id,
                'name': queries[i].name,
                'strength': queries[i].strength,
                'dosage_form': queries[i].form,
                'user_confirmed': true,
              },
          ],
        });
        final batch = medicineBatchOverviewProvider(bodyJson);
        body = ref
            .watch(batch)
            .when(
              loading: () => const AppLoadingState(
                label: 'Explaining your medicine list…',
              ),
              error: (error, _) => AppEmptyState(
                title: 'Could not load the explanations',
                message: prescriptionErrorMessage(error),
                icon: Icons.refresh_rounded,
                action: AppPrimaryButton(
                  label: 'Retry explanations',
                  onPressed: () => ref.invalidate(batch),
                ),
              ),
              data: (results) => ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  for (var i = 0; i < results.length; i++) ...[
                    AppCard(
                      key: ValueKey('explanation-${results[i].itemId}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            results[i].name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          MedicineOverviewContent(
                            query: queries[i],
                            overview: results[i].overview,
                            retryLabel: 'Retry explanations',
                            onRetry: () => ref.invalidate(batch),
                            onEditName: () => context.push(
                              '/prescriptions/${widget.prescriptionId}/items/${results[i].itemId}/edit',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  TextButton.icon(
                    onPressed: () => ref.invalidate(batch),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh all explanations'),
                  ),
                ],
              ),
            );
      }
    }
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(fallbackLocation: reviewPath),
        title: const Text('Medicine explanations'),
      ),
      body: body,
    );
  }

  MedicineOverviewQuery _query(PrescriptionItem item, String language) {
    final strength = item.field(PrescriptionFieldType.strength);
    final form = item.field(PrescriptionFieldType.dosageForm);
    return (
      name: item.field(PrescriptionFieldType.medicationName).currentValue!,
      strength: strength.hasValue && !prescriptionFieldNeedsCheck(strength)
          ? strength.currentValue
          : null,
      form: form.hasValue && !prescriptionFieldNeedsCheck(form)
          ? prescriptionFieldValue(form)
          : null,
      language: language,
    );
  }
}
