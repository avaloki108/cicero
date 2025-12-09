import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme_cicero.dart';
import 'providers.dart';
import 'subscription_screen.dart';
import '../services/auth_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : const Color(0xFFF2F2F7);
    final sectionColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final stateAbbr = ref.watch(selectedStateProvider);
    final stateName = abbrToStateName[stateAbbr] ?? stateAbbr;
    final themeMode = ref.watch(themeModeProvider);
    final themeLabel = themeMode == ThemeMode.system
        ? 'System'
        : themeMode == ThemeMode.dark
        ? 'Dark'
        : 'Light';
    final apiBaseUrl = ref.watch(apiBaseUrlProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: bgColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),

          // SECTION 0: ACCOUNT
          _SectionHeader(title: "ACCOUNT"),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: sectionColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: LucideIcons.crown,
                  title: "Subscription",
                  isFirst: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SubscriptionScreen(),
                      ),
                    );
                  },
                ),
                _Divider(),
                _SettingsTile(
                  icon: LucideIcons.logOut,
                  title: "Sign Out",
                  titleColor: Colors.red,
                  iconColor: Colors.red,
                  isLast: true,
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign Out'),
                        content: const Text('Are you sure you want to sign out?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      final authService = ref.read(authServiceProvider);
                      await authService.signOut();
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // SECTION 1: PREFERENCES
          _SectionHeader(title: "PREFERENCES"),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: sectionColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: LucideIcons.mapPin,
                  title: "Primary State",
                  value: stateName,
                  isFirst: true,
                  onTap: () => _showStatePicker(context, ref, stateAbbr),
                ),
                _Divider(),
                _SettingsTile(
                  icon: LucideIcons.moon,
                  title: "Dark Mode",
                  value: themeLabel,
                  trailing: Switch.adaptive(
                    value: themeMode == ThemeMode.dark,
                    onChanged: (v) => ref
                        .read(themeModeProvider.notifier)
                        .setMode(v ? ThemeMode.dark : ThemeMode.system),
                    activeTrackColor: CiceroTheme.primaryLight,
                  ),
                  isLast: false,
                ),
                _Divider(),
                _SettingsTile(
                  icon: LucideIcons.server,
                  title: "Server Address",
                  value: apiBaseUrl,
                  isLast: true,
                  onTap: () => _showBaseUrlDialog(context, ref, apiBaseUrl),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // SECTION 2: SECURITY
          _SectionHeader(title: "SECURITY"),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: sectionColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: LucideIcons.fingerprint,
                  title: "Biometric Unlock",
                  trailing: Switch.adaptive(
                    value: true,
                    onChanged: (v) {},
                    activeTrackColor: CiceroTheme.primaryLight,
                  ),
                  isFirst: true,
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // SECTION 3: DATA
          _SectionHeader(title: "DATA & PRIVACY"),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: sectionColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _SettingsTile(
              icon: LucideIcons.trash2,
              title: "Clear All Data",
              titleColor: Colors.red,
              iconColor: Colors.red,
              isFirst: true,
              isLast: true,
              onTap: () {},
            ),
          ),

          const SizedBox(height: 40),
          const Center(
            child: Text(
              "Cicero v1.0.0\nAI-powered legal assistance",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

void _showStatePicker(BuildContext context, WidgetRef ref, String currentAbbr) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select primary state',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...stateNameToAbbr.entries.map(
                (entry) => RadioListTile<String>(
                  value: entry.value,
                  // ignore: deprecated_member_use
                  groupValue: currentAbbr,
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    if (val == null) return;
                    ref.read(selectedStateProvider.notifier).setStateAbbr(val);
                    Navigator.of(ctx).pop();
                  },
                  title: Text(entry.key),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _showBaseUrlDialog(
  BuildContext context,
  WidgetRef ref,
  String currentUrl,
) async {
  final controller = TextEditingController(text: currentUrl);
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Server Address'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Base URL',
          hintText: 'http://10.0.2.2:8000',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            ref.read(apiBaseUrlProvider.notifier).setBaseUrl(controller.text);
            Navigator.of(ctx).pop();
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

// --- Helper Components for iOS-style Settings ---

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;
  final Color? titleColor;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.value,
    this.trailing,
    this.isFirst = false,
    this.isLast = false,
    this.onTap,
    this.titleColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(12) : Radius.zero,
        bottom: isLast ? const Radius.circular(12) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? (isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: titleColor ?? (isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            if (trailing != null) trailing!,
            if (trailing == null && value == null)
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 48,
      color: Colors.grey.withValues(alpha: 0.2),
    );
  }
}
