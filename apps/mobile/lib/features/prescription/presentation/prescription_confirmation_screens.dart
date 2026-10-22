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
import '../../medications/application/medication_providers.dart';
import 'delete_prescription.dart';

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

class FinalPrescriptionConfirmationScreen extends ConsumerStatefulWidget {
  const FinalPrescriptionConfirmationScreen({
    required this.prescriptionId,
    super.key,
  });
  final String prescriptionId;

  @override
  ConsumerState<FinalPrescriptionConfirmationScreen> createState() =>
      _FinalPrescriptionConfirmationScreenState();
}

class _FinalPrescriptionConfirmationScreenState
    extends ConsumerState<FinalPrescriptionConfirmationScreen> {
  bool _adding = false;
  String get prescriptionId => widget.prescriptionId;

  @override
  Widget build(BuildContext context) {
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
                  const Text('Review these details before adding'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Add the reviewed medicines to your list. Reminders stay off until you choose times.',
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSecondaryButton(
            label: 'Delete prescription',
            icon: Icons.delete_outline_rounded,
            onPressed: _adding
                ? null
                : () async {
                    if (await deletePrescriptionWithConfirmation(
                          context,
                          ref,
                          prescriptionId,
                        ) &&
                        context.mounted) {
                      context.go('/scan');
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppPrimaryButton(
            label: 'Confirm and add to My Medications',
            icon: Icons.check_circle_outline_rounded,
            expand: true,
            loading: _adding,
            onPressed: _adding ? null : _addReviewedMedicines,
          ),
        ],
      ),
    );
  }

  Future<void> _addReviewedMedicines() async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      await ref
          .read(prescriptionWorkflowControllerProvider.notifier)
          .confirmPrescription();
      await ref
          .read(medicationRepositoryProvider)
          .saveConfirmedPrescription(prescriptionId);
      if (mounted) context.go('/medications');
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Check all medicine details before adding them. '
              'Your review is saved; retry if needed.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
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
