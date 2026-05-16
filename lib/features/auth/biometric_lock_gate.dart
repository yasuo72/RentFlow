import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import 'auth_provider.dart';

class BiometricLockGate extends ConsumerStatefulWidget {
  const BiometricLockGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends ConsumerState<BiometricLockGate>
    with WidgetsBindingObserver {
  bool _backgrounded = false;
  bool _promptScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgrounded = true;
      return;
    }

    if (state == AppLifecycleState.resumed && _backgrounded) {
      _backgrounded = false;
      ref.read(authControllerProvider.notifier).lockApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final shouldLock =
        authState.status == AuthStatus.authenticated &&
        authState.biometricEnabled &&
        authState.requiresBiometricUnlock;

    if (shouldLock && !authState.biometricPromptActive && !_promptScheduled) {
      _promptScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          return;
        }
        await ref.read(authControllerProvider.notifier).unlockAppWithBiometrics();
        if (mounted) {
          setState(() {
            _promptScheduled = false;
          });
        }
      });
    }

    if (!shouldLock && _promptScheduled) {
      _promptScheduled = false;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (shouldLock)
          ColoredBox(
            color: AppColors.bgPrimaryDark.withValues(alpha: 0.94),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.bgCardDark,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.bgCardBorderStrongDark,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: AppColors.primaryDim,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.primaryGlow),
                          ),
                          child: const Icon(
                            Icons.fingerprint_rounded,
                            size: 38,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Unlock RentFlow',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use your fingerprint to reopen the app and protect rent data.',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        if (authState.errorMessage?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 12),
                          Text(
                            authState.errorMessage!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.warning,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: authState.biometricPromptActive
                                ? null
                                : () => ref
                                      .read(authControllerProvider.notifier)
                                      .unlockAppWithBiometrics(),
                            icon: authState.biometricPromptActive
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.fingerprint_rounded),
                            label: Text(
                              authState.biometricPromptActive
                                  ? 'Checking fingerprint...'
                                  : 'Unlock with fingerprint',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
