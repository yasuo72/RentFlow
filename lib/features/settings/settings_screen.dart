import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/app_surfaces.dart';
import '../auth/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
        children: [
          Text(
            l10n.tr('settings').toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.tr('settingsHeadline'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1535), Color(0xFF0F1728)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.bgCardBorderStrongDark),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDim,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.primaryGlow),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initialsFor(user?.name),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? l10n.tr('familyMember'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${user?.phone ?? '-'}${(user?.email?.isNotEmpty ?? false) ? ' | ${user!.email}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 8),
                      StatusBadge(
                        label: user?.isSuperAdmin ?? false
                            ? l10n.tr('superAdmin').toUpperCase()
                            : l10n.tr('familyRole').toUpperCase(),
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppSectionTitle(
            eyebrow: l10n.tr('preferences'),
            title: l10n.tr('securityAndAppearance'),
          ),
          const SizedBox(height: 10),
          AppSectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.dark_mode_rounded,
                  color: AppColors.primary,
                  title: l10n.tr('themeMode'),
                  subtitle:
                      '${l10n.tr('themeModeSubtitle')} - ${_themeModeLabel(l10n, themeMode)}',
                  onTap: () => _showThemeSheet(context, ref),
                ),
                _SettingsTile(
                  icon: Icons.lock_rounded,
                  color: AppColors.accent,
                  title: l10n.tr('biometricLock'),
                  subtitle: auth.biometricAvailable
                      ? l10n.tr('biometricAvailable')
                      : l10n.tr('biometricUnavailable'),
                  trailing: Switch(
                    value: auth.biometricEnabled,
                    onChanged: auth.biometricAvailable
                        ? (value) => ref
                              .read(authControllerProvider.notifier)
                              .setBiometricEnabled(value)
                        : null,
                  ),
                ),
                _SettingsTile(
                  icon: Icons.translate_rounded,
                  color: AppColors.info,
                  title: l10n.tr('language'),
                  subtitle:
                      '${l10n.tr('languageSubtitle')} - ${locale.languageCode == 'hi' ? l10n.tr('hindi') : l10n.tr('english')}',
                  onTap: () => _showLanguageSheet(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppSectionTitle(
            eyebrow: l10n.tr('admin'),
            title: l10n.tr('familyManagement'),
          ),
          const SizedBox(height: 10),
          AppSectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.manage_accounts_rounded,
                  color: AppColors.warning,
                  title: l10n.tr('manageUsers'),
                  subtitle: l10n.tr('manageUsersSubtitle'),
                  onTap: () => context.push('/settings/users'),
                ),
                _SettingsTile(
                  icon: Icons.history_rounded,
                  color: AppColors.info,
                  title: l10n.tr('activityLog'),
                  subtitle: l10n.tr('activityLogSubtitle'),
                  onTap: () => context.push('/settings/activity'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
            label: Text(l10n.tr('logOut')),
          ),
        ],
      ),
    );
  }

  Future<void> _showLanguageSheet(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.read(localeProvider);

    return showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tr('language'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.tr('languageSubtitle'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.tr('english')),
                      selected: locale.languageCode == 'en',
                      onSelected: (_) async {
                        await ref
                            .read(localeProvider.notifier)
                            .setLocale(LocaleController.english);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    ChoiceChip(
                      label: Text(l10n.tr('hindi')),
                      selected: locale.languageCode == 'hi',
                      onSelected: (_) async {
                        await ref
                            .read(localeProvider.notifier)
                            .setLocale(LocaleController.hindi);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showThemeSheet(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final themeMode = ref.read(themeModeProvider);

    return showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tr('themeMode'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.tr('themeModeSubtitle'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.tr('followDeviceTheme')),
                      selected: themeMode == ThemeMode.system,
                      onSelected: (_) async {
                        await ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(ThemeMode.system);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    ChoiceChip(
                      label: Text(l10n.tr('lightMode')),
                      selected: themeMode == ThemeMode.light,
                      onSelected: (_) async {
                        await ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(ThemeMode.light);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    ChoiceChip(
                      label: Text(l10n.tr('darkMode')),
                      selected: themeMode == ThemeMode.dark,
                      onSelected: (_) async {
                        await ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(ThemeMode.dark);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _themeModeLabel(AppLocalizations l10n, ThemeMode themeMode) {
    return switch (themeMode) {
      ThemeMode.system => l10n.tr('followDeviceTheme'),
      ThemeMode.light => l10n.tr('lightMode'),
      ThemeMode.dark => l10n.tr('darkMode'),
    };
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
          ],
        ),
      ),
    );
  }
}

String _initialsFor(String? name) {
  final parts = (name ?? 'Family')
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .toList();

  return parts.isEmpty ? 'RF' : parts.join();
}
