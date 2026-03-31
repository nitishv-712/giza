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
    if (widget.editTheme != null) {
      _nameController = TextEditingController(text: widget.editTheme!.name);
      _backgroundColor = widget.editTheme!.bgColor;
      _surfaceColor = widget.editTheme!.surfColor;
      _surface2Color = widget.editTheme!.surf2Color;
      _accentColor = widget.editTheme!.accentCol;
      _accent2Color = widget.editTheme!.accent2Col;
      _textPrimaryColor = widget.editTheme!.textPriCol;
      _textSecondaryColor = widget.editTheme!.textSecCol;
    } else {
      _nameController = TextEditingController();
      _backgroundColor = const Color(0xFF0C0C14);
      _surfaceColor = const Color(0xFF141420);
      _surface2Color = const Color(0xFF1C1C2A);
      _accentColor = const Color(0xFFFF8C42);
      _accent2Color = const Color(0xFFFF5F6D);
      _textPrimaryColor = const Color(0xFFF0EFFF);
      _textSecondaryColor = const Color(0xFF6E6E8A);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickColor(String colorName, Color currentColor) async {
    Color? pickedColor;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pick $colorName'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) => pickedColor = color,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (pickedColor != null) {
                setState(() {
                  switch (colorName) {
                    case 'Background':
                      _backgroundColor = pickedColor!;
                      break;
                    case 'Surface':
                      _surfaceColor = pickedColor!;
                      break;
                    case 'Surface 2':
                      _surface2Color = pickedColor!;
                      break;
                    case 'Accent':
                      _accentColor = pickedColor!;
                      break;
                    case 'Accent 2':
                      _accent2Color = pickedColor!;
                      break;
                    case 'Text Primary':
                      _textPrimaryColor = pickedColor!;
                      break;
                    case 'Text Secondary':
                      _textSecondaryColor = pickedColor!;
                      break;
                  }
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTheme() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a theme name')),
      );
      return;
    }

    final theme = CustomTheme.fromColors(
      id: widget.editTheme?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      backgroundColor: _backgroundColor,
      surfaceColor: _surfaceColor,
      surface2Color: _surface2Color,
      accentColor: _accentColor,
      accent2Color: _accent2Color,
      textPrimaryColor: _textPrimaryColor,
      textSecondaryColor: _textSecondaryColor,
    );

    final provider = context.read<ThemeProvider>();
    if (widget.editTheme != null) {
      await provider.updateCustomTheme(theme);
    } else {
      await provider.createCustomTheme(theme);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: _textPrimaryColor,
        title: Text(
          widget.editTheme != null ? 'Edit Theme' : 'Create Theme',
          style: TextStyle(color: _textPrimaryColor),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.check_rounded, color: _accentColor),
            onPressed: _saveTheme,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Name
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _nameController,
              style: TextStyle(color: _textPrimaryColor),
              decoration: InputDecoration(
                labelText: 'Theme Name',
                labelStyle: TextStyle(color: _textSecondaryColor),
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Preview Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preview',
                  style: TextStyle(
                    color: _accentColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface2Color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Song Title',
                        style: TextStyle(
                          color: _textPrimaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Artist Name',
                        style: TextStyle(
                          color: _textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _accentColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Play',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _accent2Color,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Favorite',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Color Pickers
          _buildColorSection('Colors', [
            _ColorTile(
              name: 'Background',
              color: _backgroundColor,
              onTap: () => _pickColor('Background', _backgroundColor),
            ),
            _ColorTile(
              name: 'Surface',
              color: _surfaceColor,
              onTap: () => _pickColor('Surface', _surfaceColor),
            ),
            _ColorTile(
              name: 'Surface 2',
              color: _surface2Color,
              onTap: () => _pickColor('Surface 2', _surface2Color),
            ),
            _ColorTile(
              name: 'Accent',
              color: _accentColor,
              onTap: () => _pickColor('Accent', _accentColor),
            ),
            _ColorTile(
              name: 'Accent 2',
              color: _accent2Color,
              onTap: () => _pickColor('Accent 2', _accent2Color),
            ),
            _ColorTile(
              name: 'Text Primary',
              color: _textPrimaryColor,
              onTap: () => _pickColor('Text Primary', _textPrimaryColor),
            ),
            _ColorTile(
              name: 'Text Secondary',
              color: _textSecondaryColor,
              onTap: () => _pickColor('Text Secondary', _textSecondaryColor),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildColorSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: _accentColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ColorTile extends StatelessWidget {
  final String name;
  final Color color;
  final VoidCallback onTap;

  const _ColorTile({
    required this.name,
    required this.color,
    required this.onTap,
  });

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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white54, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
