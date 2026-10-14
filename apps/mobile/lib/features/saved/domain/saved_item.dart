import '../../terminology/domain/medical_term.dart';

class SavedItem {
  const SavedItem({
    required this.id,
    required this.contentId,
    required this.contentType,
    required this.savedAt,
    required this.syncState,
  });
  final String id;
  final String contentId;
  final MedicalContentType contentType;
  final DateTime savedAt;
  final String syncState;
}

class SavedContentDisplay {
  const SavedContentDisplay({
    required this.item,
    required this.title,
    required this.subtitle,
  });
  final SavedItem item;
  final String title;
  final String subtitle;
}

abstract interface class SavedContentRepository {
  Stream<List<SavedItem>> watch({MedicalContentType? type});
  Future<bool> isSaved(String contentId, MedicalContentType type);
  Future<void> save(String contentId, MedicalContentType type);
  Future<void> unsave(String contentId, MedicalContentType type);
}
