import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../auth/application/auth_controller.dart';
import '../data/api_medication_intelligence_repository.dart';
import '../domain/intelligence_models.dart';
import '../domain/medication_intelligence_repository.dart';

final medicationIntelligenceRepositoryProvider =
    Provider<MedicationIntelligenceRepository>(
      (ref) => ApiMedicationIntelligenceRepository(
        api: ref.watch(apiClientProvider),
        database: ref.watch(databaseProvider),
      ),
    );

final savedMedicationIdentitiesProvider =
    FutureProvider<List<MedicationIdentity>>(
      (ref) => ref.watch(medicationIntelligenceRepositoryProvider).saved(),
    );

final recentMedicationIdentitiesProvider =
    FutureProvider<List<MedicationIdentity>>(
      (ref) => ref.watch(medicationIntelligenceRepositoryProvider).recent(),
    );

final medicationIdentityProvider =
    FutureProvider.family<MedicationIdentity, String>(
      (ref, id) =>
          ref.watch(medicationIntelligenceRepositoryProvider).detail(id),
    );
