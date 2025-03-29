// lib/screens/settings/settings_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../lib_200/screens/settings/widgets/sound_selection_grid.dart';
import '../../../lib_200/screens/widgets/language_selector.dart';
import '../../../lib_200/translations/app_translations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/settings_provider.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../widgets/common_header.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // AudioPlayer instance for voice previews
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _playingVoice;
  
  @override
  void dispose() {
    _previewPlayer.stop();
    _previewPlayer.dispose();
    super.dispose();
  }
  
  Future<void> _playVoicePreview(String language, String voiceType, double volume) async {
    try {
      final String voiceId = '${language}_${voiceType}';
      
      // Stop if the same voice is already playing
      if (_playingVoice == voiceId) {
        await _previewPlayer.stop();
        setState(() => _playingVoice = null);
        return;
      }
      
      final String promptFile = 'voiceprompts/$voiceId.mp3';
      
      // Stop any currently playing preview
      if (_playingVoice != null) {
        await _previewPlayer.stop();
      }
      
      await _previewPlayer.setVolume(volume);
      await _previewPlayer.play(AssetSource(promptFile));
      
      setState(() => _playingVoice = voiceId);
      
      // Reset playing state when playback completes
      _previewPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() => _playingVoice = null);
        }
      });
    } catch (e) {
      debugPrint('Error playing voice preview: $e');
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.translate('notLoggedIn', settings.currentLanguage)))
      );
      return;
    }

    // Show a dialog to get the user's email for password reset
    final emailController = TextEditingController(text: user.email);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252531),
        title: Text(
          AppTranslations.translate('changePassword', settings.currentLanguage),
          style: const TextStyle(color: Colors.white70),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppTranslations.translate('passwordResetInfo', settings.currentLanguage),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: AppTranslations.translate('email', settings.currentLanguage),
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF5E5DE3)),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              AppTranslations.translate('cancel', settings.currentLanguage),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              AppTranslations.translate('sendResetLink', settings.currentLanguage),
              style: const TextStyle(color: Color(0xFF5E5DE3)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: emailController.text.trim());
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTranslations.translate('passwordResetLinkSent', settings.currentLanguage)),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error sending password reset email: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppTranslations.translate('errorMessage', settings.currentLanguage)}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _changeEmail(BuildContext context) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.translate('notLoggedIn', settings.currentLanguage)))
      );
      return;
    }
    
    // Show dialog to get new email
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252531),
        title: Text(
          AppTranslations.translate('changeEmail', settings.currentLanguage),
          style: const TextStyle(color: Colors.white70),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppTranslations.translate('reAuthRequiredEmail', settings.currentLanguage),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: AppTranslations.translate('newEmail', settings.currentLanguage),
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF5E5DE3)),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: AppTranslations.translate('password', settings.currentLanguage),
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF5E5DE3)),
                ),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(
              AppTranslations.translate('cancel', settings.currentLanguage),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              if (emailController.text.isEmpty || passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppTranslations.translate('allFieldsRequired', settings.currentLanguage)),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.of(context).pop({
                'email': emailController.text.trim(),
                'password': passwordController.text,
              });
            },
            child: Text(
              AppTranslations.translate('update', settings.currentLanguage),
              style: const TextStyle(color: Color(0xFF5E5DE3)),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        // Re-authenticate the user
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: result['password']!,
        );
        
        await user.reauthenticateWithCredential(credential);
        
        // Update the email
        await user.updateEmail(result['email']!);
        
        // Refresh to get updated user data
        await user.reload();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTranslations.translate('emailUpdated', settings.currentLanguage)),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh UI
        setState(() {});
      } catch (e) {
        print('Error changing email: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppTranslations.translate('errorMessage', settings.currentLanguage)}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.translate('notLoggedIn', settings.currentLanguage)))
      );
      return;
    }
    
    // First confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252531),
        title: Text(
          AppTranslations.translate('deleteAccount', settings.currentLanguage),
          style: const TextStyle(color: Colors.white70),
        ),
        content: Text(
          AppTranslations.translate('deleteAccountConfirm', settings.currentLanguage),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppTranslations.translate('cancel', settings.currentLanguage), 
                 style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppTranslations.translate('delete', settings.currentLanguage),
                 style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    
    // Password confirmation for re-authentication
    final passwordController = TextEditingController();
    final passwordConfirmed = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252531),
        title: Text(
          AppTranslations.translate('confirmPassword', settings.currentLanguage),
          style: const TextStyle(color: Colors.white70),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppTranslations.translate('reAuthRequired', settings.currentLanguage),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: AppTranslations.translate('password', settings.currentLanguage),
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF5E5DE3)),
                ),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(
              AppTranslations.translate('cancel', settings.currentLanguage),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(passwordController.text),
            child: Text(
              AppTranslations.translate('confirm', settings.currentLanguage),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (passwordConfirmed == null || passwordConfirmed.isEmpty) return;
    
    try {
      // Create a credential
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: passwordConfirmed,
      );
      
      // Re-authenticate
      await user.reauthenticateWithCredential(credential);
      
      // Delete user data from Firestore first (if needed)
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();
      } catch (e) {
        print('Warning: Could not delete Firestore data: $e');
        // Continue with account deletion even if Firestore deletion fails
      }
      
      // Delete the user
      await user.delete();
      
      // Navigate to login screen and show success message
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppTranslations.translate('accountDeleted', settings.currentLanguage)),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting account: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppTranslations.translate('errorDeletingAccount', settings.currentLanguage)}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  

  Future<void> _signOut(BuildContext context) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    try {
      await AuthService().signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppTranslations.translate('errorSigningOut', settings.currentLanguage)}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add this method to launch URLs
  Future<void> _launchURL(String url, BuildContext context, SettingsProvider settings) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Show error message if URL can't be launched
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${AppTranslations.translate('errorOpeningLink', settings.currentLanguage)}: $url'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppTranslations.translate('errorOpeningLink', settings.currentLanguage)}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
              ),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0).add(const EdgeInsets.only(bottom: 100)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dream Sound Section
                    Text(
                      AppTranslations.translate('triggerMelody', settings.currentLanguage),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white70,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SoundSelectionGrid(
                      selectedSound: settings.soundTrigger,
                      onSoundSelected: settings.setSoundTrigger,
                    ),
                    const SizedBox(height: 16),
                    
                    // Volume Slider
                    Text(
                      AppTranslations.translate('triggerVolume', settings.currentLanguage),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.volume_down,
                          color: Colors.white70,
                          size: 24,
                        ),
                        Expanded(
                          child: Slider(
                            value: settings.soundVolume,
                            min: 0.0,
                            max: 1.0,
                            divisions: 10,
                            activeColor: Colors.deepPurple,
                            inactiveColor: Colors.deepPurple.withOpacity(0.3),
                            onChanged: (value) {
                              Provider.of<SettingsProvider>(context, listen: false)
                                  .setSoundVolume(value);
                            },
                          ),
                        ),
                        const Icon(
                          Icons.volume_up,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Voice Prompt Section
                    Text(
                      AppTranslations.translate('voicePrompt', settings.currentLanguage),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Male voice option
                    InkWell(
                      onTap: () {
                        Provider.of<SettingsProvider>(context, listen: false)
                            .setVoiceType('men');
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: settings.voiceType == 'men'
                              ? const Color(0xFF5E5DE3).withOpacity(0.2)
                              : const Color(0xFF2D2D36).withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: settings.voiceType == 'men'
                                ? const Color(0xFF5E5DE3)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.record_voice_over,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppTranslations.translate('maleVoice', settings.currentLanguage),
                                  style: TextStyle(
                                    color: settings.voiceType == 'men'
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 14,
                                    fontWeight: settings.voiceType == 'men'
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(
                                _playingVoice == '${settings.currentLanguage}_men' 
                                    ? Icons.stop 
                                    : Icons.play_arrow,
                                color: settings.voiceType == 'men'
                                    ? const Color(0xFF5E5DE3)
                                    : Colors.white70,
                                size: 20,
                              ),
                              onPressed: () => _playVoicePreview(settings.currentLanguage, 'men', settings.voiceVolume),
                              tooltip: _playingVoice == '${settings.currentLanguage}_men'
                                  ? AppTranslations.translate('stop', settings.currentLanguage)
                                  : AppTranslations.translate('play', settings.currentLanguage),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Female voice option
                    InkWell(
                      onTap: () {
                        Provider.of<SettingsProvider>(context, listen: false)
                            .setVoiceType('women');
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        decoration: BoxDecoration(
                          color: settings.voiceType == 'women'
                              ? const Color(0xFF5E5DE3).withOpacity(0.2)
                              : const Color(0xFF2D2D36).withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: settings.voiceType == 'women'
                                ? const Color(0xFF5E5DE3)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.record_voice_over,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppTranslations.translate('femaleVoice', settings.currentLanguage),
                                  style: TextStyle(
                                    color: settings.voiceType == 'women'
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 14,
                                    fontWeight: settings.voiceType == 'women'
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(
                                _playingVoice == '${settings.currentLanguage}_women' 
                                    ? Icons.stop 
                                    : Icons.play_arrow,
                                color: settings.voiceType == 'women'
                                    ? const Color(0xFF5E5DE3)
                                    : Colors.white70,
                                size: 20,
                              ),
                              onPressed: () => _playVoicePreview(settings.currentLanguage, 'women', settings.voiceVolume),
                              tooltip: _playingVoice == '${settings.currentLanguage}_women'
                                  ? AppTranslations.translate('stop', settings.currentLanguage)
                                  : AppTranslations.translate('play', settings.currentLanguage),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Voice Volume Slider
                    Text(
                      AppTranslations.translate('voiceVolume', settings.currentLanguage),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.volume_down,
                          color: Colors.white70,
                          size: 24,
                        ),
                        Expanded(
                          child: Slider(
                            value: settings.voiceVolume,
                            min: 0.0,
                            max: 1.0,
                            divisions: 10,
                            activeColor: Colors.deepPurple,
                            inactiveColor: Colors.deepPurple.withOpacity(0.3),
                            onChanged: (value) {
                              Provider.of<SettingsProvider>(context, listen: false)
                                  .setVoiceVolume(value);
                              // Also update the preview player volume if it's currently playing
                              if (_playingVoice != null) {
                                _previewPlayer.setVolume(value);
                              }
                            },
                          ),
                        ),
                        const Icon(
                          Icons.volume_up,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Language Section
                    Text(
                      AppTranslations.translate('language', settings.currentLanguage),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white70,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const LanguageSelector(),
                    const SizedBox(height: 32),

                    // Account Section with modern styling
                    Text(
                      AppTranslations.translate('account', settings.currentLanguage),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white70,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Email display in a styled container
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2D36).withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppTranslations.translate('email', settings.currentLanguage),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.email ?? AppTranslations.translate('noEmail', settings.currentLanguage),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Change Password Button (styled card)
                    InkWell(
                      onTap: () => _changePassword(context),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                        AppTranslations.translate('changePassword', settings.currentLanguage),
                        style: const TextStyle(
                          fontSize: 16,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Change Email Button (styled card)
                    InkWell(
                      onTap: () => _changeEmail(context),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.teal.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.email_outlined,
                              color: Colors.teal,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              AppTranslations.translate('changeEmail', settings.currentLanguage),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.teal,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sign Out Button (styled card)
                    InkWell(
                      onTap: () => _signOut(context),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.logout,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                        AppTranslations.translate('signOut', settings.currentLanguage),
                        style: const TextStyle(
                          fontSize: 16,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Footer links
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            // Use default privacy policy URL or show dialog if not available
                            _launchURL('https://lucidnow.app/privacy', context, settings);
                          },
                          child: Text(
                            AppTranslations.translate('privacyPolicy', settings.currentLanguage),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(' | ', style: TextStyle(color: Colors.white30, fontSize: 14)),
                        TextButton(
                          onPressed: () {
                            _launchURL('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/', context, settings);
                          },
                          child: Text(
                            AppTranslations.translate('termsOfUse', settings.currentLanguage),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(' | ', style: TextStyle(color: Colors.white30, fontSize: 14)),
                        TextButton(
                          onPressed: () {
                            _launchURL('https://lucidnow.app/support', context, settings);
                          },
                          child: Text(
                            AppTranslations.translate('support', settings.currentLanguage),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Delete Account Button (styled card)
                    InkWell(
                      onTap: () => _deleteAccount(context),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                        AppTranslations.translate('deleteAccount', settings.currentLanguage),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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