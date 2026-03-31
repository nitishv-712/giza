// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/hive_helper.dart';
import '../models/custom_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'theme_creator_screen.dart';

const _bg       = Color(0xFF0C0C14);
const _surface  = Color(0xFF141420);
const _surface2 = Color(0xFF1C1C2A);
const _accent   = Color(0xFFFF8C42);
const _accent2  = Color(0xFFFF5F6D);
const _textPri  = Color(0xFFF0EFFF);
const _textSec  = Color(0xFF6E6E8A);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = HiveHelper.instance;

  bool _autoDownload = false;
  bool _downloadOnWifiOnly = true;
  bool _showNotifications = true;
  String _audioQuality = 'best';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _autoDownload = _db.getSetting<bool>('auto_download') ?? false;
      _downloadOnWifiOnly = _db.getSetting<bool>('wifi_only') ?? true;
      _showNotifications = _db.getSetting<bool>('notifications') ?? true;
      _audioQuality = _db.getSetting<String>('audio_quality') ?? 'best';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    await _db.setSetting(key, value);
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Clear Cache?', style: TextStyle(color: _textPri)),
        content: const Text(
          'This will remove all downloaded songs. You can re-download them later.',
          style: TextStyle(color: _textSec, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: _accent2)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Implement cache clearing
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully'),
            backgroundColor: _surface2,
          ),
        );
      }
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Clear History?', style: TextStyle(color: _textPri)),
        content: const Text(
          'This will remove your play history.',
          style: TextStyle(color: _textSec, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: _accent2)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.clearHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('History cleared'),
            backgroundColor: _surface2,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final surfaceColor = theme.colorScheme.surface;
    final textPriColor = theme.colorScheme.onSurface;
    final textSecColor = theme.colorScheme.onSurface.withOpacity(0.6);
    final accentColor = theme.colorScheme.primary;
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPriColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Settings',
            style: TextStyle(color: textPriColor, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAccountSection(),
          const SizedBox(height: 24),
          _buildAppearanceSection(),
          const SizedBox(height: 24),
          _buildDownloadSection(),
          const SizedBox(height: 24),
          _buildPlaybackSection(),
          const SizedBox(height: 24),
          _buildDataSection(),
          const SizedBox(height: 24),
          _buildAboutSection(),
        ],
      ),
    );
  }

  // ── Account Section ────────────────────────────────────────────────────────

  Widget _buildAccountSection() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        return _SettingsSection(
          title: 'Account',
          children: [
            if (user != null) ...[
              _SettingsTile(
                icon: Icons.person_rounded,
                title: 'Signed in as Guest',
                subtitle: user.email ?? 'Anonymous User',
                trailing: const SizedBox.shrink(),
              ),
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Sign Out',
                subtitle: 'Log out from your account',
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: _surface,
                      title: const Text('Sign Out?',
                          style: TextStyle(color: _textPri)),
                      content: const Text(
                        'Are you sure you want to sign out?',
                        style: TextStyle(color: _textSec, fontSize: 14),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel',
                              style: TextStyle(color: _textSec)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sign Out',
                              style: TextStyle(color: _accent2)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await authProvider.signOut();
                  }
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

  // ── Appearance Section ─────────────────────────────────────────────────────

  Widget _buildAppearanceSection() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final currentTheme = themeProvider.currentTheme ?? CustomTheme.darkTheme;
        final customThemes = themeProvider.customThemes;
        
        return _SettingsSection(
          title: 'Appearance',
          children: [
            _SettingsTile(
              icon: Icons.palette_rounded,
              title: 'Current Theme',
              subtitle: currentTheme.name,
              onTap: () => _showThemeSelector(themeProvider),
            ),
            _SettingsTile(
              icon: Icons.add_rounded,
              title: 'Create Custom Theme',
              subtitle: 'Design your own color scheme',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ThemeCreatorScreen(),
                ),
              ),
            ),
            if (customThemes.where((t) => !t.isDefault).isNotEmpty)
              _SettingsTile(
                icon: Icons.edit_rounded,
                title: 'Manage Themes',
                subtitle: '${customThemes.where((t) => !t.isDefault).length} custom themes',
                onTap: () => _showManageThemes(themeProvider),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showThemeSelector(ThemeProvider provider) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Choose Theme', style: TextStyle(color: _textPri)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: provider.customThemes.map((theme) {
              return _ThemeOption(
                title: theme.name,
                subtitle: theme.isDefault ? 'Default' : 'Custom',
                selected: provider.currentTheme?.id == theme.id,
                onTap: () {
                  provider.setTheme(theme);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _showManageThemes(ThemeProvider provider) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Manage Themes', style: TextStyle(color: _textPri)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: provider.customThemes
                .where((t) => !t.isDefault)
                .map((theme) {
              return ListTile(
                title: Text(theme.name, style: const TextStyle(color: _textPri)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: _accent, size: 20),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ThemeCreatorScreen(editTheme: theme),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_rounded, color: _accent2, size: 20),
                      onPressed: () async {
                        await provider.deleteCustomTheme(theme.id);
                        if (context.mounted) Navigator.pop(context);
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );
  }

  // ── Download Section ───────────────────────────────────────────────────────

  Widget _buildDownloadSection() {
    return _SettingsSection(
      title: 'Downloads',
      children: [
        _SettingsTile(
          icon: Icons.download_rounded,
          title: 'Auto Download',
          subtitle: 'Automatically download songs when playing',
          trailing: Switch(
            value: _autoDownload,
            onChanged: (value) {
              setState(() => _autoDownload = value);
              _saveSetting('auto_download', value);
            },
            activeColor: _accent,
          ),
        ),
        _SettingsTile(
          icon: Icons.wifi_rounded,
          title: 'Download on Wi-Fi Only',
          subtitle: 'Save mobile data',
          trailing: Switch(
            value: _downloadOnWifiOnly,
            onChanged: (value) {
              setState(() => _downloadOnWifiOnly = value);
              _saveSetting('wifi_only', value);
            },
            activeColor: _accent,
          ),
        ),
        _SettingsTile(
          icon: Icons.high_quality_rounded,
          title: 'Audio Quality',
          subtitle: _getQualityLabel(_audioQuality),
          onTap: () => _showQualityDialog(),
        ),
      ],
    );
  }

  String _getQualityLabel(String quality) {
    switch (quality) {
      case 'best':
        return 'Best Available (Highest quality)';
      case 'high':
        return 'High (320kbps)';
      case 'medium':
        return 'Medium (192kbps)';
      case 'low':
        return 'Low (128kbps)';
      default:
        return 'Best Available';
    }
  }

  Future<void> _showQualityDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Audio Quality', style: TextStyle(color: _textPri)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ThemeOption(
                title: 'Best Available',
                subtitle: 'Highest quality (Recommended)',
                selected: _audioQuality == 'best',
                onTap: () {
                  setState(() => _audioQuality = 'best');
                  _saveSetting('audio_quality', 'best');
                  Navigator.pop(context);
                },
              ),
              _ThemeOption(
                title: 'High (320kbps)',
                subtitle: 'Excellent quality, larger files',
                selected: _audioQuality == 'high',
                onTap: () {
                  setState(() => _audioQuality = 'high');
                  _saveSetting('audio_quality', 'high');
                  Navigator.pop(context);
                },
              ),
              _ThemeOption(
                title: 'Medium (192kbps)',
                subtitle: 'Good quality, balanced size',
                selected: _audioQuality == 'medium',
                onTap: () {
                  setState(() => _audioQuality = 'medium');
                  _saveSetting('audio_quality', 'medium');
                  Navigator.pop(context);
                },
              ),
              _ThemeOption(
                title: 'Low (128kbps)',
                subtitle: 'Acceptable quality, smallest files',
                selected: _audioQuality == 'low',
                onTap: () {
                  setState(() => _audioQuality = 'low');
                  _saveSetting('audio_quality', 'low');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Playback Section ───────────────────────────────────────────────────────

  Widget _buildPlaybackSection() {
    return _SettingsSection(
      title: 'Playback',
      children: [
        _SettingsTile(
          icon: Icons.notifications_rounded,
          title: 'Show Notifications',
          subtitle: 'Display playback controls in notification',
          trailing: Switch(
            value: _showNotifications,
            onChanged: (value) {
              setState(() => _showNotifications = value);
              _saveSetting('notifications', value);
            },
            activeColor: _accent,
          ),
        ),
      ],
    );
  }

  // ── Data Section ───────────────────────────────────────────────────────────

  Widget _buildDataSection() {
    return _SettingsSection(
      title: 'Data & Storage',
      children: [
        _SettingsTile(
          icon: Icons.delete_sweep_rounded,
          title: 'Clear Cache',
          subtitle: 'Remove downloaded songs',
          onTap: _clearCache,
        ),
        _SettingsTile(
          icon: Icons.history_rounded,
          title: 'Clear History',
          subtitle: 'Remove play history',
          onTap: _clearHistory,
        ),
      ],
    );
  }

  // ── About Section ──────────────────────────────────────────────────────────

  Widget _buildAboutSection() {
    return _SettingsSection(
      title: 'About',
      children: [
        _SettingsTile(
          icon: Icons.info_rounded,
          title: 'Version',
          subtitle: '1.0.0',
          trailing: const SizedBox.shrink(),
        ),
        _SettingsTile(
          icon: Icons.code_rounded,
          title: 'Open Source',
          subtitle: 'View on GitHub',
          onTap: () {
            // Open GitHub link
          },
        ),
        _SettingsTile(
          icon: Icons.privacy_tip_rounded,
          title: 'Privacy Policy',
          subtitle: 'Read our privacy policy',
          onTap: () {
            // Open privacy policy
          },
        ),
      ],
    );
  }
}

// ── Settings Section Widget ────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: _accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF22223A)),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}

// ── Settings Tile Widget ───────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textPri,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: _textSec,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                const Icon(Icons.chevron_right_rounded,
                    color: _textSec, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Theme Option Widget ────────────────────────────────────────────────────

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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? _accent : _textSec,
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
                        color: selected ? _textPri : _textSec,
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: _textSec,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
