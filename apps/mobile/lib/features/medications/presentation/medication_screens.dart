import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/tts/tts_provider.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/voice/voice_provider.dart';
import '../../../core/voice/voice_service.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../../prescription/application/prescription_providers.dart';
import '../../prescription/domain/prescription_models.dart';
import '../../prescription/presentation/medicine_overview_card.dart';
import '../application/adherence_calculator.dart';
import '../application/medication_export_service.dart';
import '../application/medication_providers.dart';
import '../application/schedule_engine.dart';
import '../application/voice_intent_parser.dart';
import '../domain/medication_models.dart';
import '../domain/dose_history.dart';
import 'delete_medication.dart';

class MyMedicationsScreen extends ConsumerWidget {
  const MyMedicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(medicationPlansProvider);
    final history = ref.watch(medicationDoseHistoryProvider(null));
    final latestByPlan = <String, DoseEvent>{};
    for (final event in currentDoseEvents(history.valueOrNull ?? const [])) {
      latestByPlan.putIfAbsent(event.medicationPlanId, () => event);
    }
    final hideDetails =
        ref.watch(medicationPrivacyProvider).valueOrNull?.hideMedicineDetails ??
        false;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('My Medications'),
        actions: [
          IconButton(
            tooltip: 'Voice assistant',
            onPressed: () => context.push('/medications/voice'),
            icon: const Icon(Icons.mic_outlined),
          ),
          IconButton(
            tooltip: 'Completed medication archive',
            onPressed: () => context.push('/medications/archive'),
            icon: const Icon(Icons.archive_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/medications/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add medication'),
      ),
      body: plans.when(
        loading: () => const AppLoadingState(label: 'Loading medications…'),
        error: (_, _) => AppFullScreenError(
          title: 'Could not load medications',
          message: 'Your saved data is still on this device.',
          retryLabel: 'Try again',
          onRetry: () => ref.invalidate(medicationPlansProvider),
        ),
        data: (values) {
          final visible = values
              .where(
                (item) => item.medication.status != MedicationStatus.archived,
              )
              .toList();
          if (visible.isEmpty) {
            return const AppEmptyState(
              icon: Icons.medication_outlined,
              title: 'No medications saved',
              message:
                  'Add one manually or create it from a prescription you have confirmed.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              96,
            ),
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final details = visible[index];
              return AppCard(
                onTap: () => context.push('/medications/${details.plan.id}'),
                semanticLabel:
                    '${details.medication.displayName}. ${details.medication.status.name}.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hideDetails
                                ? 'Medication details hidden'
                                : details.medication.displayName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        _StatusChip(status: details.medication.status),
                        IconButton(
                          key: ValueKey(
                            'delete-medication-${details.medication.id}',
                          ),
                          tooltip: 'Delete medication',
                          color: Theme.of(context).colorScheme.error,
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => deleteMedicationWithConfirmation(
                            context,
                            ref,
                            details,
                            hideDetails: hideDetails,
                          ),
                        ),
                      ],
                    ),
                    if (!hideDetails && details.medication.strength != null)
                      Text(details.medication.strength!),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      hideDetails
                          ? 'Open privacy settings to show medicine information.'
                          : details.source.confirmedInstruction,
                    ),
                    if (!hideDetails &&
                        latestByPlan[details.plan.id] != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _datedDoseLabel(latestByPlan[details.plan.id]!),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    TextButton.icon(
                      onPressed: () => context.push(
                        '/medications/${details.plan.id}/history',
                      ),
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('Dose history'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        Chip(
                          label: Text(_sourceLabel(details.source.sourceType)),
                        ),
                        Chip(
                          label: Text(
                            details.medication.informationStatus ==
                                    MedicineInformationStatus.verified
                                ? 'Medicine information verified'
                                : 'View medicine explanation',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CreateMedicationPlanScreen extends ConsumerStatefulWidget {
  const CreateMedicationPlanScreen({super.key, this.prescriptionId});
  final String? prescriptionId;

  @override
  ConsumerState<CreateMedicationPlanScreen> createState() =>
      _CreateMedicationPlanScreenState();
}

class _CreateMedicationPlanScreenState
    extends ConsumerState<CreateMedicationPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _strength = TextEditingController();
  final _dose = TextEditingController();
  final _frequency = TextEditingController();
  final _duration = TextEditingController();
  final _instruction = TextEditingController();
  final _times = <TimeOfDay>[const TimeOfDay(hour: 8, minute: 0)];
  MedicationSourceType _source = MedicationSourceType.manualEntry;
  MedicationScheduleType _type = MedicationScheduleType.onceDaily;
  PrescriptionItem? _prescriptionItem;
  DateTime _start = DateTime.now();
  DateTime? _end;
  Set<int> _weekdays = {};
  bool _saving = false;
  int _intervalHours = 8;

  @override
  void initState() {
    super.initState();
    if (widget.prescriptionId != null) {
      _source = MedicationSourceType.confirmedPrescription;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrescription());
    }
  }

  Future<void> _loadPrescription() async {
    final prescription = await ref.read(
      prescriptionDetailProvider(widget.prescriptionId!).future,
    );
    if (prescription == null || !mounted) return;
    final items = prescription.items
        .where((item) => item.state == PrescriptionItemState.readyForLookup)
        .toList();
    if (items.isNotEmpty) _selectItem(items.first);
  }

  void _selectItem(PrescriptionItem item) {
    setState(() {
      _prescriptionItem = item;
      _name.text =
          item.field(PrescriptionFieldType.medicationName).currentValue ?? '';
      _strength.text =
          item.field(PrescriptionFieldType.strength).currentValue ?? '';
      _dose.text = item.field(PrescriptionFieldType.dose).currentValue ?? '';
      _frequency.text =
          item.field(PrescriptionFieldType.frequency).currentValue ??
          item.frequency?.rawText ??
          '';
      _duration.text =
          item.field(PrescriptionFieldType.duration).currentValue ??
          item.duration?.rawText ??
          '';
      _instruction.text =
          item.field(PrescriptionFieldType.instructions).currentValue ??
          item.sourceText;
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _strength,
      _dose,
      _frequency,
      _duration,
      _instruction,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prescription = widget.prescriptionId == null
        ? null
        : ref
              .watch(prescriptionDetailProvider(widget.prescriptionId!))
              .valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Reminder')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const _SafetyBanner(),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<MedicationSourceType>(
              segments: const [
                ButtonSegment(
                  value: MedicationSourceType.manualEntry,
                  label: Text('Manual'),
                  icon: Icon(Icons.edit_outlined),
                ),
                ButtonSegment(
                  value: MedicationSourceType.confirmedPrescription,
                  label: Text('Confirmed prescription'),
                  icon: Icon(Icons.receipt_long_outlined),
                ),
              ],
              selected: {_source},
              onSelectionChanged: (value) =>
                  setState(() => _source = value.single),
            ),
            if (_source == MedicationSourceType.confirmedPrescription) ...[
              const SizedBox(height: AppSpacing.md),
              if (prescription == null)
                const Text('Open this screen from a confirmed prescription.')
              else
                DropdownButtonFormField<PrescriptionItem>(
                  initialValue: _prescriptionItem,
                  decoration: const InputDecoration(
                    labelText: 'Confirmed medicine',
                  ),
                  items: prescription.items
                      .where(
                        (item) =>
                            item.state == PrescriptionItemState.readyForLookup,
                      )
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            item
                                    .field(PrescriptionFieldType.medicationName)
                                    .currentValue ??
                                'Confirmed medicine',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) _selectItem(value);
                  },
                ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Medicine name'),
              readOnly: _source == MedicationSourceType.confirmedPrescription,
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _strength,
              decoration: const InputDecoration(
                labelText: 'Strength (optional)',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _instruction,
              minLines: 2,
              maxLines: 4,
              readOnly: _source == MedicationSourceType.confirmedPrescription,
              decoration: const InputDecoration(
                labelText: 'Confirmed prescription instruction',
                helperText: 'This source reference is preserved separately.',
              ),
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _dose,
              decoration: const InputDecoration(
                labelText: 'User-confirmed dose text',
              ),
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _frequency,
              decoration: const InputDecoration(
                labelText: 'User-confirmed frequency',
              ),
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _duration,
              decoration: const InputDecoration(
                labelText: 'Confirmed duration (optional)',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Reminder schedule',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Choose reminder times yourself. They organize your confirmed instruction; they are not new medical instructions.',
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<MedicationScheduleType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Schedule type'),
              items: MedicationScheduleType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(_scheduleLabel(type)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _type = value!;
                if (_type == MedicationScheduleType.asNeeded) _times.clear();
                if (_type != MedicationScheduleType.asNeeded &&
                    _type != MedicationScheduleType.everyNHours &&
                    _times.isEmpty) {
                  _times.add(const TimeOfDay(hour: 8, minute: 0));
                }
              }),
            ),
            if (_type == MedicationScheduleType.everyNHours) ...[
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<int>(
                initialValue: _intervalHours,
                decoration: const InputDecoration(
                  labelText: 'Confirmed interval',
                ),
                items: [4, 6, 8, 12, 24]
                    .map(
                      (hours) => DropdownMenuItem(
                        value: hours,
                        child: Text('Every $hours hours'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _intervalHours = value!),
              ),
            ] else if (_type == MedicationScheduleType.selectedWeekdays ||
                _type == MedicationScheduleType.specificDays) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final day in const [
                    (DateTime.monday, 'Mon'),
                    (DateTime.tuesday, 'Tue'),
                    (DateTime.wednesday, 'Wed'),
                    (DateTime.thursday, 'Thu'),
                    (DateTime.friday, 'Fri'),
                    (DateTime.saturday, 'Sat'),
                    (DateTime.sunday, 'Sun'),
                  ])
                    FilterChip(
                      label: Text(day.$2),
                      selected: _weekdays.contains(day.$1),
                      onSelected: (selected) => setState(() {
                        _weekdays = {..._weekdays};
                        selected
                            ? _weekdays.add(day.$1)
                            : _weekdays.remove(day.$1);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ..._timePickerWidgets(),
            ] else if (_type == MedicationScheduleType.asNeeded) ...[
              const SizedBox(height: AppSpacing.sm),
              const AppBanner(
                message:
                    'Medicine available as needed. No fixed dose notifications will be created.',
                icon: Icons.info_outline_rounded,
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.sm),
              ..._timePickerWidgets(),
            ],
            const SizedBox(height: AppSpacing.md),
            ListTile(
              title: const Text('Start date'),
              subtitle: Text(DateFormat.yMMMd().format(_start)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => _pickDate(isEnd: false),
            ),
            ListTile(
              title: const Text('End date (optional)'),
              subtitle: Text(
                _end == null ? 'Not set' : DateFormat.yMMMd().format(_end!),
              ),
              trailing: const Icon(Icons.event_available_outlined),
              onTap: () => _pickDate(isEnd: true),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(_saving ? 'Saving…' : 'Create medication plan'),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value?.trim().isEmpty ?? true ? 'Required' : null;

  Future<void> _pickTime(int index) async {
    final value = await showTimePicker(
      context: context,
      initialTime: _times[index],
    );
    if (value != null) setState(() => _times[index] = value);
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: isEnd ? (_end ?? _start) : _start,
    );
    if (value != null) setState(() => isEnd ? _end = value : _start = value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_source == MedicationSourceType.confirmedPrescription &&
        _prescriptionItem == null) {
      _message('Choose a user-confirmed prescription medicine.');
      return;
    }
    setState(() => _saving = true);
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      final request = CreateMedicationPlanRequest(
        sourceType: _source,
        prescriptionItemId: _prescriptionItem?.id,
        displayName: _name.text,
        strength: _strength.text,
        confirmedDoseText: _dose.text,
        confirmedFrequency: _frequency.text,
        confirmedDuration: _duration.text,
        rawPrescriptionInstruction:
            _source == MedicationSourceType.confirmedPrescription
            ? _prescriptionItem?.sourceText
            : null,
        confirmedInstruction: _instruction.text,
        startDate: _start,
        endDate: _end,
        instructions: _instruction.text,
        timezone: timezone.identifier,
        scheduleType: _type,
        reminderTimes: _times
            .map((value) => value.hour * 60 + value.minute)
            .toList(),
        weekdays: _weekdays,
        intervalHours: _type == MedicationScheduleType.everyNHours
            ? _intervalHours
            : null,
        intervalAnchor: _type == MedicationScheduleType.everyNHours
            ? DateTime(
                _start.year,
                _start.month,
                _start.day,
                _times.isEmpty ? 8 : _times.first.hour,
                _times.isEmpty ? 0 : _times.first.minute,
              )
            : null,
        asNeeded: _type == MedicationScheduleType.asNeeded,
      );
      final details = await ref
          .read(medicationRepositoryProvider)
          .createPlan(request);
      if (!request.asNeeded) {
        final permissions = ref.read(notificationPermissionProvider);
        final currentPermission = await permissions.status();
        final permission =
            currentPermission == NotificationPermissionState.denied
            ? await permissions.request()
            : currentPermission;
        if (permission == NotificationPermissionState.granted && mounted) {
          await _rebuildMedicationReminders(ref);
        } else if (permission ==
            NotificationPermissionState.permanentlyDenied) {
          _message(
            'Notifications are blocked. Enable them in system settings when you want local reminders.',
          );
        } else {
          _message(
            'The medication plan was saved without notifications. You can enable them later in system settings.',
          );
        }
      }
      ref.invalidate(medicationPlansProvider);
      if (mounted) context.pushReplacement('/medications/${details.plan.id}');
    } on Object catch (error) {
      _message(error.toString().replaceFirst('StateError: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<Widget> _timePickerWidgets() => [
    for (var index = 0; index < _times.length; index++)
      ListTile(
        title: Text(_times[index].format(context)),
        leading: const Icon(Icons.alarm_outlined),
        trailing: IconButton(
          tooltip: 'Remove time',
          onPressed: _times.length == 1
              ? null
              : () => setState(() => _times.removeAt(index)),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        onTap: () => _pickTime(index),
      ),
    TextButton.icon(
      onPressed: () async {
        final value = await showTimePicker(
          context: context,
          initialTime: const TimeOfDay(hour: 8, minute: 0),
        );
        if (value != null) setState(() => _times.add(value));
      },
      icon: const Icon(Icons.add_alarm_outlined),
      label: const Text('Add reminder time'),
    ),
  ];
}

class MedicationPlanDetailScreen extends ConsumerWidget {
  const MedicationPlanDetailScreen({required this.planId, super.key});
  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(medicationPlanProvider(planId));
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/medications'),
        title: const Text('Medication Plan Detail'),
      ),
      body: details.when(
        loading: () => const AppLoadingState(label: 'Loading plan…'),
        error: (_, _) => const AppEmptyState(
          title: 'Plan unavailable',
          message: 'The medication plan could not be opened.',
          icon: Icons.error_outline_rounded,
        ),
        data: (value) {
          if (value == null) {
            return const AppEmptyState(
              title: 'Plan not found',
              message: 'It may have been deleted.',
              icon: Icons.search_off_rounded,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                value.medication.displayName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (value.medication.strength != null)
                Text(value.medication.strength!),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: PrescriptionMedicineOverview(
                  query: (
                    name: value.medication.displayName,
                    strength: value.medication.strength,
                    form: value.medication.dosageForm,
                    language:
                        Localizations.localeOf(context).languageCode == 'ur'
                        ? 'ur'
                        : 'en',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('ORIGINAL PRESCRIPTION / USER-CONFIRMED SOURCE'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value.source.confirmedInstruction),
                    if (value.source.rawPrescriptionInstruction != null) ...[
                      const Divider(),
                      Text(
                        'Raw source: ${value.source.rawPrescriptionInstruction}',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('REMINDER SCHEDULE'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dose: ${value.plan.confirmedDoseText.isEmpty ? 'Not written' : value.plan.confirmedDoseText}',
                    ),
                    Text(
                      'Frequency: ${value.plan.confirmedFrequency.isEmpty ? 'Not written' : value.plan.confirmedFrequency}',
                    ),
                    Text('Timezone: ${value.plan.timezone}'),
                    for (final schedule in value.schedules)
                      Text(_scheduleSummary(schedule, context)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.push('/medications/$planId/edit'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Set reminder'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await ref
                            .read(medicationRepositoryProvider)
                            .setPlanActive(planId, !value.plan.active);
                        await _rebuildMedicationReminders(ref);
                        ref.invalidate(medicationPlanProvider(planId));
                      } on Object {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Confirm dose instructions and set reminder times first.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    icon: Icon(
                      value.plan.active ? Icons.pause : Icons.play_arrow,
                    ),
                    label: Text(value.plan.active ? 'Pause' : 'Resume'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/terms/search?query=${Uri.encodeQueryComponent(value.medication.displayName)}',
                    ),
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Understand terminology'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/medications/$planId/history'),
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('Dose history'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/medications/$planId/notes'),
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Personal notes'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/medications/$planId/refill'),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Refill reminder'),
                  ),
                  _MedicationTtsControls(details: value),
                  OutlinedButton.icon(
                    onPressed: () => _changeMedicationStatus(
                      context,
                      ref,
                      value,
                      MedicationStatus.completed,
                    ),
                    icon: const Icon(Icons.task_alt_outlined),
                    label: const Text('Mark schedule completed'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _changeMedicationStatus(
                      context,
                      ref,
                      value,
                      MedicationStatus.archived,
                    ),
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Archive'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _deleteMedicationPlan(context, ref, value),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete medication'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const AppBanner(
                message:
                    'If a dose was not recorded as taken, check your medicine instructions or ask your pharmacist/doctor if you are unsure what to do. Do not double a dose based on this app.',
                icon: Icons.shield_outlined,
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _changeMedicationStatus(
  BuildContext context,
  WidgetRef ref,
  MedicationPlanDetails details,
  MedicationStatus status,
) async {
  final label = status == MedicationStatus.completed ? 'completed' : 'archived';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Mark saved schedule $label?'),
      content: Text(
        'This stops its reminders. It records only how you organized this saved plan; it does not say a clinician ended the medicine.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            status == MedicationStatus.completed ? 'Complete' : 'Archive',
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref
      .read(medicationRepositoryProvider)
      .setMedicationStatus(details.medication.id, status);
  await _rebuildMedicationReminders(ref);
  ref.invalidate(medicationPlansProvider);
  if (context.mounted) context.go('/medications');
}

Future<void> _deleteMedicationPlan(
  BuildContext context,
  WidgetRef ref,
  MedicationPlanDetails details,
) async {
  if (await deleteMedicationWithConfirmation(context, ref, details) &&
      context.mounted) {
    context.go('/medications');
  }
}

class _MedicationTtsControls extends ConsumerStatefulWidget {
  const _MedicationTtsControls({required this.details});
  final MedicationPlanDetails details;

  @override
  ConsumerState<_MedicationTtsControls> createState() =>
      _MedicationTtsControlsState();
}

class _MedicationTtsControlsState
    extends ConsumerState<_MedicationTtsControls> {
  double _speed = 0.43;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Read aloud controls',
    onSelected: (action) async {
      final tts = ref.read(textToSpeechProvider);
      switch (action) {
        case 'play':
          await tts.speak(
            '${widget.details.medication.displayName}. ${widget.details.source.confirmedInstruction}',
            locale: Localizations.localeOf(context).languageCode,
          );
        case 'pause':
          await tts.pause();
        case 'resume':
          await tts.resume();
        case 'stop':
          await tts.stop();
        case 'slower':
          setState(() => _speed = (_speed - 0.08).clamp(0.25, 0.75));
          await tts.setSpeed(_speed);
        case 'faster':
          setState(() => _speed = (_speed + 0.08).clamp(0.25, 0.75));
          await tts.setSpeed(_speed);
      }
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'play', child: Text('Play / read aloud')),
      const PopupMenuItem(value: 'pause', child: Text('Pause')),
      const PopupMenuItem(value: 'resume', child: Text('Resume')),
      const PopupMenuItem(value: 'stop', child: Text('Stop')),
      PopupMenuItem(
        value: 'slower',
        child: Text('Slower (current ${_speed.toStringAsFixed(2)}×)'),
      ),
      PopupMenuItem(
        value: 'faster',
        child: Text('Faster (current ${_speed.toStringAsFixed(2)}×)'),
      ),
    ],
    child: const Chip(
      avatar: Icon(Icons.volume_up_outlined),
      label: Text('Read aloud controls'),
    ),
  );
}

class EditReminderScreen extends ConsumerWidget {
  const EditReminderScreen({required this.planId, super.key});
  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(medicationPlanProvider(planId));
    return Scaffold(
      appBar: AppBar(title: const Text('Set Reminder')),
      body: details.when(
        loading: () => const AppLoadingState(label: 'Loading reminder…'),
        error: (_, _) => const SizedBox.shrink(),
        data: (value) => value == null
            ? const SizedBox.shrink()
            : _EditReminderForm(details: value),
      ),
    );
  }
}

class _EditReminderForm extends ConsumerStatefulWidget {
  const _EditReminderForm({required this.details});
  final MedicationPlanDetails details;
  @override
  ConsumerState<_EditReminderForm> createState() => _EditReminderFormState();
}

class _EditReminderFormState extends ConsumerState<_EditReminderForm> {
  late final List<TimeOfDay> _times;
  late final MedicationSchedule? _schedule;
  late String _timezone;
  bool _loadingTimezone = false;
  bool _timezoneUnavailable = false;
  bool _saving = false;

  bool get _asNeeded =>
      _schedule?.asNeeded == true ||
      _schedule?.type == MedicationScheduleType.asNeeded;
  bool get _interval => _schedule?.type == MedicationScheduleType.everyNHours;
  bool get _hasInstructions =>
      widget.details.plan.confirmedDoseText.trim().isNotEmpty &&
      widget.details.plan.confirmedFrequency.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _schedule = widget.details.schedules.firstOrNull;
    _timezone = widget.details.plan.timezone;
    _times = widget.details.schedules
        .expand((schedule) => schedule.times)
        .map((minutes) => TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60))
        .toList();
    if (_interval && _schedule?.intervalAnchor != null) {
      final anchor = tz.TZDateTime.from(
        _schedule!.intervalAnchor!,
        (_timezone == 'UTC' ? tz.UTC : tz.getLocation(_timezone)),
      );
      _times
        ..clear()
        ..add(TimeOfDay(hour: anchor.hour, minute: anchor.minute));
    } else if (!_asNeeded && _times.isEmpty) {
      _times.add(const TimeOfDay(hour: 8, minute: 0));
      if (!widget.details.plan.active) {
        // A medicine saved from a scan has no reminder timezone yet. Choose
        // the device zone before its first schedule, and show it explicitly.
        _loadingTimezone = true;
        _loadInitialTimezone();
      }
    }
  }

  Future<void> _loadInitialTimezone() async {
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      if (local.identifier != 'UTC') tz.getLocation(local.identifier);
      if (mounted) {
        setState(() {
          _timezone = local.identifier;
          _timezoneUnavailable = false;
          _loadingTimezone = false;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _timezoneUnavailable = true;
          _loadingTimezone = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving ||
        !_hasInstructions ||
        _loadingTimezone ||
        _timezoneUnavailable) {
      return;
    }
    setState(() => _saving = true);
    try {
      DateTime? anchor = _schedule?.intervalAnchor;
      if (_interval && anchor != null) {
        final location = (_timezone == 'UTC'
            ? tz.UTC
            : tz.getLocation(_timezone));
        final original = tz.TZDateTime.from(anchor, location);
        anchor = tz.TZDateTime(
          location,
          original.year,
          original.month,
          original.day,
          _times.single.hour,
          _times.single.minute,
        ).toUtc();
      }
      await ref
          .read(medicationRepositoryProvider)
          .replaceSchedule(
            widget.details.plan.id,
            type: _schedule?.type ?? MedicationScheduleType.custom,
            reminderTimes: _asNeeded || _interval
                ? const []
                : _times.map((time) => time.hour * 60 + time.minute).toList(),
            weekdays: _schedule?.weekdays ?? const {},
            intervalHours: _schedule?.intervalHours,
            intervalAnchor: anchor,
            asNeeded: _asNeeded,
            timezone: _timezone,
            activate: true,
          );
      ref.invalidate(medicationPlanProvider(widget.details.plan.id));
      try {
        await _rebuildMedicationReminders(ref);
      } on Object {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Reminder times saved. Notifications could not be updated; check notification settings.',
              ),
            ),
          );
        }
      }
      if (mounted) context.pop();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save reminder times. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.md),
    children: [
      const AppBanner(
        message:
            'Changing reminder times does not change the original prescription instruction.',
        icon: Icons.lock_outline_rounded,
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        _asNeeded
            ? 'As needed · no fixed reminders'
            : _scheduleLabel(_schedule?.type ?? MedicationScheduleType.custom),
      ),
      if (_schedule?.weekdays.isNotEmpty ?? false)
        Text(
          'Days: ${_schedule!.weekdays.map((day) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1]).join(', ')}',
        ),
      if (_interval)
        Text(
          'Every ${_schedule?.intervalHours} hours from the chosen start time',
        ),
      Text(
        _loadingTimezone ? 'Reading device timezone…' : 'Timezone: $_timezone',
      ),
      if (_timezoneUnavailable)
        TextButton(
          onPressed: () {
            setState(() => _loadingTimezone = true);
            _loadInitialTimezone();
          },
          child: const Text('Could not read device timezone. Retry'),
        ),
      if (!_hasInstructions)
        const AppBanner(
          message:
              'A reminder needs a confirmed dose and frequency. Check the prescription before creating a reminder. This medicine remains saved.',
          icon: Icons.info_outline_rounded,
        ),
      for (var index = 0; !_asNeeded && index < _times.length; index++)
        ListTile(
          title: Text(_times[index].format(context)),
          leading: const Icon(Icons.alarm_outlined),
          onTap: _saving
              ? null
              : () async {
                  final value = await showTimePicker(
                    context: context,
                    initialTime: _times[index],
                  );
                  if (value != null && mounted) {
                    setState(() => _times[index] = value);
                  }
                },
        ),
      FilledButton(
        onPressed:
            _saving ||
                !_hasInstructions ||
                _loadingTimezone ||
                _timezoneUnavailable
            ? null
            : _save,
        child: Text(_saving ? 'Saving…' : 'Save reminder times'),
      ),
    ],
  );
}

class TodayMedicationTimelineScreen extends ConsumerWidget {
  const TodayMedicationTimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(medicationPlansProvider);
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Medication Timeline")),
      body: plans.when(
        loading: () => const AppLoadingState(label: 'Building timeline…'),
        error: (_, _) => const SizedBox.shrink(),
        data: (values) => _TimelineList(plans: values),
      ),
    );
  }
}

class _TimelineList extends ConsumerWidget {
  const _TimelineList({required this.plans});
  final List<MedicationPlanDetails> plans;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toUtc();
    final end = start.add(const Duration(days: 1));
    const engine = ScheduleEngine();
    final events = {
      for (final event in currentDoseEvents(
        ref.watch(medicationDoseHistoryProvider(null)).valueOrNull ?? const [],
      ))
        event.logicalDoseId: event,
    };
    final doses = <ScheduledDose>[];
    for (final details in plans) {
      for (final schedule in details.schedules) {
        for (final time in engine.occurrences(
          plan: details.plan,
          schedule: schedule,
          from: start,
          to: end,
        )) {
          doses.add(
            ScheduledDose(
              logicalDoseId: engine.logicalDoseId(details.plan.id, time),
              planId: details.plan.id,
              medicationName: details.medication.displayName,
              doseText: details.plan.confirmedDoseText,
              scheduledAt: time,
              action:
                  events[engine.logicalDoseId(details.plan.id, time)]?.action ??
                  DoseAction.notRecorded,
              recordedAt: events[engine.logicalDoseId(details.plan.id, time)]
                  ?.recordedAt,
              eventId: events[engine.logicalDoseId(details.plan.id, time)]?.id,
            ),
          );
        }
      }
    }
    doses.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    if (doses.isEmpty) {
      return const AppEmptyState(
        title: 'No fixed reminders today',
        message: 'As-needed medicines do not appear as scheduled doses.',
        icon: Icons.event_available_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: doses.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final dose = doses[index];
        return _DoseTimelineRow(key: ValueKey(dose.logicalDoseId), dose: dose);
      },
    );
  }
}

String _datedDoseLabel(DoseEvent event) =>
    '${_doseLabel(event.action)} • ${DateFormat.yMMMd().add_jm().format(event.recordedAt.toLocal())}';

class _DoseTimelineRow extends ConsumerStatefulWidget {
  const _DoseTimelineRow({required this.dose, super.key});
  final ScheduledDose dose;
  @override
  ConsumerState<_DoseTimelineRow> createState() => _DoseTimelineRowState();
}

class _DoseTimelineRowState extends ConsumerState<_DoseTimelineRow> {
  bool _saving = false;

  Future<void> _record(DoseAction action) async {
    if (_saving) return;
    setState(() => _saving = true);
    final dose = widget.dose;
    final repository = ref.read(medicationRepositoryProvider);
    try {
      await repository.recordDose(
        planId: dose.planId,
        logicalDoseId: dose.logicalDoseId,
        scheduledAt: dose.scheduledAt,
        action: action,
        source: DoseEventSource.app,
      );
      if (mounted) {
        ref.invalidate(medicationActivityProvider);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                '${dose.medicationName}: ${_doseLabel(action).toLowerCase()} recorded',
              ),
            ),
          );
      }
      // Notification availability must never prevent local dose recording.
      if (mounted) {
        unawaited(() async {
          try {
            await ref
                .read(medicationReminderServiceProvider)
                .cancelDose(dose.logicalDoseId);
          } on Object catch (error) {
            AppLogger().log(
              LogLevel.warning,
              'dose_notification_cancel_failed',
              fields: {'error_type': error.runtimeType.toString()},
            );
          }
        }());
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not record this dose. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dose = widget.dose;
    final recorded = doseWasRecorded(dose.action);
    return ListTile(
      leading: Text(DateFormat.jm().format(dose.scheduledAt.toLocal())),
      title: Text(dose.medicationName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dose.doseText),
          if (recorded && dose.recordedAt != null)
            Text(
              '${_doseLabel(dose.action)} • ${DateFormat.yMMMd().add_jm().format(dose.recordedAt!.toLocal())}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
        ],
      ),
      trailing: _saving
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!recorded)
                  IconButton(
                    tooltip: 'Snooze',
                    onPressed: () => _chooseSnooze(context, ref, dose),
                    icon: const Icon(Icons.snooze_rounded),
                  ),
                PopupMenuButton<DoseAction>(
                  tooltip: 'Record dose',
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: DoseAction.taken,
                      child: Text('Taken'),
                    ),
                    PopupMenuItem(
                      value: DoseAction.skipped,
                      child: Text('Skip'),
                    ),
                  ],
                  onSelected: _record,
                ),
              ],
            ),
    );
  }
}

Future<void> _chooseSnooze(
  BuildContext context,
  WidgetRef ref,
  ScheduledDose dose,
) async {
  final duration = await showModalBottomSheet<Duration>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text('Snooze reminder'),
            subtitle: Text(
              'This changes notification timing only. It does not change the prescribed dose or frequency.',
            ),
          ),
          for (final minutes in const [5, 10, 15, 30, 60, 120])
            ListTile(
              title: Text(
                minutes < 60
                    ? '$minutes minutes'
                    : '${minutes ~/ 60} hour${minutes == 60 ? '' : 's'}',
              ),
              onTap: () => Navigator.pop(context, Duration(minutes: minutes)),
            ),
        ],
      ),
    ),
  );
  if (duration == null) return;
  final details = await ref
      .read(medicationRepositoryProvider)
      .getPlan(dose.planId);
  if (details == null) return;
  await ref
      .read(medicationReminderServiceProvider)
      .snooze(details: details, dose: dose, duration: duration);
}

Future<void> _rebuildMedicationReminders(WidgetRef ref) async {
  final permission = await ref.read(notificationPermissionProvider).status();
  if (permission != NotificationPermissionState.granted) return;
  final plans = await ref.read(medicationRepositoryProvider).watchPlans().first;
  await ref.read(medicationReminderServiceProvider).rebuild(plans: plans);
}

class DoseHistoryScreen extends ConsumerWidget {
  const DoseHistoryScreen({super.key, this.planId});
  final String? planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(medicationDoseHistoryProvider(planId));
    return Scaffold(
      appBar: AppBar(title: const Text('Dose History')),
      floatingActionButton: planId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _manual(context, ref),
              icon: const Icon(Icons.add_task_outlined),
              label: const Text('I took this medicine'),
            ),
      body: history.when(
        loading: () => const AppLoadingState(label: 'Loading dose history…'),
        error: (_, _) => AppFullScreenError(
          title: 'Dose history unavailable',
          message: 'Your saved medication is still on this device.',
          retryLabel: 'Try again',
          onRetry: () => ref.invalidate(medicationDoseHistoryProvider(planId)),
        ),
        data: (history) {
          final values = currentDoseEvents(history);
          return values.isEmpty
              ? const AppEmptyState(
                  title: 'No dose entries',
                  message:
                      'Opening a notification does not count as taking a dose.',
                  icon: Icons.history_toggle_off_rounded,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: values.length,
                  itemBuilder: (context, index) {
                    final event = values[index];
                    return ListTile(
                      leading: Icon(
                        event.action == DoseAction.taken
                            ? Icons.check_circle_outline
                            : event.action == DoseAction.skipped
                            ? Icons.remove_circle_outline
                            : Icons.schedule_outlined,
                      ),
                      title: Text(_doseLabel(event.action)),
                      subtitle: Text(
                        '${DateFormat.yMMMd().add_jm().format(event.recordedAt.toLocal())}${event.supersedesEventId != null ? ' • Updated entry' : ''}',
                      ),
                      trailing: PopupMenuButton<DoseAction>(
                        tooltip: 'Correct entry',
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: DoseAction.taken,
                            child: Text('Correct to Taken'),
                          ),
                          PopupMenuItem(
                            value: DoseAction.skipped,
                            child: Text('Correct to Skipped'),
                          ),
                        ],
                        onSelected: (action) async {
                          try {
                            await ref
                                .read(medicationRepositoryProvider)
                                .correctDose(eventId: event.id, action: action);
                          } on Object {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not update this dose. Please retry.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    );
                  },
                );
        },
      ),
    );
  }

  Future<void> _manual(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now().toUtc();
    await ref
        .read(medicationRepositoryProvider)
        .recordDose(
          planId: planId!,
          logicalDoseId: 'manual:$planId:${now.toIso8601String()}',
          scheduledAt: null,
          action: DoseAction.taken,
          source: DoseEventSource.manualEntry,
        );
    ref.invalidate(medicationDoseHistoryProvider(planId));
  }
}

class MedicationCalendarScreen extends ConsumerStatefulWidget {
  const MedicationCalendarScreen({super.key});
  @override
  ConsumerState<MedicationCalendarScreen> createState() =>
      _MedicationCalendarScreenState();
}

class _MedicationCalendarScreenState
    extends ConsumerState<MedicationCalendarScreen> {
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_selected.year, _selected.month, 1);
    final days = DateUtils.getDaysInMonth(_selected.year, _selected.month);
    final history =
        ref.watch(medicationDoseHistoryProvider(null)).valueOrNull ?? [];
    final selectedEvents = currentDoseEvents(history).where((event) {
      final date = (event.scheduledAt ?? event.recordedAt).toLocal();
      return DateUtils.isSameDay(date, _selected);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Medication Calendar')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => setState(
                  () => _selected = DateTime(
                    _selected.year,
                    _selected.month - 1,
                    1,
                  ),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                DateFormat.yMMMM().format(_selected),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => setState(
                  () => _selected = DateTime(
                    _selected.year,
                    _selected.month + 1,
                    1,
                  ),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemCount: first.weekday - 1 + days,
            itemBuilder: (context, index) {
              if (index < first.weekday - 1) return const SizedBox.shrink();
              final day = index - first.weekday + 2;
              final date = DateTime(first.year, first.month, day);
              final selected = DateUtils.isSameDay(date, _selected);
              return Semantics(
                selected: selected,
                label: DateFormat.yMMMMd().format(date),
                child: InkWell(
                  onTap: () => setState(() => _selected = date),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text('$day')),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            DateFormat.yMMMMd().format(_selected),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (selectedEvents.isEmpty)
            const Text('No dose entries recorded for this date.')
          else
            for (final event in selectedEvents)
              ListTile(
                title: Text(_doseLabel(event.action)),
                subtitle: Text(
                  DateFormat.jm().format(event.recordedAt.toLocal()),
                ),
              ),
        ],
      ),
    );
  }
}

class AdherenceSummaryScreen extends ConsumerWidget {
  const AdherenceSummaryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(medicationDoseHistoryProvider(null));
    final plans = ref.watch(medicationPlansProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Adherence Summary')),
      body: events.when(
        loading: () => const AppLoadingState(label: 'Calculating summary…'),
        error: (_, _) => const SizedBox.shrink(),
        data: (eventValues) => plans.when(
          loading: () => const AppLoadingState(label: 'Loading plans…'),
          error: (_, _) => const SizedBox.shrink(),
          data: (planValues) {
            final now = DateTime.now().toUtc();
            final from = now.subtract(const Duration(days: 7));
            const engine = ScheduleEngine();
            final scheduled = <ScheduledDose>[];
            for (final details in planValues) {
              for (final schedule in details.schedules) {
                for (final time in engine.occurrences(
                  plan: details.plan,
                  schedule: schedule,
                  from: from,
                  to: now,
                )) {
                  scheduled.add(
                    ScheduledDose(
                      logicalDoseId: engine.logicalDoseId(
                        details.plan.id,
                        time,
                      ),
                      planId: details.plan.id,
                      medicationName: details.medication.displayName,
                      doseText: details.plan.confirmedDoseText,
                      scheduledAt: time,
                      action: DoseAction.notRecorded,
                    ),
                  );
                }
              }
            }
            final summary = const AdherenceCalculator().calculate(
              scheduled: scheduled,
              events: eventValues,
            );
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  'Past 7 days',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                if (summary.takenPercentage case final percentage?)
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                Text(
                  '${summary.takenCount} of ${summary.scheduledCount} scheduled doses marked taken.',
                ),
                const Divider(),
                Text('Skipped: ${summary.skippedCount}'),
                Text('Not recorded: ${summary.unrecordedCount}'),
                Text('Manual entries: ${summary.manualCount}'),
                const SizedBox(height: AppSpacing.md),
                const AppBanner(
                  message:
                      'This summary describes your recorded actions only. It does not measure treatment effectiveness or make a clinical judgment.',
                  icon: Icons.info_outline_rounded,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CompletedMedicationArchiveScreen extends ConsumerWidget {
  const CompletedMedicationArchiveScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(medicationPlansProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Completed Medication Archive')),
      body: plans.when(
        loading: () => const AppLoadingState(label: 'Loading archive…'),
        error: (_, _) => const SizedBox.shrink(),
        data: (values) {
          final archived = values
              .where(
                (value) =>
                    value.medication.status == MedicationStatus.completed ||
                    value.medication.status == MedicationStatus.archived,
              )
              .toList();
          return archived.isEmpty
              ? const AppEmptyState(
                  title: 'Archive is empty',
                  message:
                      'Ended schedules remain available here when you archive them.',
                  icon: Icons.archive_outlined,
                )
              : ListView(
                  children: [
                    for (final value in archived)
                      ListTile(
                        title: Text(value.medication.displayName),
                        subtitle: const Text(
                          'Saved medication schedule ended or archived',
                        ),
                        onTap: () =>
                            context.push('/medications/${value.plan.id}'),
                      ),
                  ],
                );
        },
      ),
    );
  }
}

class RefillReminderScreen extends ConsumerStatefulWidget {
  const RefillReminderScreen({required this.planId, super.key});
  final String planId;
  @override
  ConsumerState<RefillReminderScreen> createState() =>
      _RefillReminderScreenState();
}

class _RefillReminderScreenState extends ConsumerState<RefillReminderScreen> {
  final _quantity = TextEditingController();
  final _perDose = TextEditingController(text: '1');
  DateTime? _date;
  @override
  void dispose() {
    _quantity.dispose();
    _perDose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Refill Reminder')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const AppBanner(
          message:
              'Refill quantities are estimates based only on doses you mark taken. This does not represent pharmacy stock.',
        ),
        const SizedBox(height: AppSpacing.md),
        ListTile(
          title: const Text('Manual reminder date'),
          subtitle: Text(
            _date == null ? 'Not set' : DateFormat.yMMMd().format(_date!),
          ),
          onTap: () async {
            final value = await showDatePicker(
              context: context,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 730)),
            );
            if (value != null) setState(() => _date = value);
          },
        ),
        TextField(
          controller: _quantity,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Starting quantity (optional)',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _perDose,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantity per logged taken dose',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () async {
            await ref
                .read(medicationRepositoryProvider)
                .saveRefill(
                  planId: widget.planId,
                  reminderDate: _date,
                  startingQuantity: double.tryParse(_quantity.text),
                  quantityPerTakenDose: double.tryParse(_perDose.text),
                );
            if (context.mounted) context.pop();
          },
          child: const Text('Save refill reminder'),
        ),
      ],
    ),
  );
}

class MedicationNotesScreen extends ConsumerStatefulWidget {
  const MedicationNotesScreen({required this.planId, super.key});
  final String planId;
  @override
  ConsumerState<MedicationNotesScreen> createState() =>
      _MedicationNotesScreenState();
}

class _MedicationNotesScreenState extends ConsumerState<MedicationNotesScreen> {
  final _note = TextEditingController();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(medicationPlanProvider(widget.planId));
    return Scaffold(
      appBar: AppBar(title: const Text('Personal Notes')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const Text(
            'Personal notes are stored separately and are not interpreted clinically.',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Example: Keep this medicine in work bag.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: () async {
              final value = details.valueOrNull;
              if (value == null || _note.text.trim().isEmpty) return;
              await ref
                  .read(medicationRepositoryProvider)
                  .addNote(value.medication.id, _note.text);
              _note.clear();
              ref.invalidate(medicationPlanProvider(widget.planId));
            },
            child: const Text('Save note'),
          ),
          for (final note
              in details.valueOrNull?.notes ?? const <MedicationNote>[])
            ListTile(
              title: Text(note.note),
              subtitle: Text(
                DateFormat.yMMMd().format(note.updatedAt.toLocal()),
              ),
            ),
        ],
      ),
    );
  }
}

class ShareMedicationSummaryScreen extends ConsumerStatefulWidget {
  const ShareMedicationSummaryScreen({super.key});
  @override
  ConsumerState<ShareMedicationSummaryScreen> createState() =>
      _ShareMedicationSummaryScreenState();
}

class _ShareMedicationSummaryScreenState
    extends ConsumerState<ShareMedicationSummaryScreen> {
  bool _notes = false;
  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(medicationPlansProvider).valueOrNull ?? [];
    final preview = const MedicationExportService().preview(
      plans,
      MedicationExportSelection(
        includeStrength: true,
        includeInstruction: true,
        includeSchedule: true,
        includeNotes: _notes,
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Share Medication Summary')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const Text('Review exactly what will be included before sharing.'),
          SwitchListTile(
            title: const Text('Include personal notes'),
            value: _notes,
            onChanged: (value) => setState(() => _notes = value),
          ),
          AppCard(child: SelectableText(preview.plainText)),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: plans.isEmpty
                ? null
                : () async {
                    await ref
                        .read(medicationRepositoryProvider)
                        .recordExport(
                          format: 'text',
                          includedFields: preview.includedFields,
                          shared: true,
                        );
                    await SharePlus.instance.share(
                      ShareParams(
                        text: preview.plainText,
                        subject: 'User medication summary',
                        sharePositionOrigin: _shareOrigin(),
                      ),
                    );
                  },
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share reviewed summary'),
          ),
          OutlinedButton.icon(
            onPressed: plans.isEmpty ? null : () => _sharePdf(preview),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Export reviewed PDF'),
          ),
        ],
      ),
    );
  }

