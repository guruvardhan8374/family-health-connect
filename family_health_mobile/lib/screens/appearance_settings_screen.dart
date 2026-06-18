import 'package:flutter/material.dart';
import '../main.dart';

class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  State<AppearanceSettingsScreen> createState() => _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  bool _isDark = false;
  String _selectedColor = 'emerald';

  final List<Map<String, dynamic>> _themeColors = [
    {'name': 'blue', 'color': const Color(0xFF3B82F6), 'label': 'Blue'},
    {'name': 'emerald', 'color': const Color(0xFF10B981), 'label': 'Emerald'},
    {'name': 'indigo', 'color': const Color(0xFF6366F1), 'label': 'Indigo'},
    {'name': 'rose', 'color': const Color(0xFFF43F5E), 'label': 'Rose'},
    {'name': 'violet', 'color': const Color(0xFF8B5CF6), 'label': 'Violet'},
    {'name': 'orange', 'color': const Color(0xFFF97316), 'label': 'Orange'},
  ];

  @override
  void initState() {
    super.initState();
    _isDark = ThemeController.instance.themeMode.value == ThemeMode.dark;
    _selectedColor = ThemeController.instance.stringFromColor(ThemeController.instance.themeColor.value);
  }

  Future<void> _updateThemeSettings() async {
    await ThemeController.instance.updateTheme(
      dark: _isDark,
      colorName: _selectedColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Theme Mode'),
          Card(
            elevation: 0,
            color: isDarkTheme ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              value: _isDark,
              onChanged: (val) {
                setState(() => _isDark = val);
                _updateThemeSettings();
              },
              activeThumbColor: ThemeController.instance.themeColor.value,
              title: const Row(
                children: [
                  Icon(Icons.dark_mode_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              subtitle: const Padding(
                padding: EdgeInsets.only(left: 28.0, top: 4),
                child: Text('Toggle between light and dark display modes'),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionHeader('Accent Brand Color'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: _themeColors.length,
            itemBuilder: (context, index) {
              final item = _themeColors[index];
              final name = item['name'] as String;
              final color = item['color'] as Color;
              final label = item['label'] as String;
              final isSelected = _selectedColor == name;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedColor = name);
                  _updateThemeSettings();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isDarkTheme ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? color : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      else
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isDarkTheme ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
