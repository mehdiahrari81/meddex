import 'package:dio/dio.dart';

import 'local_api_transport.dart';

Uri validateDevelopmentServerUrl(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      !const {'http', 'https'}.contains(uri.scheme) ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.port == 0) {
    throw const FormatException(
      'Use a server URL such as http://192.168.1.20:8000/api/v1/.',
    );
  }
  if (uri.scheme == 'http' && !_isLocalHost(uri.host)) {
    throw const FormatException(
      'HTTP is supported only for a private LAN address or .local hostname. Use HTTPS for a hosted server.',
    );
  }
  if (!const ['', '/', '/api/v1', '/api/v1/'].contains(uri.path)) {
    throw const FormatException('The server URL must end with /api/v1/.');
  }
  return uri.replace(path: '/api/v1/');
}

bool _isLocalHost(String host) {
  if (host.endsWith('.local') && host.length > 6) return true;
  final bytes = host.split('.').map(int.tryParse).toList();
  if (bytes.length != 4 || bytes.any((n) => n == null || n < 0 || n > 255)) {
    return false;
  }
  return bytes[0] == 10 ||
      (bytes[0] == 172 && bytes[1]! >= 16 && bytes[1]! <= 31) ||
      (bytes[0] == 192 && bytes[1] == 168);
}

/// Check only the selected server's public readiness endpoint. No session,
/// prescription, API key or Authorization header is sent and redirects are refused.
Future<void> checkDevelopmentServer(Uri server, {Dio? client}) async {
  final http =
      client ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 4),
          followRedirects: false,
        ),
      );
  if (client == null) configureLocalApiTransport(http, server);
  try {
    final response = await http.get<Object?>(
      server.resolve('ready').toString(),
      options: Options(followRedirects: false),
    );
    if (response.statusCode != 200 ||
        response.data is! Map ||
        (response.data as Map)['status'] != 'ready') {
      throw const FormatException(
        'The selected address did not identify a ready MediExplain server.',
      );
    }
  } finally {
    if (client == null) http.close(force: true);
  }
}
