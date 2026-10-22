import 'delete_prescription.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../application/prescription_providers.dart';
import '../domain/prescription_models.dart';
import '../domain/prescription_repository.dart';
import 'prescription_review_screen.dart';

enum _HistoryFilter { all, verified, unresolved, draft }

class PrescriptionHistoryScreen extends ConsumerStatefulWidget {
  const PrescriptionHistoryScreen({this.showDraftsOnly = false, super.key});
  final bool showDraftsOnly;

  @override
  ConsumerState<PrescriptionHistoryScreen> createState() =>
      _PrescriptionHistoryScreenState();
}

class _PrescriptionHistoryScreenState
    extends ConsumerState<PrescriptionHistoryScreen> {
  String _query = '';
  late _HistoryFilter _filter = widget.showDraftsOnly
      ? _HistoryFilter.draft
      : _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(prescriptionHistoryProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/scan'),
        title: const Text('Prescription History'),
      ),
      body: history.when(
        loading: () => const AppLoadingState(label: 'Loading prescriptions…'),
        error: (_, _) => AppFullScreenError(
          title: 'History unavailable',
          message: 'Saved prescriptions could not be loaded from this device.',
          retryLabel: 'Try again',
          onRetry: () => ref.invalidate(prescriptionHistoryProvider),
        ),
        data: (values) {
          if (values.isEmpty) {
            return const AppEmptyState(
              title: 'No saved prescriptions',
              message:
                  'Captured, manual, and unresolved prescription drafts will appear here.',
              icon: Icons.receipt_long_outlined,
            );
          }
          final filtered = values.where(_matches).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              SearchBar(
                hintText: 'Search medicines locally',
                leading: const Icon(Icons.search_rounded),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final filter in _HistoryFilter.values)
                    ChoiceChip(
                      label: Text(switch (filter) {
                        _HistoryFilter.all => 'All',
                        _HistoryFilter.verified => 'Verified',
                        _HistoryFilter.unresolved => 'Unresolved',
                        _HistoryFilter.draft => 'Unfinished',
                      }),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (filtered.isEmpty)
                const AppEmptyState(
                  title: 'No matching prescriptions',
                  message: 'Try another medicine name or status.',
                  icon: Icons.search_off_rounded,
                )
              else
                for (final value in filtered) ...[
                  _HistoryCard(value: value),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
          );
        },
      ),
    );
  }

  bool _matches(PrescriptionHistoryEntry value) {
    final query = _query.toLowerCase();
    final text = '${value.medicationNames.join(' ')} ${value.captureDate}'
        .toLowerCase();
    if (query.isNotEmpty && !text.contains(query)) return false;
    return switch (_filter) {
      _HistoryFilter.all => true,
      _HistoryFilter.verified =>
        value.pipelineState ==
            PrescriptionPipelineState.readyForMedicationLookup,
      _HistoryFilter.unresolved => value.unresolvedCount > 0,
      _HistoryFilter.draft =>
        value.pipelineState !=
                PrescriptionPipelineState.readyForMedicationLookup &&
            value.pipelineState != PrescriptionPipelineState.userConfirmed,
    };
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.value});
  final PrescriptionHistoryEntry value;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppCard(
    key: ValueKey(value.id),
    semanticLabel:
        '${DateFormat.yMMMd().format(value.captureDate.toLocal())}. ${value.itemCount} medicine items. ${value.unresolvedCount} unresolved.',
    onTap: () => context.push('/prescriptions/${value.id}'),
    child: Row(
      children: [
        Icon(
          value.imageAvailable
              ? Icons.receipt_long_outlined
              : Icons.description_outlined,
          size: 32,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prescriptionCaptureLabel(value.captureDate),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                value.medicationNames.isEmpty
                    ? '${value.itemCount} medicine item(s)'
                    : value.medicationNames.join(', '),
              ),
              Text(
                value.unresolvedCount == 0
                    ? _pipelineLabel(value.pipelineState)
                    : '${value.unresolvedCount} unresolved item(s)',
              ),
              Text(
                value.imageAvailable
                    ? 'Source image available'
                    : 'Source image not retained',
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Delete prescription',
          onPressed: () => deletePrescriptionWithConfirmation(
            context,
            ref,
            value.id,
            capturedAt: value.captureDate,
          ),
          icon: const Icon(Icons.delete_outline_rounded),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}

String _pipelineLabel(PrescriptionPipelineState state) => switch (state) {
  PrescriptionPipelineState.readyForMedicationLookup => 'Reviewed by user',
  PrescriptionPipelineState.userReviewRequired => 'Review required',
  _ => 'Draft',
};

class PrescriptionDetailScreen extends ConsumerWidget {
  const PrescriptionDetailScreen({required this.prescriptionId, super.key});
  final String prescriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(prescriptionDetailProvider(prescriptionId));
    final pages = ref.watch(prescriptionPagesProvider(prescriptionId));
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(
          fallbackLocation: '/prescriptions/history',
        ),
        title: const Text('Prescription Detail'),
      ),
      body: detail.when(
        loading: () => const AppLoadingState(label: 'Loading prescription…'),
        error: (_, _) => const AppEmptyState(
          title: 'Prescription unavailable',
          message: 'This prescription may have been deleted.',
        ),
        data: (prescription) {
          if (prescription == null) {
            return const AppEmptyState(
              title: 'Prescription unavailable',
              message: 'This prescription may have been deleted.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              Text(
                DateFormat.yMMMMd().add_jm().format(
                  prescription.captureDate.toLocal(),
                ),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text('Status: ${prescription.pipelineState.name}'),
              Text('Source: ${prescription.sourceType.name}'),
              Text('Parser: ${prescription.parserVersion}'),
              Text(
                pages.valueOrNull?.isNotEmpty == true
                    ? 'Source image retained on this device'
                    : 'Source image not retained',
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('ORIGINAL PRESCRIPTION / USER EDIT'),
              for (
                var index = 0;
                index < prescription.items.length;
                index++
              ) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medicine ${index + 1}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Original source: ${prescription.items[index].sourceText}',
                      ),
                      for (final type in PrescriptionFieldType.values)
                        if (prescription.items[index].fields[type]?.hasValue ??
                            false)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              '${prescriptionFieldLabel(type)}: ${prescription.items[index].fields[type]!.currentValue}${prescription.items[index].fields[type]!.changedByUser ? ' (USER EDIT)' : ''}',
                            ),
                          ),
                      const SizedBox(height: AppSpacing.xs),
                      Text('State: ${prescription.items[index].state.name}'),
                      if (prescription.items[index].state ==
                          PrescriptionItemState.readyForLookup) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppPrimaryButton(
                          label: 'View Medication Information',
                          icon: Icons.info_outline_rounded,
                          expand: true,
                          onPressed: () {
                            final name =
                                prescription
                                    .items[index]
                                    .fields[PrescriptionFieldType
                                        .medicationName]
                                    ?.currentValue ??
                                '';
                            final strength =
                                prescription
                                    .items[index]
                                    .fields[PrescriptionFieldType.strength]
                                    ?.currentValue ??
                                '';
                            final form =
                                prescription
                                    .items[index]
                                    .fields[PrescriptionFieldType.dosageForm]
                                    ?.currentValue ??
                                '';
                            context.push(
                              '/medicine-information/search?query=${Uri.encodeComponent(name)}&strength=${Uri.encodeComponent(strength)}&dosageForm=${Uri.encodeComponent(form)}&autoSearch=true&prescriptionItemId=${prescription.items[index].id}',
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const AppBanner(
                message:
                    'MEDICATION DATABASE INFORMATION and AI EXPLANATION are separate source-backed features. They are not stored as prescription instructions.',
                icon: Icons.fact_check_outlined,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (prescription.pipelineState ==
                  PrescriptionPipelineState.readyForMedicationLookup) ...[
                AppPrimaryButton(
                  label: 'Would you like reminders for this medicine?',
                  icon: Icons.add_alarm_outlined,
                  expand: true,
                  onPressed: () => context.push(
                    '/medications/new?prescriptionId=$prescriptionId',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (prescription.pipelineState !=
                  PrescriptionPipelineState.readyForMedicationLookup)
                AppPrimaryButton(
                  label: 'Continue reviewing prescription',
                  expand: true,
                  onPressed: () =>
                      context.go('/prescriptions/$prescriptionId/review'),
                ),
              const SizedBox(height: AppSpacing.sm),
              AppSecondaryButton(
                label: 'Delete image only',
                icon: Icons.image_not_supported_outlined,
                expand: true,
                onPressed: () => _deleteImages(context, ref),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppDestructiveButton(
                label: 'Delete entire prescription',
                onPressed: () => _deletePrescription(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteImages(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete prescription image?'),
        content: const Text(
          'Structured fields will remain. You will no longer be able to compare them with this image.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete image'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(prescriptionRepositoryProvider)
          .deleteImages(prescriptionId);
      ref.invalidate(prescriptionDetailProvider(prescriptionId));
      ref.invalidate(prescriptionPagesProvider(prescriptionId));
      ref.invalidate(prescriptionHistoryProvider);
    }
  }

  Future<void> _deletePrescription(BuildContext context, WidgetRef ref) async {
    if (await deletePrescriptionWithConfirmation(
          context,
          ref,
          prescriptionId,
        ) &&
        context.mounted) {
      context.go('/prescriptions/history');
    }
  }
}
