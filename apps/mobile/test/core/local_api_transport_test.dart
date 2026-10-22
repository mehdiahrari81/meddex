import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/network/local_api_transport_io.dart';

class _Socket extends Fake implements Socket {
  bool destroyed = false;
  @override
  void destroy() => destroyed = true;
}

void main() {
  test(
    'blocked Bonjour uses an identity-verified remembered address',
    () async {
      final verified = <String>[];
      final task = await connectLocalApiHost(
        'mac.local',
        8000,
        lookup: (_) async => throw const SocketException('Bonjour blocked'),
        fallbackLookup: () async => [InternetAddress('10.141.27.28')],
        verifyAddress: (address, _) async {
          verified.add(address.address);
          return true;
        },
        startConnect: (_, _) async =>
            ConnectionTask.fromSocket(Future.value(_Socket()), () {}),
      );
      (await task.socket).destroy();
      expect(verified, ['10.141.27.28']);
    },
  );

  test(
    'wrong server and USB fallback never receive the authenticated connection',
    () async {
      var connected = false;
      final task = await connectLocalApiHost(
        'mac.local',
        8000,
        lookup: (_) async => [],
        fallbackLookup: () async => [
          InternetAddress('169.254.1.2'),
          InternetAddress('10.141.27.28'),
        ],
        verifyAddress: (_, _) async => false,
        startConnect: (_, _) async {
          connected = true;
          return ConnectionTask.fromSocket(Future.value(_Socket()), () {});
        },
      );
      await expectLater(task.socket, throwsA(isA<SocketException>()));
      expect(connected, isFalse);
    },
  );

  test('fallback addresses are ignored without an identity verifier', () async {
    var fallbackCalled = false;
    await expectLater(
      connectLocalApiHost(
        'mac.local',
        8000,
        lookup: (_) async => [],
        fallbackLookup: () async {
          fallbackCalled = true;
          return [InternetAddress('10.141.27.28')];
        },
      ),
      throwsA(isA<SocketException>()),
    );
    expect(fallbackCalled, isFalse);
  });
  test(
    'Bonjour LAN routing ignores USB, loopback and IPv6 link advertisements',
    () {
      final address = selectLocalApiAddress([
        InternetAddress('169.254.228.80'),
        InternetAddress('127.0.0.1'),
        InternetAddress('fe80::1234'),
        InternetAddress('10.141.216.118'),
      ]);
      expect(address?.address, '10.141.216.118');
      expect(
        selectLocalApiAddress([InternetAddress('169.254.228.80')]),
        isNull,
      );
      for (final lan in ['192.168.1.20', '172.16.1.20', '172.31.1.20']) {
        expect(selectLocalApiAddress([InternetAddress(lan)])?.address, lan);
      }
      expect(selectLocalApiAddress([InternetAddress('172.32.1.20')]), isNull);
    },
  );

  test('only configured local HTTP server gets the LAN connection factory', () {
    final lan = Dio();
    configureLocalApiTransport(lan, Uri.parse('http://mac.local:8000/api/v1/'));
    expect(
      (lan.httpClientAdapter as IOHttpClientAdapter).createHttpClient,
      isNotNull,
    );
    for (final url in [
      'https://api.example.com/api/v1/',
      'http://127.0.0.1:8000/api/v1/',
    ]) {
      final normal = Dio();
      configureLocalApiTransport(normal, Uri.parse(url));
      expect(
        (normal.httpClientAdapter as IOHttpClientAdapter).createHttpClient,
        isNull,
      );
      normal.close(force: true);
    }
    lan.close(force: true);
  });
  test('each new connection resolves the changed Wi-Fi address', () async {
    var resolutions = 0;
    final connected = <String>[];
    Future<List<InternetAddress>> lookup(String host) async {
      expect(host, 'my-mac.local');
      resolutions++;
      return [InternetAddress(resolutions == 1 ? '192.168.1.20' : '10.0.0.9')];
    }

    Future<ConnectionTask<Socket>> connect(
      InternetAddress address,
      int port,
    ) async {
      expect(port, 8000);
      connected.add(address.address);
      return ConnectionTask.fromSocket(Future.value(_Socket()), () {});
    }

    for (var index = 0; index < 2; index++) {
      final task = await connectLocalApiHost(
        'my-mac.local',
        8000,
        lookup: lookup,
        startConnect: connect,
      );
      (await task.socket).destroy();
    }
    expect(connected, ['192.168.1.20', '10.0.0.9']);
    expect(resolutions, 2);
  });

  test('stale LAN address falls through to current Wi-Fi, never USB', () async {
    final attempts = <String>[];
    final socket = _Socket();
    final task = await connectLocalApiHost(
      'my-mac.local',
      8000,
      lookup: (_) async => [
        InternetAddress('169.254.1.9'),
        InternetAddress('127.0.0.1'),
        InternetAddress('192.168.1.20'),
        InternetAddress('192.168.1.20'),
        InternetAddress('10.0.0.9'),
      ],
      startConnect: (address, port) async {
        attempts.add(address.address);
        if (attempts.length == 1) throw const SocketException('Stale route');
        return ConnectionTask.fromSocket(Future.value(socket), () {});
      },
    );
    expect(await task.socket, same(socket));
    expect(attempts, ['192.168.1.20', '10.0.0.9']);
    socket.destroy();
  });

  test(
    'stalled address is cancelled before trying another LAN address',
    () async {
      final pending = Completer<Socket>();
      var cancelled = false;
      var attempts = 0;
      final task = await connectLocalApiHost(
        'my-mac.local',
        8000,
        addressTimeout: const Duration(milliseconds: 10),
        lookup: (_) async => [
          InternetAddress('192.168.1.20'),
          InternetAddress('10.0.0.9'),
        ],
        startConnect: (address, port) async {
          attempts++;
          if (attempts == 1) {
            return ConnectionTask.fromSocket(pending.future, () {
              cancelled = true;
              if (!pending.isCompleted) {
                pending.completeError(const SocketException('Cancelled'));
              }
            });
          }
          return ConnectionTask.fromSocket(Future.value(_Socket()), () {});
        },
      );
      (await task.socket).destroy();
      expect(cancelled, isTrue);
      expect(attempts, 2);
    },
  );

  test('cancelling connection stops address fallback', () async {
    final pending = Completer<Socket>();
    var attempts = 0;
    final task = await connectLocalApiHost(
      'my-mac.local',
      8000,
      lookup: (_) async => [
        InternetAddress('192.168.1.20'),
        InternetAddress('10.0.0.9'),
      ],
      startConnect: (address, port) async {
        attempts++;
        return ConnectionTask.fromSocket(pending.future, () {
          if (!pending.isCompleted) {
            pending.completeError(const SocketException('Cancelled'));
          }
        });
      },
    );
    final failure = expectLater(task.socket, throwsA(isA<SocketException>()));
    await Future<void>.delayed(Duration.zero);
    task.cancel();
    await failure;
    expect(attempts, 1);
  });

  test('failure tries at most three advertised addresses', () async {
    var attempts = 0;
    final task = await connectLocalApiHost(
      'my-mac.local',
      8000,
      lookup: (_) async => List.generate(
        5,
        (index) => InternetAddress('192.168.1.${20 + index}'),
      ),
      startConnect: (_, _) async {
        attempts++;
        throw const SocketException('Unavailable');
      },
    );
    await expectLater(task.socket, throwsA(isA<SocketException>()));
    expect(attempts, 3);
  });

  test('USB-only and public DNS answers never receive a connection', () async {
    var attempted = false;
    await expectLater(
      connectLocalApiHost(
        'my-mac.local',
        8000,
        lookup: (_) async => [
          InternetAddress('169.254.1.9'),
          InternetAddress('8.8.8.8'),
        ],
        startConnect: (_, _) async {
          attempted = true;
          throw const SocketException('Must not connect');
        },
      ),
      throwsA(isA<SocketException>()),
    );
    expect(attempted, isFalse);
  });
}
