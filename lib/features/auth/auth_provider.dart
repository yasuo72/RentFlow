import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/providers/app_providers.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/socket_service.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
    this.token,
    this.biometricEnabled = false,
    this.biometricAvailable = false,
    this.requiresBiometricUnlock = false,
    this.biometricPromptActive = false,
    this.hasSavedSession = false,
  });

  const AuthState.loading()
    : status = AuthStatus.loading,
      user = null,
      errorMessage = null,
      token = null,
      biometricEnabled = false,
      biometricAvailable = false,
      requiresBiometricUnlock = false,
      biometricPromptActive = false,
      hasSavedSession = false;

  const AuthState.unauthenticated({
    this.errorMessage,
    this.biometricEnabled = false,
    this.biometricAvailable = false,
    this.requiresBiometricUnlock = false,
    this.biometricPromptActive = false,
    this.hasSavedSession = false,
  }) : status = AuthStatus.unauthenticated,
       user = null,
       token = null;

  const AuthState.authenticated({
    required this.user,
    required this.token,
    this.biometricEnabled = false,
    this.biometricAvailable = false,
    this.requiresBiometricUnlock = false,
    this.biometricPromptActive = false,
    this.hasSavedSession = true,
  }) : status = AuthStatus.authenticated,
       errorMessage = null,
       assert(user != null),
       assert(token != null);

  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;
  final String? token;
  final bool biometricEnabled;
  final bool biometricAvailable;
  final bool requiresBiometricUnlock;
  final bool biometricPromptActive;
  final bool hasSavedSession;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
    String? token,
    bool? biometricEnabled,
    bool? biometricAvailable,
    bool? requiresBiometricUnlock,
    bool? biometricPromptActive,
    bool? hasSavedSession,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      token: token ?? this.token,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      requiresBiometricUnlock:
          requiresBiometricUnlock ?? this.requiresBiometricUnlock,
      biometricPromptActive:
          biometricPromptActive ?? this.biometricPromptActive,
      hasSavedSession: hasSavedSession ?? this.hasSavedSession,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  bool _bootstrapped = false;

  @override
  AuthState build() {
    if (!_bootstrapped) {
      _bootstrapped = true;
      Future.microtask(_bootstrap);
    }
    return const AuthState.loading();
  }

  Future<void> _bootstrap() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final repo = ref.read(authRepositoryProvider);
    final notificationService = ref.read(notificationServiceProvider);
    final token = await repo.readSavedToken();
    final canUseBiometrics = await _checkBiometricAvailability();
    final biometricEnabled = prefs.getBool(AppStrings.biometricKey) ?? false;

    if (token == null || token.isEmpty) {
      state = AuthState.unauthenticated(
        biometricAvailable: canUseBiometrics,
        biometricEnabled: biometricEnabled,
        hasSavedSession: false,
      );
      return;
    }

    try {
      final user = await repo.getMe();
      ref.read(socketServiceProvider).connect(token);
      unawaited(_syncNotifications());
      unawaited(
        notificationService.startTokenSync((nextToken) async {
          await repo.updateFcmToken(nextToken);
        }),
      );
      state = AuthState.authenticated(
        user: user,
        token: token,
        biometricAvailable: canUseBiometrics,
        biometricEnabled: biometricEnabled,
        requiresBiometricUnlock: biometricEnabled,
        hasSavedSession: true,
      );
    } catch (_) {
      await repo.logout();
      state = AuthState.unauthenticated(
        biometricAvailable: canUseBiometrics,
        biometricEnabled: biometricEnabled,
        hasSavedSession: false,
      );
    }
  }

  Future<void> login(String phone, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final notificationService = ref.read(notificationServiceProvider);
      final result = await ref
          .read(authRepositoryProvider)
          .login(phone: phone, password: password);
      ref.read(socketServiceProvider).connect(result.token);
      unawaited(_syncNotifications());
      unawaited(
        notificationService.startTokenSync((nextToken) async {
          await ref.read(authRepositoryProvider).updateFcmToken(nextToken);
        }),
      );
      state = AuthState.authenticated(
        user: result.user,
        token: result.token,
        biometricAvailable: state.biometricAvailable,
        biometricEnabled: state.biometricEnabled,
        requiresBiometricUnlock: false,
        biometricPromptActive: false,
        hasSavedSession: true,
      );
    } catch (_) {
      state = AuthState.unauthenticated(
        errorMessage: 'Unable to log in. Please check your phone and password.',
        biometricAvailable: state.biometricAvailable,
        biometricEnabled: state.biometricEnabled,
        hasSavedSession: false,
      );
    }
  }

  Future<void> loginWithBiometrics() async {
    final repo = ref.read(authRepositoryProvider);
    final notificationService = ref.read(notificationServiceProvider);
    final token = await repo.readSavedToken();

    if (token == null) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'No previous session found for biometric login.',
        hasSavedSession: false,
      );
      return;
    }

    final authenticated = await _authenticateWithBiometrics(
      reason: 'Unlock RentFlow to continue',
    );

    if (!authenticated) {
      return;
    }

    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final user = await repo.getMe();
      ref.read(socketServiceProvider).connect(token);
      unawaited(
        notificationService.startTokenSync((nextToken) async {
          await repo.updateFcmToken(nextToken);
        }),
      );
      state = AuthState.authenticated(
        user: user,
        token: token,
        biometricAvailable: state.biometricAvailable,
        biometricEnabled: state.biometricEnabled,
        requiresBiometricUnlock: false,
        biometricPromptActive: false,
        hasSavedSession: true,
      );
    } catch (_) {
      await repo.logout();
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Your previous session expired. Please log in again.',
        requiresBiometricUnlock: false,
        biometricPromptActive: false,
        hasSavedSession: false,
      );
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled && !state.biometricAvailable) {
      state = state.copyWith(
        errorMessage: 'Fingerprint unlock is not available on this device.',
      );
      return;
    }

    if (enabled) {
      final confirmed = await _authenticateWithBiometrics(
        reason: 'Confirm your fingerprint to enable app lock',
      );
      if (!confirmed) {
        return;
      }
    }

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(AppStrings.biometricKey, enabled);
    state = state.copyWith(
      biometricEnabled: enabled,
      requiresBiometricUnlock: false,
      errorMessage: null,
    );
  }

  void lockApp() {
    if (state.status != AuthStatus.authenticated || !state.biometricEnabled) {
      return;
    }

    state = state.copyWith(
      requiresBiometricUnlock: true,
      biometricPromptActive: false,
      errorMessage: null,
    );
  }

  Future<void> unlockAppWithBiometrics() async {
    if (state.status != AuthStatus.authenticated ||
        !state.biometricEnabled ||
        !state.requiresBiometricUnlock ||
        state.biometricPromptActive) {
      return;
    }

    final unlocked = await _authenticateWithBiometrics(
      reason: 'Use your fingerprint to unlock RentFlow',
    );

    if (!unlocked) {
      return;
    }

    state = state.copyWith(
      requiresBiometricUnlock: false,
      biometricPromptActive: false,
      errorMessage: null,
    );
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).updateFcmToken(null);
    } catch (_) {
      // Ignore FCM token cleanup issues during logout.
    }

    await ref.read(authRepositoryProvider).logout();
    ref.read(socketServiceProvider).disconnect();
    state = AuthState.unauthenticated(
      biometricAvailable: state.biometricAvailable,
      biometricEnabled: state.biometricEnabled,
      hasSavedSession: false,
    );
  }

  Future<void> _syncNotifications() async {
    final token = await ref.read(notificationServiceProvider).getFcmToken();
    await ref.read(authRepositoryProvider).updateFcmToken(token);
  }

  Future<bool> _checkBiometricAvailability() async {
    final localAuth = ref.read(localAuthenticationProvider);

    try {
      final deviceSupported = await localAuth.isDeviceSupported();
      final canCheckBiometrics = await localAuth.canCheckBiometrics;
      final availableBiometrics = await localAuth.getAvailableBiometrics();

      return deviceSupported &&
          canCheckBiometrics &&
          availableBiometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _authenticateWithBiometrics({
    required String reason,
  }) async {
    final localAuth = ref.read(localAuthenticationProvider);
    state = state.copyWith(
      biometricPromptActive: true,
      errorMessage: null,
    );

    try {
      final authenticated = await localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      state = state.copyWith(
        biometricPromptActive: false,
        errorMessage: null,
      );

      return authenticated;
    } on PlatformException catch (error) {
      state = state.copyWith(
        biometricPromptActive: false,
        errorMessage: error.message ?? 'Fingerprint authentication failed.',
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        biometricPromptActive: false,
        errorMessage: 'Fingerprint authentication was cancelled.',
      );
      return false;
    }
  }
}
