import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/features/intelligence/domain/intelligence_models.dart';

void main() {
  test('combination ingredients keep independent strengths', () {
    final value = MedicationCandidate.fromJson({
      'candidate_id': 'drap:one',
      'canonical_name': 'Combination tablet',
      'generic_name': 'ingredient a / ingredient b',
      'brand_name': 'Brand',
      'ingredients': [
        {
          'name': 'ingredient a',
          'numerator_value': '500',
          'numerator_unit': 'mg',
          'denominator_value': null,
          'denominator_unit': null,
        },
        {
          'name': 'ingredient b',
          'numerator_value': '125',
          'numerator_unit': 'mg',
          'denominator_value': null,
          'denominator_unit': null,
        },
      ],
      'strength': '500 mg / 125 mg',
      'dosage_form': 'tablet',
      'country': 'PK',
      'provider': 'drap_dataset',
      'provider_version': '2026-08',
      'identifiers': <Object?>[],
      'evidence': [
        {
          'signal': 'strength',
          'matched': true,
          'requested': '500 mg / 125 mg',
          'candidate': '500 mg / 125 mg',
        },
      ],
      'match_score': .95,
      'exact_identity': true,
    });

    expect(value.ingredients, hasLength(2));
    expect(value.ingredients.first.displayStrength, '500 mg');
    expect(value.ingredients.last.displayStrength, '125 mg');
  });

  test('explicit server resolution states are preserved', () {
    final value = MedicationResolution.fromJson({
      'id': 'resolution-1',
      'state': 'user_selection_required',
      'normalized_search_string': 'amoxicillin',
      'candidates': <Object?>[],
      'provider_failures': <Object?>[],
      'medication_id': null,
    });
    expect(value.state, MedicationResolutionState.userSelectionRequired);
  });

  test('offline identity is marked stale without changing source dates', () {
    final retrieved = DateTime.utc(2026, 8, 1);
    final value = MedicationIdentity.fromJson({
      'id': 'medication-1',
      'canonical_display_name': 'Source medicine',
      'generic_name': 'source ingredient',
      'brand_names': <Object?>[],
      'ingredients': <Object?>[],
      'dosage_form': 'tablet',
      'country': 'US',
      'identifiers': <Object?>[],
      'verification_state': 'external_identity_verified',
      'facts': [
        {
          'id': 'fact-1',
          'type': 'warnings',
          'content': 'Source warning',
          'review_status': 'source_retrieved',
          'source': {
            'id': 'fact-1',
            'provider': 'dailymed',
            'title': 'Official label',
            'section': 'Warnings',
            'jurisdiction': 'US',
            'language': 'en',
            'content_version': '1',
            'retrieved_at': retrieved.toIso8601String(),
            'source_updated_at': null,
            'url': 'https://dailymed.nlm.nih.gov/example',
          },
        },
      ],
      'cache_state': 'current',
      'interaction_provider_state': 'not_configured',
    }, offline: true);

    expect(value.offline, isTrue);
    expect(value.cacheState, 'stale');
    expect(value.facts.single.source.retrievedAt, retrieved);
  });
}
