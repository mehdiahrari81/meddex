import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'local_server_identity.dart';

/// Bonjour can advertise both a Mac's Wi-Fi address and its USB link address.
/// Use the LAN address for the configured development server, resolving afresh
/// for each connection so a DHCP change does not require a new app build.
void configureLocalApiTransport(Dio client, Uri baseUrl) {
  if (baseUrl.scheme != 'http' || !baseUrl.host.endsWith('.local')) return;
  final adapter = client.httpClientAdapter;
  if (adapter is! IOHttpClientAdapter) return;
  final pairedHost = Uri.tryParse(
    const String.fromEnvironment('API_BASE_URL'),
  )?.host;
  final identity = baseUrl.host == pairedHost
      ? LocalServerIdentity()
      : LocalServerIdentity(publicKey: '');
  adapter.createHttpClient = () => HttpClient()
    // Do not reuse a socket from the previous Wi-Fi network. Each request
    // resolves the same trusted hostname again, never a saved numeric address.
    ..idleTimeout = Duration.zero
    ..connectionFactory = (uri, proxyHost, proxyPort) async {
      if (proxyHost != null || uri.host != baseUrl.host) {
        return Socket.startConnect(
          proxyHost ?? uri.host,
          proxyPort ?? uri.port,
        );
      }
      return connectLocalApiHost(
        uri.host,
        uri.port,
        fallbackLookup: identity.enabled ? identity.addresses : null,
        verifyAddress: identity.enabled ? identity.verify : null,
      );
    };
}

/// Try the LAN addresses advertised by this exact hostname before any HTTP
/// bytes are sent. A stale Bonjour address must not prevent trying the current
/// Wi-Fi address. This never scans the network or redirects a signed-in request.
Future<ConnectionTask<Socket>> connectLocalApiHost(
  String host,
  int port, {
  Future<List<InternetAddress>> Function(String)? lookup,
  Future<ConnectionTask<Socket>> Function(InternetAddress, int)? startConnect,
  Duration addressTimeout = const Duration(seconds: 2),
  Future<List<InternetAddress>> Function()? fallbackLookup,
  Future<bool> Function(InternetAddress, int)? verifyAddress,
}) async {
  List<InternetAddress> resolved;
  try {
    resolved = await (lookup ?? _lookup)(
      host,
    ).timeout(const Duration(seconds: 3));
  } on Object {
    if (fallbackLookup == null || verifyAddress == null) rethrow;
    resolved = [];
  }
  // A cached address is eligible only with cryptographic verification enabled.
  final fallback = fallbackLookup != null && verifyAddress != null
      ? await fallbackLookup()
      : <InternetAddress>[];
  final lan = resolved
      .where((a) => selectLocalApiAddress([a]) != null)
      .toList();
  final addresses = <InternetAddress>[];
  for (final address in [...lan.take(1), ...fallback, ...lan.skip(1)]) {
    if (selectLocalApiAddress([address]) != null &&
        !addresses.any((item) => item.address == address.address)) {
      addresses.add(address);
    }
  }
  if (addresses.isEmpty) {
    throw const SocketException(
      'No LAN address for the server. Connect both devices to the same Wi-Fi.',
    );
  }
  var cancelled = false;
  ConnectionTask<Socket>? active;
  Socket? connected;
  Future<Socket> connect() async {
    for (final address in addresses.take(3)) {
      if (cancelled) throw const SocketException('Connection cancelled.');
      try {
        if (verifyAddress != null && !await verifyAddress(address, port)) {
          continue;
        }
        if (cancelled) throw const SocketException('Connection cancelled.');
        active = await (startConnect ?? _startConnect)(address, port);
        if (cancelled) {
          active!.cancel();
          throw const SocketException('Connection cancelled.');
        }
        connected = await active!.socket.timeout(addressTimeout);
        if (cancelled) {
          connected!.destroy();
          throw const SocketException('Connection cancelled.');
        }
        return connected!;
      } on SocketException {
        active?.cancel();
      } on TimeoutException {
        active?.cancel();
      }
    }
    throw const SocketException(
      'Cannot reach this Mac on Wi-Fi. Keep both devices on the same network and the API running.',
    );
  }

  return ConnectionTask.fromSocket(connect(), () {
    cancelled = true;
    active?.cancel();
    connected?.destroy();
  });
}

Future<List<InternetAddress>> _lookup(String host) =>
    InternetAddress.lookup(host, type: InternetAddressType.IPv4);

Future<ConnectionTask<Socket>> _startConnect(
  InternetAddress address,
  int port,
) => Socket.startConnect(address, port);

/// Excludes loopback and USB link-local (169.254/16) advertisements. The server
/// URL and HTTP Host header stay unchanged; no alternate host receives tokens.
InternetAddress? selectLocalApiAddress(List<InternetAddress> addresses) {
  for (final address in addresses) {
    if (address.type != InternetAddressType.IPv4) continue;
    final bytes = address.rawAddress;
    if (bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168)) {
      return address;
    }
  }
  return null;
}
