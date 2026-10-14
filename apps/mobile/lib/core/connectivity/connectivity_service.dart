import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityState { online, offline, reconnecting, synchronizing }

class ConnectivityService {
  ConnectivityService(this._connectivity);

  final Connectivity _connectivity;

  Future<ConnectivityState> current() async =>
      _map(await _connectivity.checkConnectivity());

  Stream<ConnectivityState> watch() =>
      _connectivity.onConnectivityChanged.map(_map).distinct();

  ConnectivityState _map(List<ConnectivityResult> results) =>
      results.isEmpty ||
          results.every((item) => item == ConnectivityResult.none)
      ? ConnectivityState.offline
      : ConnectivityState.online;
}

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService(Connectivity()),
);

final connectivityProvider = StreamProvider<ConnectivityState>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  yield await service.current();
  yield* service.watch();
});
