import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A development-only pin. The private signing key never leaves the backend.
class LocalServerIdentity {
  LocalServerIdentity({
    this.publicKey = const String.fromEnvironment('LOCAL_SERVER_PUBLIC_KEY'),
    this.bootstrapAddresses = const String.fromEnvironment(
      'LOCAL_SERVER_ADDRESSES',
    ),
  });

  final String publicKey;
  final String bootstrapAddresses;
  SharedPreferencesAsync get _preferences => SharedPreferencesAsync();
  bool get enabled => publicKey.isNotEmpty;
  String get _cacheKey =>
      'connection.verified_addresses.${sha256.convert(utf8.encode(publicKey))}';

  Future<List<InternetAddress>> addresses() async {
    List<String> saved = const [];
    try {
      saved = await _preferences.getStringList(_cacheKey) ?? [];
    } on Object {
      /* Best-effort cache. */
    }
    return [
      ...saved,
      ...bootstrapAddresses.split(','),
    ].map(InternetAddress.tryParse).whereType<InternetAddress>().toList();
  }

  Future<bool> verify(InternetAddress address, int port) async {
    if (!enabled) return false;
    final random = Random.secure();
    final challenge = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 1),
        receiveTimeout: const Duration(seconds: 2),
        sendTimeout: const Duration(seconds: 1),
        followRedirects: false,
      ),
    );
    try {
      // This client has no account/session interceptors and sends no health data.
      final response = await client.get<Map<String, dynamic>>(
        'http://${address.address}:$port/api/v1/local-server-identity',
        queryParameters: {'challenge': challenge},
      );
      final proof = response.data;
      if (response.statusCode != 200 ||
          proof?['public_key'] != publicKey ||
          proof?['signature'] is! String) {
        return false;
      }
      final verified = await const MethodChannel('mediexplain/local_server')
          .invokeMethod<bool>('verifyIdentity', {
            'public_key': publicKey,
            'signature': proof!['signature'],
            'challenge': challenge,
          });
      if (verified != true) return false;
      try {
        final previous = await _preferences.getStringList(_cacheKey) ?? [];
        await _preferences.setStringList(
          _cacheKey,
          {address.address, ...previous}.take(5).toList(),
        );
      } on Object {
        /* A cache write must not fail a verified connection. */
      }
      return true;
    } on Object {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
