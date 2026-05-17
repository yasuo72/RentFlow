import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/constants/app_strings.dart';
import '../../features/dashboard/dashboard_provider.dart';
import '../../features/expenses/expenses_provider.dart';
import '../../features/payments/payments_provider.dart';
import '../../features/rooms/rooms_provider.dart';
import '../../features/tenants/tenants_provider.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService(ref);
});

class SocketService {
  SocketService(this._ref);

  final Ref _ref;
  io.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String token) {
    if (_socket != null) {
      disconnect();
    }

    _socket = io.io(
      AppStrings.socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['polling', 'websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(12)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setTimeout(20000)
          .enableAutoConnect()
          .build(),
    );

    _socket?.onConnect((_) {});
    _socket?.on('payment:new', (_) {
      _ref.read(paymentsProvider.notifier).refresh(silent: true);
      _ref.invalidate(pendingPaymentsProvider);
      _ref.read(roomsProvider.notifier).refresh(silent: true);
      _ref.read(dashboardProvider.notifier).refresh(silent: true);
      _ref.read(tenantsProvider.notifier).refresh(silent: true);
    });
    _socket?.on('room:updated', (_) {
      _ref.read(roomsProvider.notifier).refresh(silent: true);
      _ref.read(dashboardProvider.notifier).refresh(silent: true);
      _ref.read(tenantsProvider.notifier).refresh(silent: true);
    });
    _socket?.on('tenant:added', (_) {
      _ref.read(tenantsProvider.notifier).refresh(silent: true);
      _ref.read(roomsProvider.notifier).refresh(silent: true);
      _ref.read(dashboardProvider.notifier).refresh(silent: true);
    });
    _socket?.on('expense:added', (_) {
      _ref.read(expensesProvider.notifier).refresh(silent: true);
      _ref.read(dashboardProvider.notifier).refresh(silent: true);
    });
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
