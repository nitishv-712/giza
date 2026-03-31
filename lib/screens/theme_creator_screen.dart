// lib/screens/theme_creator_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

import '../models/custom_theme.dart';
import '../providers/theme_provider.dart';

class ThemeCreatorScreen extends StatefulWidget {
  final CustomTheme? editTheme;

  const ThemeCreatorScreen({super.key, this.editTheme});

  @override
  State<ThemeCreatorScreen> createState() => _ThemeCreatorScreenState();
}

class _ThemeCreatorScreenState extends State<ThemeCreatorScreen> {
  late TextEditingController _nameController;
  late Color _backgroundColor;
  late Color _surfaceColor;
  late Color _surface2Color;
  late Color _accentColor;
  late Color _accent2Color;
  late Color _textPrimaryColor;
  late Color _textSecondaryColor;

  @override
  void initState() {
    super.initState();
    final edit = widget.editTheme;
    if (edit != null) {
      _nameController     = TextEditingController(text: edit.name);
      _backgroundColor    = edit.bgColor;
      _surfaceColor       = edit.surfColor;
      _surface2Color      = edit.surf2Color;
      _accentColor        = edit.accentCol;
      _accent2Color       = edit.accent2Col;
      _textPrimaryColor   = edit.textPriCol;
      _textSecondaryColor = edit.textSecCol;
    } else {
      // Default new themes to the app's dark palette
      _nameController     = TextEditingController();
      _backgroundColor    = const Color(0xFF0C0C14);
      _surfaceColor       = const Color(0xFF141420);
      _surface2Color      = const Color(0xFF1C1C2A);
      _accentColor        = const Color(0xFFFF8C42);
      _accent2Color       = const Color(0xFFFF5F6D);
      _textPrimaryColor   = const Color(0xFFF0EFFF);
      _textSecondaryColor = const Color(0xFF6E6E8A);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Color picker dialog ────────────────────────────────────────────────────

  Future<void> _pickColor(String label, Color current,
      void Function(Color) onPicked) async {
    Color picked = current;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // Force the dialog to use the surface color of the theme being built,
        // not whatever the app's active theme says — this gives accurate preview.
        backgroundColor: _surfaceColor,
        title: Text('Pick $label',
            style: TextStyle(color: _textPrimaryColor)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            onColorChanged: (c) => picked = c,
            pickerAreaHeightPercent: 0.8,
            labelTypes: const [],           // cleaner UI, no hex label clutter
            displayThumbColor: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: _textSecondaryColor)),
          ),
          TextButton(
            onPressed: () {
              setState(() => onPicked(picked));
              Navigator.pop(ctx);
            },
            child: Text('Select',
                style: TextStyle(color: _accentColor,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _saveTheme() async {
    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a theme name'),
          backgroundColor: _surface2Color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final theme = CustomTheme.fromColors(
      // Preserve original id & createdAt when editing; generate new ones otherwise.
      id:                 widget.editTheme?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
      name:               trimmed,
      createdAt:          widget.editTheme?.createdAt ?? DateTime.now(),
      backgroundColor:    _backgroundColor,
      surfaceColor:       _surfaceColor,
      surface2Color:      _surface2Color,
      accentColor:        _accentColor,
      accent2Color:       _accent2Color,
      textPrimaryColor:   _textPrimaryColor,
      textSecondaryColor: _textSecondaryColor,
    );

    final provider = context.read<ThemeProvider>();
    if (widget.editTheme != null) {
      await provider.updateCustomTheme(theme);
    } else {
      await provider.createCustomTheme(theme);
    }

    if (mounted) Navigator.pop(context);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // The scaffold uses the *being-built* colors so the user sees live feedback.
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: _textPrimaryColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.editTheme != null ? 'Edit Theme' : 'Create Theme',
          style: TextStyle(
            color: _textPrimaryColor,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saveTheme,
              style: TextButton.styleFrom(
                backgroundColor: _accentColor.withOpacity(0.15),
                foregroundColor: _accentColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
              ),
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Name field ───────────────────────────────────────────────────
          _sectionLabel('Theme Name'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _textPrimaryColor.withOpacity(0.10), width: 0.5),
            ),
            child: TextField(
              controller: _nameController,
              style: TextStyle(
                  color: _textPrimaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
              cursorColor: _accentColor,
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle:
                    TextStyle(color: _textSecondaryColor, fontSize: 13),
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Live preview ─────────────────────────────────────────────────
          _sectionLabel('Preview'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _textPrimaryColor.withOpacity(0.10), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mock song tile
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _surface2Color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: _accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.music_note_rounded,
                            color: _accentColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Song Title',
                                style: TextStyle(
                                    color: _textPrimaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text('Artist Name',
                                style: TextStyle(
                                    color: _textSecondaryColor,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(Icons.download_outlined,
                          color: _textSecondaryColor, size: 20),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Mock mini player
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _accentColor.withOpacity(0.15),
                        _accent2Color.withOpacity(0.10),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _accentColor.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text('Now Playing…',
                            style: TextStyle(
                                color: _textPrimaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        width: 32, height: 32,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [_accentColor, _accent2Color]),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.pause_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Color pickers ─────────────────────────────────────────────────
          _sectionLabel('Colors'),
          Container(
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _textPrimaryColor.withOpacity(0.10), width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _ColorTile(
                  name: 'Background',
                  description: 'Main screen background',
                  color: _backgroundColor,
                  textColor: _textPrimaryColor,
                  textSecColor: _textSecondaryColor,
                  onTap: () => _pickColor('Background', _backgroundColor,
                      (c) => _backgroundColor = c),
                ),
                _divider(),
                _ColorTile(
                  name: 'Surface',
                  description: 'Card & dialog backgrounds',
                  color: _surfaceColor,
                  textColor: _textPrimaryColor,
                  textSecColor: _textSecondaryColor,
                  onTap: () => _pickColor('Surface', _surfaceColor,
                      (c) => _surfaceColor = c),
                ),
                _divider(),
                _ColorTile(
                  name: 'Surface 2',
                  description: 'Nested surface / icon backgrounds',
                  color: _surface2Color,
                  textColor: _textPrimaryColor,
                  textSecColor: _textSecondaryColor,
                  onTap: () => _pickColor('Surface 2', _surface2Color,
                      (c) => _surface2Color = c),
                ),
                _divider(),
                _ColorTile(
                  name: 'Accent',
                  description: 'Primary highlights & controls',
                  color: _accentColor,
                  textColor: _textPrimaryColor,
                  textSecColor: _textSecondaryColor,
                  onTap: () => _pickColor('Accent', _accentColor,
                      (c) => _accentColor = c),
                ),
                _divider(),
                _ColorTile(
                  name: 'Accent 2',
                  description: 'Secondary highlights & destructive actions',
                  color: _accent2Color,
                  textColor: _textPrimaryColor,
                  textSecColor: _textSecondaryColor,
                  onTap: () => _pickColor('Accent 2', _accent2Color,
                      (c) => _accent2Color = c),
                ),
                _divider(),
                _ColorTile(
                  name: 'Text Primary',
                  description: 'Main labels & titles',
                  color: _textPrimaryColor,
                  textColor: _textPrimaryColor,
                  textSecColor: _textSecondaryColor,
                  onTap: () => _pickColor('Text Primary', _textPrimaryColor,
                      (c) => _textPrimaryColor = c),
                ),
                _divider(),
                _ColorTile(
                  name: 'Text Secondary',
                  description: 'Subtitles & placeholders',
                  color: _textSecondaryColor,
                  textColor: _textPrimaryColor,
                  textSecColor: _textSecondaryColor,
                  onTap: () => _pickColor(
                      'Text Secondary', _textSecondaryColor,
                      (c) => _textSecondaryColor = c),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Small helpers ──────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: _accentColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _divider() => Divider(
        height: 0.5,
        thickness: 0.5,
        color: _textPrimaryColor.withOpacity(0.08),
        indent: 16,
        endIndent: 16,
      );
}

// ── _ColorTile ─────────────────────────────────────────────────────────────

class _ColorTile extends StatelessWidget {
  final String name;
  final String description;
  final Color color;
  final Color textColor;       // the theme-being-built's text primary
  final Color textSecColor;    // the theme-being-built's text secondary
  final VoidCallback onTap;

  const _ColorTile({
    required this.name,
    required this.description,
    required this.color,
    required this.textColor,
    required this.textSecColor,
    required this.onTap,
  });

  /// Returns the hex string for a color, e.g. "#FF8C42".
  String _hex(Color c) =>
      '#${c.value.toRadixString(16).substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Color swatch
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    // Use a contrast-aware border so the swatch is always
                    // visible regardless of how close it is to the surface.
                    color: textColor.withOpacity(0.18),
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Labels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color:      textColor,
                        fontSize:   15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                          color: textSecColor, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Hex badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _hex(color),
                  style: TextStyle(
                    color:      textSecColor,
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ),

              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: textSecColor, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}