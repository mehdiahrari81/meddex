class ConsentRecord {
  const ConsentRecord({
    required this.version,
    required this.acceptedAt,
    required this.locale,
  });

  final int version;
  final DateTime acceptedAt;
  final String locale;
}
