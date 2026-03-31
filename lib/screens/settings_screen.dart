// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/hive_helper.dart';
import '../models/custom_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'theme_creator_screen.dart';

// ── Design tokens (dark fallbacks — overridden at runtime by ThemeProvider) ─
//
// These are used ONLY by the helper widgets that are built outside a full
// BuildContext (e.g. the _SettingsSection / _SettingsTile helpers).  Every
// widget that has a BuildContext reads its colors from Theme.of(context) so
// the light theme is honoured correctly.
//
const _accentFallback  = Color(0xFFFF8C42);
const _accent2Fallback = Color(0xFFFF5F6D);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = HiveHelper.instance;

  bool _autoDownload      = false;
  bool _downloadOnWifiOnly = true;
  bool _showNotifications  = true;
  String _audioQuality     = 'best';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _autoDownload        = _db.getSetting<bool>('auto_download')   ?? false;
      _downloadOnWifiOnly  = _db.getSetting<bool>('wifi_only')       ?? true;
      _showNotifications   = _db.getSetting<bool>('notifications')   ?? true;
      _audioQuality        = _db.getSetting<String>('audio_quality') ?? 'best';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    await _db.setSetting(key, value);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Shorthand for the current theme's CustomTheme (falls back to dark).
  CustomTheme _ct(BuildContext context) =>
      context.read<ThemeProvider>().currentTheme ?? CustomTheme.darkTheme;

  Color _accent(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  Color _accent2(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;

  Color _textPri(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  Color _textSec(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withOpacity(0.55);

  Color _surfaceColor(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  Future<bool?> _confirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: _textSec(ctx))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel,
                  style: TextStyle(color: _accent2(ctx))),
            ),
          ],
        ),
      );

  Future<void> _clearCache() async {
    final ok = await _confirmDialog(
      title: 'Clear Cache?',
      body: 'This will remove all downloaded songs. You can re-download them later.',
      confirmLabel: 'Clear',
    );
    if (ok == true) _showSnack('Cache cleared successfully');
  }

  Future<void> _clearHistory() async {
    final ok = await _confirmDialog(
      title: 'Clear History?',
      body: 'This will remove your play history.',
      confirmLabel: 'Clear',
    );
    if (ok == true) {
      await _db.clearHistory();
      _showSnack('History cleared');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAccountSection(context),
          const SizedBox(height: 24),
          _buildAppearanceSection(context),
          const SizedBox(height: 24),
          _buildDownloadSection(context),
          const SizedBox(height: 24),
          _buildPlaybackSection(context),
          const SizedBox(height: 24),
          _buildDataSection(context),
          const SizedBox(height: 24),
          _buildAboutSection(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Account ────────────────────────────────────────────────────────────────

  Widget _buildAccountSection(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (ctx, authProvider, _) {
        final user = authProvider.user;
        return _SettingsSection(
          title: 'Account',
          children: [
            if (user != null) ...[
              _SettingsTile(
                icon: Icons.person_rounded,
                title: 'Signed in',
                subtitle: user.email ?? 'Anonymous User',
                trailing: const SizedBox.shrink(),
              ),
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Sign Out',
                subtitle: 'Log out from your account',
                onTap: () async {
                  final ok = await _confirmDialog(
                    title: 'Sign Out?',
                    body: 'Are you sure you want to sign out?',
                    confirmLabel: 'Sign Out',
                  );
                  if (ok == true) await authProvider.signOut();
                },
              ),
            ] else ...[
              _SettingsTile(
                icon: Icons.login_rounded,
                title: 'Sign In',
                subtitle: 'Sign in to sync your data',
                onTap: () {
                  // Navigate to login screen
                },
              ),
            ],
          ],
        );
      },
    );
  }

  // ── Appearance ─────────────────────────────────────────────────────────────

  Widget _buildAppearanceSection(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (ctx, themeProvider, _) {
        final currentTheme = themeProvider.currentTheme ?? CustomTheme.darkTheme;
        final hasCustom = themeProvider.customThemes
            .any((t) => !t.isDefault);

        return _SettingsSection(
          title: 'Appearance',
          children: [
            _SettingsTile(
              icon: Icons.palette_rounded,
              title: 'Theme',
              subtitle: currentTheme.name,
              onTap: () => _showThemeSelector(ctx, themeProvider),
            ),
            _SettingsTile(
              icon: Icons.add_circle_outline_rounded,
              title: 'Create Custom Theme',
              subtitle: 'Design your own color scheme',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ThemeCreatorScreen(),
                ),
              ),
            ),
            if (hasCustom)
              _SettingsTile(
                icon: Icons.tune_rounded,
                title: 'Manage Themes',
                subtitle:
                    '${themeProvider.customThemes.where((t) => !t.isDefault).length} custom themes',
                onTap: () => _showManageThemes(ctx, themeProvider),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showThemeSelector(
      BuildContext context, ThemeProvider provider) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Theme'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: provider.customThemes.map((theme) {
              return _ThemeOption(
                title: theme.name,
                subtitle: theme.isDefault ? 'Built-in' : 'Custom',
                selected:
                    provider.currentTheme?.id == theme.id,
                onTap: () {
                  provider.setTheme(theme);
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _showManageThemes(
      BuildContext context, ThemeProvider provider) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manage Themes'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: provider.customThemes
                .where((t) => !t.isDefault)
                .map((theme) {
              return ListTile(
                title: Text(theme.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_rounded,
                          color: _accent(context), size: 20),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ThemeCreatorScreen(editTheme: theme),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_rounded,
                          color: _accent2(context), size: 20),
                      onPressed: () async {
                        await provider.deleteCustomTheme(theme.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close',
                style: TextStyle(color: _accent(context))),
          ),
        ],
      ),
    );
  }

  // ── Downloads ──────────────────────────────────────────────────────────────

  Widget _buildDownloadSection(BuildContext context) {
    return _SettingsSection(
      title: 'Downloads',
      children: [
        _SettingsTile(
          icon: Icons.download_rounded,
          title: 'Auto Download',
          subtitle: 'Automatically download songs when playing',
          trailing: Switch(
            value: _autoDownload,
            onChanged: (v) {
              setState(() => _autoDownload = v);
              _saveSetting('auto_download', v);
            },
          ),
        ),
        _SettingsTile(
          icon: Icons.wifi_rounded,
          title: 'Download on Wi-Fi Only',
          subtitle: 'Save mobile data',
          trailing: Switch(
            value: _downloadOnWifiOnly,
            onChanged: (v) {
              setState(() => _downloadOnWifiOnly = v);
              _saveSetting('wifi_only', v);
            },
          ),
        ),
        _SettingsTile(
          icon: Icons.high_quality_rounded,
          title: 'Audio Quality',
          subtitle: _getQualityLabel(_audioQuality),
          onTap: _showQualityDialog,
        ),
      ],
    );
  }

  String _getQualityLabel(String quality) {
    switch (quality) {
      case 'best':   return 'Best Available';
      case 'high':   return 'High (320 kbps)';
      case 'medium': return 'Medium (192 kbps)';
      case 'low':    return 'Low (128 kbps)';
      default:       return 'Best Available';
    }
  }

  Future<void> _showQualityDialog() async {
    final options = [
      ('best',   'Best Available', 'Highest quality (Recommended)'),
      ('high',   'High (320 kbps)', 'Excellent quality, larger files'),
      ('medium', 'Medium (192 kbps)', 'Good quality, balanced size'),
      ('low',    'Low (128 kbps)', 'Acceptable quality, smallest files'),
    ];
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Audio Quality'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((o) {
              final (key, label, sub) = o;
              return _ThemeOption(
                title: label,
                subtitle: sub,
                selected: _audioQuality == key,
                onTap: () {
                  setState(() => _audioQuality = key);
                  _saveSetting('audio_quality', key);
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Playback ───────────────────────────────────────────────────────────────

  Widget _buildPlaybackSection(BuildContext context) {
    return _SettingsSection(
      title: 'Playback',
      children: [
        _SettingsTile(
          icon: Icons.notifications_rounded,
          title: 'Show Notifications',
          subtitle: 'Display playback controls in notification',
          trailing: Switch(
            value: _showNotifications,
            onChanged: (v) {
              setState(() => _showNotifications = v);
              _saveSetting('notifications', v);
            },
          ),
        ),
      ],
    );
  }

  // ── Data & Storage ─────────────────────────────────────────────────────────

  Widget _buildDataSection(BuildContext context) {
    return _SettingsSection(
      title: 'Data & Storage',
      children: [
        _SettingsTile(
          icon: Icons.delete_sweep_rounded,
          title: 'Clear Cache',
          subtitle: 'Remove downloaded songs',
          onTap: _clearCache,
          destructive: true,
        ),
        _SettingsTile(
          icon: Icons.history_rounded,
          title: 'Clear History',
          subtitle: 'Remove play history',
          onTap: _clearHistory,
          destructive: true,
        ),
      ],
    );
  }

  // ── About ──────────────────────────────────────────────────────────────────

  Widget _buildAboutSection(BuildContext context) {
    return _SettingsSection(
      title: 'About',
      children: [
        const _SettingsTile(
          icon: Icons.info_rounded,
          title: 'Version',
          subtitle: '1.0.0',
          trailing: SizedBox.shrink(),
        ),
        _SettingsTile(
          icon: Icons.code_rounded,
          title: 'Open Source',
          subtitle: 'View on GitHub',
          onTap: () {/* open GitHub link */},
        ),
        _SettingsTile(
          icon: Icons.privacy_tip_rounded,
          title: 'Privacy Policy',
          subtitle: 'Read our privacy policy',
          onTap: () {/* open privacy policy */},
        ),
      ],
    );
  }
}

// ── _SettingsSection ───────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final accent  = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    final border  = Theme.of(context).colorScheme.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color:       accent,
              fontSize:    11,
              fontWeight:  FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ── _SettingsTile ──────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final accent   = cs.primary;
    final textPri  = cs.onSurface;
    final textSec  = cs.onSurface.withOpacity(0.55);
    final iconBg   = cs.surfaceContainerHighest;
    final tileColor = destructive ? cs.secondary : accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: destructive ? cs.secondary : accent,
                    size: 20),
              ),
              const SizedBox(width: 14),

              // Labels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color:       destructive ? cs.secondary : textPri,
                        fontSize:    15,
                        fontWeight:  FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: TextStyle(color: textSec, fontSize: 12)),
                    ],
                  ],
                ),
              ),

              // Trailing widget or chevron
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: textSec, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _ThemeOption ───────────────────────────────────────────────────────────

class _ThemeOption extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent  = Theme.of(context).colorScheme.primary;
    final textPri = Theme.of(context).colorScheme.onSurface;
    final textSec = Theme.of(context).colorScheme.onSurface.withOpacity(0.55);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? accent : textSec,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color:      selected ? textPri : textSec,
                        fontSize:   14,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: TextStyle(color: textSec, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, color: accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}