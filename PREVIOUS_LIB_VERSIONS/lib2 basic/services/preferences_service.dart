import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _hasSeenIntroKey = 'has_seen_intro';

  // Check if the user has seen the intro screens
  static Future<bool> hasSeenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenIntroKey) ?? false;
  }

  // Set that the user has seen the intro screens
  static Future<void> setIntroSeen([bool seen = true]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenIntroKey, seen);
  }
} 