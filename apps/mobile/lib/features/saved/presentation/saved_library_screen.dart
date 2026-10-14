import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/states.dart';
import '../../medications/application/medication_providers.dart';
import '../../intelligence/application/intelligence_providers.dart';
import '../../prescription/application/prescription_providers.dart';
import 'saved_terminology_screen.dart';

class SavedLibraryScreen extends ConsumerWidget {
  const SavedLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Saved Library'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Terms'),
            Tab(text: 'Medicines'),
            Tab(text: 'Learning'),
            Tab(text: 'Prescriptions'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          const SavedTerminologyScreen(embedded: true),
          _MedicinesTab(ref: ref),
          const AppEmptyState(
            title: 'Saved learning',
            message: 'Saved lessons use the same local library architecture.',
            icon: Icons.school_outlined,
          ),
          _PrescriptionsTab(ref: ref),
        ],
      ),
    ),
  );
}

class _MedicinesTab extends StatelessWidget {
  const _MedicinesTab({required this.ref});
  final WidgetRef ref;
  @override
  Widget build(BuildContext context) {
    final savedInformation = ref.watch(savedMedicationIdentitiesProvider);
    final plans = ref.watch(medicationPlansProvider).valueOrNull ?? const [];
    return savedInformation.when(
      loading: () => const AppLoadingState(label: 'Loading medicines…'),
      error: (_, _) => AppEmptyState(
        title: 'Saved medicine information unavailable',
        message:
            'Medication plans remain available separately. No cached source-backed medicines were found.',
        icon: Icons.cloud_off_outlined,
        action: AppSecondaryButton(
          label: 'View medication plans',
          onPressed: () => context.push('/medications'),
        ),
      ),
      data: (values) => values.isEmpty
          ? AppEmptyState(
              title: 'No saved medicines',
              message:
                  '${plans.length} medication plan(s) are stored separately. Save trusted medicine information to read it offline here.',
              icon: Icons.medication_outlined,
              action: AppPrimaryButton(
                label: 'Search medicine information',
                onPressed: () => context.push('/medicine-information/search'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                for (final value in values)
                  ListTile(
                    title: Text(value.canonicalName),
                    subtitle: Text(
                      '${value.genericName ?? 'Generic not specified'} • ${value.cacheState}',
                    ),
                    onTap: () =>
                        context.push('/medicine-information/${value.id}'),
                  ),
              ],
            ),
    );
  }
}

class _PrescriptionsTab extends StatelessWidget {
  const _PrescriptionsTab({required this.ref});
  final WidgetRef ref;
  @override
  Widget build(BuildContext context) {
    final history = ref.watch(prescriptionHistoryProvider);
    return history.when(
      loading: () => const AppLoadingState(label: 'Loading prescriptions…'),
      error: (_, _) => const SizedBox.shrink(),
      data: (values) => values.isEmpty
          ? const AppEmptyState(
              title: 'No prescriptions',
              message: 'Your prescription history appears here.',
              icon: Icons.receipt_long_outlined,
            )
          : ListView(
              children: [
                for (final value in values)
                  ListTile(
                    title: Text('${value.itemCount} medicine item(s)'),
                    subtitle: Text(value.pipelineState.name),
                    onTap: () => context.push('/prescriptions/${value.id}'),
                  ),
              ],
            ),
    );
  }
}
