// lib/providers/settings_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  static final SettingsProvider _instance = SettingsProvider._internal();
  factory SettingsProvider() => _instance;

  // Settings state
  bool _backgroundAudioEnabled = true;
  bool _keepScreenOn = true;
  int _sleepPhaseDelayMinutes = 20;
  bool _useFlashForLight = true;
  List<String> _activeSenses = ['Vision', 'Hearing', 'Body'];
  String _currentLanguage = 'en';
  String _soundTrigger = 'melody1.mp3'; // default sound trigger

  // Getters
  bool get backgroundAudioEnabled => _backgroundAudioEnabled;
  bool get keepScreenOn => _keepScreenOn;
  int get sleepPhaseDelayMinutes => _sleepPhaseDelayMinutes;
  bool get useFlashForLight => _useFlashForLight;
  List<String> get activeSenses => List.from(_activeSenses);
  String get currentLanguage => _currentLanguage;
  String get soundTrigger => _soundTrigger; // NEW getter for sound trigger

  SettingsProvider._internal() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _backgroundAudioEnabled = prefs.getBool('backgroundAudioEnabled') ?? true;
    _keepScreenOn = prefs.getBool('keepScreenOn') ?? true;
    _sleepPhaseDelayMinutes = prefs.getInt('sleepPhaseDelayMinutes') ?? 20;
    _useFlashForLight = prefs.getBool('useFlashForLight') ?? true;
    _activeSenses = prefs.getStringList('activeSenses') ?? ['Vision', 'Hearing', 'Body'];
    _currentLanguage = prefs.getString('language') ?? 'en';
    _soundTrigger = prefs.getString('soundTrigger') ?? 'melody1.mp3';

    notifyListeners();
  }

  // Settings setters
  Future<void> setBackgroundAudioEnabled(bool value) async {
    _backgroundAudioEnabled = value;
    await _saveToPrefs('backgroundAudioEnabled', value);
    notifyListeners();
  }

  Future<void> setKeepScreenOn(bool value) async {
    _keepScreenOn = value;
    await _saveToPrefs('keepScreenOn', value);
    notifyListeners();
  }

  Future<void> setSleepPhaseDelayMinutes(int value) async {
    _sleepPhaseDelayMinutes = value;
    await _saveToPrefs('sleepPhaseDelayMinutes', value);
    notifyListeners();
  }

  Future<void> setUseFlashForLight(bool value) async {
    _useFlashForLight = value;
    await _saveToPrefs('useFlashForLight', value);
    notifyListeners();
  }

  Future<void> setActiveSenses(List<String> value) async {
    _activeSenses = List.from(value);
    await _saveToPrefs('activeSenses', value);
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    _currentLanguage = languageCode;
    await _saveToPrefs('language', languageCode);
    notifyListeners();
  }

  Future<void> setSoundTrigger(String value) async {
    _soundTrigger = value;
    await _saveToPrefs('soundTrigger', value);
    notifyListeners();
  }

  // Helper method to save to SharedPreferences
  Future<void> _saveToPrefs(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();

    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    }
  }
}
