// lib/widgets/language_selector.dart

import 'package:flutter/material.dart';
import '../../../lib_200/providers/settings_provider.dart';
import '../../../lib_200/translations/app_translations.dart';
import 'package:provider/provider.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D36).withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.language,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppTranslations.translate('language', settings.currentLanguage),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildLanguageChip(context, 'en', 'English', settings),
                  _buildLanguageChip(context, 'fr', 'Français', settings),
                  _buildLanguageChip(context, 'es', 'Español', settings),
                ],
              ),
            ],
          ),
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
      selectedColor: const Color(0xFF5E5DE3),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? const Color(0xFF5E5DE3) : Colors.transparent,
          width: 1,
        ),
      ),
    );
  }
}