  Rect _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    return const Rect.fromLTWH(0, 0, 1, 1);
  }

  Future<void> _sharePdf(MedicationSummaryPreview preview) async {
    final bytes = await const MedicationExportService().pdfBytes(preview);
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/mediexplain-user-medication-summary.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    await ref
        .read(medicationRepositoryProvider)
        .recordExport(
          format: 'pdf',
          includedFields: preview.includedFields,
          shared: true,
        );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'User medication summary',
        sharePositionOrigin: _shareOrigin(),
      ),
    );
  }
}

class MedicationPrivacyScreen extends ConsumerWidget {
  const MedicationPrivacyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacy = ref.watch(medicationPrivacyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Data Management')),
      body: privacy.when(
        loading: () =>
            const AppLoadingState(label: 'Loading privacy settings…'),
        error: (_, _) => const SizedBox.shrink(),
        data: (value) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            FutureBuilder<NotificationPermissionState>(
              future: ref.read(notificationPermissionProvider).status(),
              builder: (context, snapshot) => AppBanner(
                message: snapshot.data == NotificationPermissionState.granted
                    ? 'Notifications are enabled. Exact delivery can still be delayed by operating-system power management.'
                    : 'Medication reminders are not enabled at the operating-system level. Your schedule remains saved in the app.',
                icon: Icons.notifications_outlined,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<NotificationPrivacy>(
              initialValue: value.notificationPrivacy,
              decoration: const InputDecoration(
                labelText: 'Notification privacy',
              ),
              items: NotificationPrivacy.values
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(_privacyLabel(item)),
                    ),
                  )
                  .toList(),
              onChanged: (next) async {
                if (next == null) return;
                await ref
                    .read(medicationRepositoryProvider)
                    .savePrivacy(value.copyWith(notificationPrivacy: next));
                await _rebuildMedicationReminders(ref);
                ref.invalidate(medicationPrivacyProvider);
              },
            ),
            SwitchListTile(
              title: const Text('Retain prescription images'),
              subtitle: const Text(
                'Off by default. Existing images are removed only through an explicit delete action.',
              ),
              value: value.retainPrescriptionImages,
              onChanged: (next) async {
                await ref
                    .read(medicationRepositoryProvider)
                    .savePrivacy(
                      value.copyWith(retainPrescriptionImages: next),
                    );
                ref.invalidate(medicationPrivacyProvider);
              },
            ),
            SwitchListTile(
              title: const Text('Sync medication logs'),
              subtitle: const Text(
                'Off by default. Logs stay on this device unless you explicitly enable sync.',
              ),
              value: value.syncMedicationHistory,
              onChanged: (next) async {
                await ref
                    .read(medicationRepositoryProvider)
                    .savePrivacy(value.copyWith(syncMedicationHistory: next));
                ref.invalidate(medicationPrivacyProvider);
              },
            ),
            SwitchListTile(
              title: const Text('Hide medicine details in the app'),
              value: value.hideMedicineDetails,
              onChanged: (next) async {
                await ref
                    .read(medicationRepositoryProvider)
                    .savePrivacy(value.copyWith(hideMedicineDetails: next));
                ref.invalidate(medicationPrivacyProvider);
              },
            ),
            SwitchListTile(
              title: const Text('Obscure app preview'),
              subtitle: const Text(
                'Preference saved. Full recent-apps obscuring still depends on platform support.',
              ),
              value: value.obscureAppPreview,
              onChanged: (next) async {
                await ref
                    .read(medicationRepositoryProvider)
                    .savePrivacy(value.copyWith(obscureAppPreview: next));
                ref.invalidate(medicationPrivacyProvider);
              },
            ),
            SwitchListTile(
              title: const Text('Neutral daily reminder summary'),
              subtitle: const Text(
                'Saves your preference for a future daily summary notification.',
              ),
              value: value.dailySummaryEnabled,
              onChanged: (next) async {
                await ref
                    .read(medicationRepositoryProvider)
                    .savePrivacy(value.copyWith(dailySummaryEnabled: next));
                ref.invalidate(medicationPrivacyProvider);
              },
            ),
            ListTile(
              title: const Text('Delete medication logs'),
              subtitle: const Text(
                'Removes taken/skipped/manual history from this device.',
              ),
              leading: const Icon(Icons.delete_outline_rounded),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete medication logs?'),
                    content: const Text(
                      'Medication plans and prescription history will remain.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => context.pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => context.pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref
                      .read(medicationRepositoryProvider)
                      .clearMedicationLogs();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MedicationActivityScreen extends ConsumerWidget {
  const MedicationActivityScreen({super.key, this.planId});
  final String? planId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(medicationActivityProvider(planId));
    return Scaffold(
      appBar: AppBar(title: const Text('Activity History')),
      body: activity.when(
        loading: () => const AppLoadingState(label: 'Loading activity…'),
        error: (_, _) => const SizedBox.shrink(),
        data: (values) => ListView(
          children: [
            for (final value in values)
              ListTile(
                title: Text(value.action.replaceAll('_', ' ')),
                subtitle: Text(
                  DateFormat.yMMMd().add_jm().format(
                    value.occurredAt.toLocal(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MedicationVoiceAssistantScreen extends ConsumerStatefulWidget {
  const MedicationVoiceAssistantScreen({super.key});
  @override
  ConsumerState<MedicationVoiceAssistantScreen> createState() =>
      _MedicationVoiceAssistantScreenState();
}

class _MedicationVoiceAssistantScreenState
    extends ConsumerState<MedicationVoiceAssistantScreen> {
  final _command = TextEditingController();
  late final VoiceInputService _voice;
  MedicationVoiceIntent _intent = const MedicationVoiceIntent(
    MedicationVoiceIntentType.unknown,
  );
  String _transcript = '';
  String _response =
      'Speak or type a command, then review the suggested action.';
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceInputProvider);
  }

  @override
  void dispose() {
    _command.dispose();
    unawaited(_voice.cancel());
    super.dispose();
  }

  void _process(String words) {
    if (words.trim().isEmpty) return;
    final intent = const MedicationVoiceIntentParser().parse(words);
    setState(() {
      _transcript = words.trim();
      _intent = intent;
      _response = _voiceResponse(intent);
      _listening = false;
    });
  }

  String? get _destination => switch (_intent.type) {
    MedicationVoiceIntentType.searchTerm => Uri(
      path: '/terms/search',
      queryParameters: {'query': _intent.argument ?? ''},
    ).toString(),
    MedicationVoiceIntentType.nextReminder ||
    MedicationVoiceIntentType.markTaken => '/medications/today',
    MedicationVoiceIntentType.readMedicine => '/medications',
    MedicationVoiceIntentType.openPrescription => '/prescriptions/history',
    MedicationVoiceIntentType.explainWarning => '/medicine-information/search',
    _ => null,
  };

  String get _actionLabel => switch (_intent.type) {
    MedicationVoiceIntentType.searchTerm => 'Search terminology',
    MedicationVoiceIntentType.nextReminder => 'Open medication timeline',
    MedicationVoiceIntentType.markTaken => 'Review dose on timeline',
    MedicationVoiceIntentType.readMedicine => 'Choose a medication',
    MedicationVoiceIntentType.openPrescription => 'Open prescription history',
    MedicationVoiceIntentType.explainWarning => 'Choose a sourced medicine',
    _ => 'Review action',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Voice Assistant')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const AppBanner(
          message:
              'Voice can read and navigate. Any dose-log change requires a separate visual confirmation. Voice cannot change dosage or prescribe.',
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _command,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Type a command',
            hintText: 'Search hypertension',
          ),
          textInputAction: TextInputAction.go,
          onSubmitted: _process,
        ),
        AppPrimaryButton(
          label: 'Review command',
          onPressed: () => _process(_command.text),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _transcript.isEmpty
                    ? 'Listening transcript appears here'
                    : _transcript,
              ),
              const Divider(),
              Text(_response),
              if (_destination != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppPrimaryButton(
                  label: _actionLabel,
                  onPressed: () => context.push(_destination!),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: _toggle,
          icon: Icon(_listening ? Icons.stop : Icons.mic),
          label: Text(_listening ? 'Stop listening' : 'Start voice input'),
        ),
      ],
    ),
  );

  Future<void> _toggle() async {
    final locale = Localizations.localeOf(context).languageCode;
    try {
      if (_listening) {
        await _voice.stop();
        if (mounted) setState(() => _listening = false);
        return;
      }
      if (!await _voice.initialize()) {
        throw UnsupportedError('Speech unavailable');
      }
      if (!mounted) return;
      setState(() => _listening = true);
      await _voice.listen(
        locale: locale,
        onResult: (words, finalResult) {
          if (!mounted) return;
          if (finalResult) {
            _process(words);
            unawaited(_voice.stop());
          } else {
            setState(() => _transcript = words);
          }
        },
      );
    } on Object {
      if (mounted) {
        setState(() {
          _listening = false;
          _response =
              'Voice input is unavailable on this device. You can type a command instead.';
        });
      }
    }
  }

  String _voiceResponse(MedicationVoiceIntent intent) => switch (intent.type) {
    MedicationVoiceIntentType.unsafeMedicationChange =>
      'I cannot recommend an extra dose, change a dose, or tell you to stop a medicine. Check your instructions or ask your pharmacist or doctor.',
    MedicationVoiceIntentType.markTaken =>
      'I found a request to mark a dose taken. Open Today’s Timeline and visually confirm the exact medicine and time.',
    MedicationVoiceIntentType.nextReminder =>
      'Open Today’s Medication Timeline to hear and review the next confirmed reminder.',
    MedicationVoiceIntentType.readMedicine =>
      'Open a medication and choose Read aloud.',
    MedicationVoiceIntentType.searchTerm =>
      'Search request recognized: ${intent.argument}.',
    MedicationVoiceIntentType.openPrescription =>
      'Open Prescription History to choose the prescription.',
    MedicationVoiceIntentType.explainWarning =>
      'Open the sourced warning and choose Read aloud.',
    MedicationVoiceIntentType.unknown =>
      'I did not recognize a supported medication command.',
  };
}

class MedicationAccessibilitySettingsScreen extends StatelessWidget {
  const MedicationAccessibilitySettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Accessibility Settings')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: const [
        AppBanner(
          message:
              'Use the main Settings screen for larger text, larger controls, high readability, reduced motion, haptics, language, and text-to-speech.',
        ),
        ListTile(
          leading: Icon(Icons.record_voice_over_outlined),
          title: Text('Screen-reader headings and action labels'),
          subtitle: Text(
            'Medication controls include semantic labels and explicit confirmation prompts.',
          ),
        ),
        ListTile(
          leading: Icon(Icons.volume_up_outlined),
          title: Text('Read aloud'),
          subtitle: Text('Sensitive content is read only after you choose it.'),
        ),
      ],
    ),
  );
}

class NotificationPrivacyScreen extends ConsumerWidget {
  const NotificationPrivacyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const MedicationPrivacyScreen();
}

String _sourceLabel(MedicationSourceType source) => switch (source) {
  MedicationSourceType.confirmedPrescription => 'Confirmed prescription',
  MedicationSourceType.manualEntry => 'Manual entry',
  MedicationSourceType.confirmedLookup => 'User-confirmed lookup',
};

String _scheduleLabel(MedicationScheduleType type) => switch (type) {
  MedicationScheduleType.onceDaily => 'Once daily',
  MedicationScheduleType.twiceDaily => 'Twice daily',
  MedicationScheduleType.threeTimesDaily => 'Three times daily',
  MedicationScheduleType.fourTimesDaily => 'Four times daily',
  MedicationScheduleType.everyNHours => 'Every N hours',
  MedicationScheduleType.selectedWeekdays => 'Selected weekdays',
  MedicationScheduleType.specificDays => 'Specific days',
  MedicationScheduleType.custom => 'Custom schedule',
  MedicationScheduleType.asNeeded => 'As needed (no fixed reminders)',
};

String _scheduleSummary(MedicationSchedule schedule, BuildContext context) {
  if (schedule.asNeeded) return 'Available as needed — no fixed reminders';
  if (schedule.type == MedicationScheduleType.everyNHours) {
    return 'Every ${schedule.intervalHours} hours from your selected start time';
  }
  final times = schedule.times.map(
    (minutes) =>
        TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context),
  );
  return '${_scheduleLabel(schedule.type)}: ${times.join(', ')}';
}

String _doseLabel(DoseAction action) => switch (action) {
  DoseAction.taken => 'Taken',
  DoseAction.skipped => 'Skipped',
  DoseAction.notRecorded => 'Not recorded',
  DoseAction.late => 'Taken late',
};

String _privacyLabel(NotificationPrivacy privacy) => switch (privacy) {
  NotificationPrivacy.fullDetails => 'Full details',
  NotificationPrivacy.medicineNameOnly => 'Medicine name only',
  NotificationPrivacy.privateReminder => 'Private reminder',
};

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final MedicationStatus status;
  @override
  Widget build(BuildContext context) => Chip(
    label: Text(
      status.name.replaceAll(RegExp(r'(?=[A-Z])'), ' ').toUpperCase(),
    ),
  );
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner();
  @override
  Widget build(BuildContext context) => const AppBanner(
    message:
        'Would you like reminders for this medicine? Reminders use only instructions you confirm. No reminder is created automatically from OCR.',
    icon: Icons.verified_user_outlined,
  );
}
