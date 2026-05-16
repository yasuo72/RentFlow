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
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .build(),
    );

    _socket?.onConnect((_) {});
    _socket?.on('payment:new', (_) {
      _ref.invalidate(paymentsProvider);
      _ref.invalidate(roomsProvider);
      _ref.invalidate(dashboardProvider);
      _ref.invalidate(tenantsProvider);
    });
    _socket?.on('room:updated', (_) {
      _ref.invalidate(roomsProvider);
      _ref.invalidate(dashboardProvider);
      _ref.invalidate(tenantsProvider);
    });
    _socket?.on('tenant:added', (_) {
      _ref.invalidate(tenantsProvider);
      _ref.invalidate(roomsProvider);
      _ref.invalidate(dashboardProvider);
    });
    _socket?.on('expense:added', (_) {
      _ref.invalidate(expensesProvider);
      _ref.invalidate(dashboardProvider);
    });
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
