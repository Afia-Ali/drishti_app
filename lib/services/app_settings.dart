// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  // Defaults
  double _voiceRate = 0.5;
  bool _isDarkTheme = true;
  String _language = 'en';
  bool _ttsEnabled = true;

  // Getters
  double get voiceRate => _voiceRate;
  bool get isDarkTheme => _isDarkTheme;
  String get language => _language;
  bool get ttsEnabled => _ttsEnabled;

  // Keys
  static const _keyRate = 'voice_rate';
  static const _keyTheme = 'is_dark_theme';
  static const _keyLang = 'language';
  static const _keyTts = 'tts_enabled';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _voiceRate = prefs.getDouble(_keyRate) ?? 0.5;
      _isDarkTheme = prefs.getBool(_keyTheme) ?? true;
      _language = prefs.getString(_keyLang) ?? 'en';
      _ttsEnabled = prefs.getBool(_keyTts) ?? true;
      notifyListeners();
    } catch (e) {
      print('Settings load error: $e');
    }
  }

  Future<void> setVoiceRate(double rate) async {
    _voiceRate = rate;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyRate, rate);
  }

  Future<void> setDarkTheme(bool dark) async {
    _isDarkTheme = dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTheme, dark);
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLang, lang);
  }

  Future<void> setTtsEnabled(bool enabled) async {
    _ttsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTts, enabled);
  }
}
