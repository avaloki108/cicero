import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme_cicero.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : const Color(0xFFF2F2F7);
    final sectionColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(title: const Text('Settings'), backgroundColor: bgColor),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          
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
                  value: "California", // This can be connected to provider
                  isFirst: true,
                  onTap: () {},
                ),
                _Divider(),
                _SettingsTile(
                  icon: LucideIcons.moon,
                  title: "Dark Mode",
                  trailing: Switch.adaptive(
                    value: isDark, 
                    onChanged: (v) {}, // Connect to ThemeProvider later
                    activeTrackColor: CiceroTheme.primaryLight,
                  ),
                  isLast: true,
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
            Icon(icon, size: 20, color: iconColor ?? (isDark ? Colors.white : Colors.black)),
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
      color: Colors.grey.withValues(alpha: 0.2)
    );
  }
}
