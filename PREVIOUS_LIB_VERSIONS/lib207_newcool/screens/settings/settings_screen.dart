// lib/screens/settings/settings_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucid_dream_trainer/screens/settings/widgets/sound_selection_grid.dart';
import 'package:lucid_dream_trainer/screens/widgets/language_selector.dart';
import 'package:lucid_dream_trainer/translations/app_translations.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _changePassword(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Change password functionality coming soon')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await AuthService().signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252531),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.white70),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deletion coming soon')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF06070F),
                Color(0xFF100B1A),
                Color(0xFF1C1326),
                Color(0xFF2F1D34),
              ],
              stops: [0.0, 0.3, 0.6, 1.0],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                AppTranslations.translate('settings', settings.currentLanguage),
                style: const TextStyle(color: Colors.white),
              ),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dream Sound Section
                    Text(
                      AppTranslations.translate('dreamSound', settings.currentLanguage),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SoundSelectionGrid(
                      selectedSound: settings.soundTrigger,
                      onSoundSelected: settings.setSoundTrigger,
                    ),
                    const SizedBox(height: 24),

                    // Divider before Language Section
                    Container(
                      height: 1,
                      width: double.infinity,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(height: 24),

                    // Language Section
                    const LanguageSelector(),
                    const SizedBox(height: 24),

                    // Divider before Account Section
                    Container(
                      height: 1,
                      width: double.infinity,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(height: 24),

                    // Account Section with capital A
                    Text(
                      'Account',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Email display
                    Text(
                      user?.email ?? AppTranslations.translate('noEmail', settings.currentLanguage),
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 12),

                    // Change Password Button
                    TextButton(
                      onPressed: () => _changePassword(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      child: Text(
                        AppTranslations.translate('changePassword', settings.currentLanguage),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sign Out Button (now as a text button)
                    TextButton(
                      onPressed: () => _signOut(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      child: Text(
                        AppTranslations.translate('signOut', settings.currentLanguage),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Delete Account Button
                    TextButton(
                      onPressed: () => _deleteAccount(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      child: Text(
                        AppTranslations.translate('deleteAccount', settings.currentLanguage),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}