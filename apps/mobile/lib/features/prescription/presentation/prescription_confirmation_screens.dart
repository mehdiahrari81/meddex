import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../application/prescription_workflow_controller.dart';
import '../domain/prescription_models.dart';
import 'prescription_review_screen.dart';

class UnresolvedFieldsReviewScreen extends ConsumerWidget {
  const UnresolvedFieldsReviewScreen({required this.prescriptionId, super.key});
  final String prescriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(prescriptionWorkflowControllerProvider);
    final prescription = state.prescription;
    if (prescription?.id != prescriptionId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(prescriptionWorkflowControllerProvider.notifier)
            .loadDraft(prescriptionId);
      });
      return const Scaffold(
        body: AppLoadingState(label: 'Finding unresolved fields…'),
      );
    }
    final items = prescription!.items
        .where((item) => item.state != PrescriptionItemState.readyForLookup)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Unresolved Fields Review')),
      body: items.isEmpty
          ? const AppEmptyState(
              title: 'No unresolved medicine names',
              message: 'All retained medicine names were confirmed by you.',
              icon: Icons.check_circle_outline_rounded,
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const AppBanner(
                  message:
                      'Missing strength or duration may remain absent. A medicine name must be explicitly confirmed before lookup.',
                ),
                const SizedBox(height: AppSpacing.md),
                for (final item in items)
                  AppCard(
                    onTap: () => context.push(
                      '/prescriptions/$prescriptionId/items/${item.id}/edit',
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item
                                .field(PrescriptionFieldType.medicationName)
                                .currentValue ??
                            'Medicine name unresolved',
                      ),
                      subtitle: Text(item.state.name),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
              ],
            ),
    );
  }
}

class FinalPrescriptionConfirmationScreen extends ConsumerWidget {
  const FinalPrescriptionConfirmationScreen({
    required this.prescriptionId,
    super.key,
  });
  final String prescriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(prescriptionWorkflowControllerProvider);
    final prescription = state.prescription;
    if (prescription?.id != prescriptionId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(prescriptionWorkflowControllerProvider.notifier)
            .loadDraft(prescriptionId);
      });
      return const Scaffold(
        body: AppLoadingState(label: 'Preparing confirmation…'),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/scan'),
        title: const Text('Final Prescription Confirmation'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          const AppBanner(
            message:
                'Confirm only if the information below matches the prescription. This records your review; it does not mean the app medically verified the prescription.',
            icon: Icons.verified_user_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Prescription',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(DateFormat.yMMMd().format(prescription!.captureDate.toLocal())),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < prescription.items.length; index++) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Medicine ${index + 1}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final type in PrescriptionFieldType.values)
                    if (prescription.items[index].fields[type]?.hasValue ??
                        false)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          '${prescriptionFieldLabel(type)}: ${prescription.items[index].fields[type]!.currentValue}',
                        ),
                      ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Verification: confirmed by user'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: 'I confirm this matches my prescription',
            icon: Icons.check_circle_outline_rounded,
            expand: true,
            onPressed: () async {
              try {
                await ref
                    .read(prescriptionWorkflowControllerProvider.notifier)
                    .confirmPrescription();
                if (context.mounted) {
                  context.go('/prescriptions/$prescriptionId/saved');
                }
              } on Object {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Some medicine names still need explicit confirmation.',
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class PrescriptionSavedSummaryScreen extends ConsumerWidget {
  const PrescriptionSavedSummaryScreen({
    required this.prescriptionId,
    super.key,
  });
  final String prescriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      leading: const AppBackButton(fallbackLocation: '/scan'),
      title: const Text('Prescription Saved Summary'),
    ),
    body: AppEmptyState(
      icon: Icons.task_alt_rounded,
      title: 'Verified review saved',
      message:
          'Your structured prescription was saved. Would you like reminders for a confirmed medicine?',
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppPrimaryButton(
            label: 'Find trusted medicine information',
            onPressed: () => context.push('/medicine-information/search'),
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: 'Create medication reminder',
            onPressed: () =>
                context.go('/medications/new?prescriptionId=$prescriptionId'),
          ),
          const SizedBox(height: AppSpacing.md),
          AppSecondaryButton(
            label: 'View prescription detail',
            onPressed: () => context.go('/prescriptions/$prescriptionId'),
          ),
        ],
      ),
    ),
  );
}
