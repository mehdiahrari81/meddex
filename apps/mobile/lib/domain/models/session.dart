class Session {
  const Session({
    required this.id,
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime createdAt;

  bool get isAccessTokenExpired =>
      !accessTokenExpiresAt.isAfter(DateTime.now().toUtc());
}
