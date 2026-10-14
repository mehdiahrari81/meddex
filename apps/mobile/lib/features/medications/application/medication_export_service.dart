import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/medication_models.dart';

class MedicationExportSelection {
  const MedicationExportSelection({
    required this.includeStrength,
    required this.includeInstruction,
    required this.includeSchedule,
    required this.includeNotes,
  });

  const MedicationExportSelection.defaults()
    : includeStrength = true,
      includeInstruction = true,
      includeSchedule = true,
      includeNotes = false;

  final bool includeStrength;
  final bool includeInstruction;
  final bool includeSchedule;
  final bool includeNotes;
}

class MedicationSummaryPreview {
  const MedicationSummaryPreview({
    required this.plainText,
    required this.structured,
    required this.includedFields,
  });

  final String plainText;
  final Map<String, Object?> structured;
  final List<String> includedFields;
}

class MedicationExportService {
  const MedicationExportService();

  MedicationSummaryPreview preview(
    List<MedicationPlanDetails> plans,
    MedicationExportSelection selection,
  ) {
    final fields = <String>['medicine name'];
    if (selection.includeStrength) fields.add('strength');
    if (selection.includeInstruction) fields.add('confirmed instruction');
    if (selection.includeSchedule) fields.add('reminder schedule');
    if (selection.includeNotes) fields.add('personal notes');
    final buffer = StringBuffer('Medication summary\n\n');
    final items = <Map<String, Object?>>[];
    for (final details in plans) {
      final item = <String, Object?>{
        'medication_name': details.medication.displayName,
      };
      buffer.writeln(details.medication.displayName);
      if (selection.includeStrength && details.medication.strength != null) {
        item['strength'] = details.medication.strength;
        buffer.writeln('Strength: ${details.medication.strength}');
      }
      if (selection.includeInstruction) {
        item['confirmed_instruction'] = details.source.confirmedInstruction;
        buffer.writeln(
          'Confirmed instruction: ${details.source.confirmedInstruction}',
        );
      }
      if (selection.includeSchedule) {
        final times = details.schedules
            .expand((schedule) => schedule.times)
            .map(_formatMinutes)
            .toList();
        item['user_reminder_times'] = times;
        buffer.writeln(
          times.isEmpty
              ? 'Reminder schedule: no fixed reminders'
              : 'User reminder times: ${times.join(', ')} (${details.plan.timezone})',
        );
      }
      if (selection.includeNotes && details.notes.isNotEmpty) {
        item['personal_notes'] = details.notes
            .map((note) => note.note)
            .toList();
        buffer.writeln(
          'Personal notes: ${details.notes.map((note) => note.note).join('; ')}',
        );
      }
      buffer.writeln();
      items.add(item);
    }
    const disclaimer =
        'User-entered / prescription-derived information. Verify against original prescription.';
    buffer.writeln(disclaimer);
    return MedicationSummaryPreview(
      plainText: buffer.toString().trim(),
      structured: {
        'document_type': 'user_medication_summary',
        'official_prescription': false,
        'medications': items,
        'disclaimer': disclaimer,
      },
      includedFields: fields,
    );
  }

  Uint8List jsonBytes(MedicationSummaryPreview preview) => Uint8List.fromList(
    utf8.encode(const JsonEncoder.withIndent('  ').convert(preview.structured)),
  );

  Future<Uint8List> pdfBytes(MedicationSummaryPreview preview) async {
    final document = pw.Document(
      title: 'User medication summary',
      author: 'MediExplain user export',
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            'User Medication Summary',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Text(preview.plainText),
        ],
        footer: (context) => pw.Text(
          'Not an official prescription • Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ),
    );
    return document.save();
  }

  String _formatMinutes(int value) {
    final hour = value ~/ 60;
    final minute = value % 60;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
  }
}
