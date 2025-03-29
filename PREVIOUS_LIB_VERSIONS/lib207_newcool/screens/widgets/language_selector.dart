// lib/widgets/language_selector.dart

import 'package:flutter/material.dart';
import 'package:lucid_dream_trainer/providers/settings_provider.dart';
import 'package:lucid_dream_trainer/translations/app_translations.dart';
import 'package:provider/provider.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.translate('language', settings.currentLanguage),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildLanguageChip(context, 'en', 'English', settings),
                _buildLanguageChip(context, 'fr', 'Français', settings),
                _buildLanguageChip(context, 'es', 'Español', settings),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageChip(
    BuildContext context,
    String code,
    String label,
    SettingsProvider settings,
  ) {
    final isSelected = settings.currentLanguage == code;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          settings.setLanguage(code);
        }
      },
      backgroundColor: const Color(0xFF252531),
      selectedColor: Colors.white,
      checkmarkColor: const Color(0xFF252531),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF252531) : Colors.white70,
      ),
    );
  }
}