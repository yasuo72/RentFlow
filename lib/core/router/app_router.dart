import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/expenses/add_expense_screen.dart';
import '../../features/expenses/expenses_list_screen.dart';
import '../../features/navigation/app_shell.dart';
import '../../features/media/image_viewer_screen.dart';
import '../../features/media/pdf_viewer_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/payments/add_payment_screen.dart';
import '../../features/payments/payment_detail_screen.dart';
import '../../features/payments/payment_qr_screen.dart';
import '../../features/payments/payments_list_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/rooms/add_edit_room_screen.dart';
import '../../features/rooms/room_detail_screen.dart';
import '../../features/rooms/rooms_list_screen.dart';
import '../../features/settings/activity_log_screen.dart';
import '../../features/settings/manage_users_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/tenants/add_edit_tenant_screen.dart';
import '../../features/tenants/tenant_detail_screen.dart';
import '../../features/tenants/tenants_list_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rooms',
                builder: (context, state) => const RoomsListScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => AddEditRoomScreen(
                      roomId: state.uri.queryParameters['roomId'],
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) =>
                        RoomDetailScreen(roomId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/payments',
                builder: (context, state) => const PaymentsListScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => AddPaymentScreen(
                      roomId: state.uri.queryParameters['roomId'],
                      tenantId: state.uri.queryParameters['tenantId'],
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => PaymentDetailScreen(
                      paymentId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/expenses',
                builder: (context, state) => const ExpensesListScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const AddExpenseScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'users',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ManageUsersScreen(),
                  ),
                  GoRoute(
                    path: 'activity',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ActivityLogScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/tenants',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TenantsListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => AddEditTenantScreen(
              tenantId: state.uri.queryParameters['tenantId'],
            ),
          ),
          GoRoute(
            path: ':id',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) =>
                TenantDetailScreen(tenantId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/reports',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/viewer/image',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ImageViewerScreen(
          imageUrl: state.uri.queryParameters['url'] ?? '',
          title: state.uri.queryParameters['title'] ?? 'Image',
        ),
      ),
      GoRoute(
        path: '/viewer/pdf',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => PdfViewerScreen(
          documentUrl: state.uri.queryParameters['url'] ?? '',
          title: state.uri.queryParameters['title'] ?? 'Document',
        ),
      ),
      GoRoute(
        path: '/payment-qr',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PaymentQrScreen(),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isLoggingIn = location == '/login';
      final isSplash = location == '/splash';

      if (authState.status == AuthStatus.loading) {
        return isSplash ? null : '/splash';
      }

      if (authState.status == AuthStatus.unauthenticated) {
        return isLoggingIn ? null : '/login';
      }

      if (authState.status == AuthStatus.authenticated &&
          (isLoggingIn || isSplash)) {
        return '/dashboard';
      }

      return null;
    },
  );
});
