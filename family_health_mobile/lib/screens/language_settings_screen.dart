import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/translation_service.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  bool _isLoading = true;
  String _selectedLang = 'en';

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English (US)'},
    {'code': 'es', 'name': 'Español (Spanish)'},
    {'code': 'hi', 'name': 'हिन्दी (Hindi)'},
    {'code': 'te', 'name': 'తెలుగు (Telugu)'},
    {'code': 'fr', 'name': 'Français (French)'},
    {'code': 'de', 'name': 'Deutsch (German)'},
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final profile = await ApiService.getProfileSettings();
    if (profile != null) {
      _selectedLang = profile['preferred_language'] ?? 'en';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _updateLanguage(String langCode) async {
    setState(() => _selectedLang = langCode);
    await TranslationService.instance.setLocale(langCode);
    final res = await ApiService.updateProfileSettings({
      'preferred_language': langCode,
    });
    final success = res['success'] == true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ Language updated successfully!' : '❌ Failed to update language.'),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Language'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _languages.length,
              itemBuilder: (context, index) {
                final lang = _languages[index];
                final code = lang['code']!;
                final name = lang['name']!;
                final isSelected = _selectedLang == code;

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    onTap: () => _updateLanguage(code),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    trailing: isSelected 
                        ? const Icon(Icons.check_rounded, color: Color(0xFF14B8A6)) 
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
