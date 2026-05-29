import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../voice/voice_command_sheet.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final List<int> _branchHistory = <int>[];
  bool _handlingBackNavigation = false;

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    final previousIndex = oldWidget.navigationShell.currentIndex;
    final currentIndex = widget.navigationShell.currentIndex;

    if (previousIndex == currentIndex) {
      return;
    }

    if (_handlingBackNavigation) {
      _handlingBackNavigation = false;
      return;
    }

    _branchHistory.add(previousIndex);
  }

  void _onDestinationSelected(int index) {
    if (index == widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(index, initialLocation: true);
      return;
    }

    widget.navigationShell.goBranch(index);
  }

  void _handleSystemBack() {
    if (_branchHistory.isEmpty) {
      return;
    }

    final previousIndex = _branchHistory.removeLast();
    _handlingBackNavigation = true;
    widget.navigationShell.goBranch(previousIndex);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? AppColors.bgCardBorderStrongDark
        : AppColors.bgCardBorderStrongLight;

    final l10n = context.l10n;

    final destinations = <_ShellDestination>[
      _ShellDestination(
        label: l10n.tr('overview'),
        icon: Icons.grid_view_rounded,
      ),
      _ShellDestination(
        label: l10n.tr('rooms'),
        icon: Icons.meeting_room_rounded,
      ),
      _ShellDestination(
        label: l10n.tr('payments'),
        icon: Icons.payments_rounded,
      ),
      _ShellDestination(
        label: l10n.tr('expenses'),
        icon: Icons.receipt_long_rounded,
      ),
      _ShellDestination(
        label: l10n.tr('settings'),
        icon: Icons.settings_rounded,
      ),
    ];

    return PopScope(
      canPop: _branchHistory.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }

        _handleSystemBack();
      },
      child: Scaffold(
        extendBody: true,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [
                      AppColors.bgPrimaryDark,
                      AppColors.bgSecondaryDark,
                      AppColors.bgTertiaryDark,
                    ]
                  : const [
                      AppColors.bgPrimaryLight,
                      AppColors.bgSecondaryLight,
                      Color(0xFFF8F8FE),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (!isOnline)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningDim,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.32),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(l10n.tr('offlineMode'))),
                      ],
                    ),
                  ),
                Expanded(child: widget.navigationShell),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.bgCardDark : Colors.white).withValues(
                alpha: 0.98,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                  blurRadius: 32,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Row(
              children: List.generate(destinations.length, (index) {
                final destination = destinations[index];
                final selected = widget.navigationShell.currentIndex == index;

                return Expanded(
                  child: _ShellNavItem(
                    destination: destination,
                    selected: selected,
                    onTap: () => _onDestinationSelected(index),
                  ),
                );
              }),
            ),
          ),
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 92),
          child: FloatingActionButton.extended(
            heroTag: 'rentflow_voice_assistant',
            onPressed: () => showVoiceCommandSheet(context),
            icon: const Icon(Icons.mic_rounded),
            label: const Text('Voice'),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}

class _ShellNavItem extends StatelessWidget {
  const _ShellNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = AppColors.primary;
    final inactiveColor = isDark
        ? AppColors.textMutedDark
        : AppColors.textSecondaryLight;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: selected ? 1 : 0,
              child: Container(
                width: 34,
                height: 3,
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryDim : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                destination.icon,
                size: 21,
                color: selected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10.5,
                color: selected ? activeColor : inactiveColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
