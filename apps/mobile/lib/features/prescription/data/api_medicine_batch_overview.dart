import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../auth/application/auth_controller.dart';
import '../presentation/medicine_overview_card.dart';

class BatchMedicineOverviewData {
  const BatchMedicineOverviewData({
    required this.itemId,
    required this.name,
    required this.overview,
  });
  final String itemId;
  final String name;
  final MedicineOverviewData overview;
}

final medicineBatchOverviewProvider = FutureProvider.autoDispose
    .family<List<BatchMedicineOverviewData>, String>((ref, bodyJson) async {
      final api = ref.watch(apiClientProvider);
      await ref.watch(authControllerProvider.future);
      final owner = api.currentUserId;
      if (owner == null) throw const AuthenticationExpiredError();
      final body = Map<String, Object?>.from(jsonDecode(bodyJson) as Map);
      final requested = (body['medicines']! as List).cast<Map>();
      final response = await api.postJson(
        'prescription-ocr/medicine-overviews',
        data: body,
        receiveTimeout: const Duration(seconds: 120),
      );
      if (api.currentUserId != owner) throw const AuthenticationExpiredError();
      final rows = response['medicines']! as List;
      final entries = <String, BatchMedicineOverviewData>{};
      for (final raw in rows) {
        final row = Map<String, Object?>.from(raw as Map);
        final id = row['item_id']! as String;
        if (entries.containsKey(id)) {
          throw const FormatException('Duplicate medicine result');
        }
        entries[id] = BatchMedicineOverviewData(
          itemId: id,
          name: row['name']! as String,
          overview: MedicineOverviewData.fromJson(
            Map<String, Object?>.from(row['overview']! as Map),
          ),
        );
      }
      if (entries.length != requested.length) {
        throw const FormatException('Incomplete medicine list');
      }
      return [for (final item in requested) _matching(entries, item)];
    });

BatchMedicineOverviewData _matching(
  Map<String, BatchMedicineOverviewData> entries,
  Map item,
) {
  final result = entries[item['item_id']];
  if (result == null || result.name != item['name']) {
    throw const FormatException('Medicine identity changed in batch response');
  }
  return result;
}
