import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  static SettingsService get instance => _instance;
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _prefThemeKey = 'sd_chat_pref_theme';
  static const String _prefLanguageKey = 'sd_chat_pref_language';
  static const String _prefFontScaleKey = 'sd_chat_pref_font_scale';
  static const String _prefAccentColorKey = 'sd_chat_pref_accent_color';

  // 6 Couleurs d'accent officielles demandées
  static const List<Map<String, dynamic>> accentColors = [
    {'name': 'Bleu', 'key': 'blue', 'color': Color(0xFF3B82F6)},
    {'name': 'Vert', 'key': 'green', 'color': Color(0xFF10B981)},
    {'name': 'Rouge', 'key': 'red', 'color': Color(0xFFEF4444)},
    {'name': 'Orange', 'key': 'orange', 'color': Color(0xFFF97316)},
    {'name': 'Jaune', 'key': 'yellow', 'color': Color(0xFFE5A93C)}, // Aura Amber Officiel
    {'name': 'Violet', 'key': 'purple', 'color': Color(0xFF8B5CF6)},
  ];

  ThemeMode _themeMode = ThemeMode.dark; // Aura Obsidian par défaut
  String _languageCode = 'fr'; // Français par défaut
  double _fontScale = 1.0; // Normal par défaut
  Color _accentColor = const Color(0xFFE5A93C); // Jaune Aura Amber par défaut
  String _accentColorKey = 'yellow';
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  String get languageCode => _languageCode;
  double get fontScale => _fontScale;
  Color get accentColor => _accentColor;
  String get accentColorKey => _accentColorKey;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Thème
      final savedTheme = prefs.getString(_prefThemeKey);
      if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else if (savedTheme == 'system') {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.dark;
      }

      // 2. Langue
      final savedLang = prefs.getString(_prefLanguageKey);
      if (savedLang != null && (savedLang == 'fr' || savedLang == 'en')) {
        _languageCode = savedLang;
      }

      // 3. Taille de police
      final savedFont = prefs.getDouble(_prefFontScaleKey);
      if (savedFont != null && savedFont >= 0.8 && savedFont <= 1.5) {
        _fontScale = savedFont;
      }

      // 4. Couleur d'accent
      final savedColor = prefs.getString(_prefAccentColorKey);
      if (savedColor != null) {
        final match = accentColors.firstWhere(
          (c) => c['key'] == savedColor,
          orElse: () => accentColors[4], // Jaune par défaut
        );
        _accentColor = match['color'] as Color;
        _accentColorKey = match['key'] as String;
      }
    } catch (e) {
      debugPrint('SettingsService init notice: $e');
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      String val = 'dark';
      if (mode == ThemeMode.light) val = 'light';
      if (mode == ThemeMode.system) val = 'system';
      await prefs.setString(_prefThemeKey, val);
      _syncPreferencesToCloud();
    } catch (e) {
      debugPrint('Erreur sauvegarde thème: $e');
    }
  }

  Future<void> setLanguage(String code) async {
    if (_languageCode == code) return;
    _languageCode = code;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLanguageKey, code);
      _syncPreferencesToCloud();
    } catch (e) {
      debugPrint('Erreur sauvegarde langue: $e');
    }
  }

  Future<void> setFontScale(double scale) async {
    _fontScale = scale.clamp(0.85, 1.35);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefFontScaleKey, _fontScale);
      _syncPreferencesToCloud();
    } catch (e) {
      debugPrint('Erreur sauvegarde taille police: $e');
    }
  }

  Future<void> setAccentColor(String key) async {
    final match = accentColors.firstWhere(
      (c) => c['key'] == key,
      orElse: () => accentColors[4],
    );
    _accentColor = match['color'] as Color;
    _accentColorKey = match['key'] as String;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefAccentColorKey, _accentColorKey);
      _syncPreferencesToCloud();
    } catch (e) {
      debugPrint('Erreur sauvegarde couleur accent: $e');
    }
  }

  /// Synchronise les préférences de manière transparente vers le profil cloud Supabase
  Future<void> _syncPreferencesToCloud() async {
    final token = AuthService().accessToken;
    if (token == null || token.isEmpty) return;

    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/v1/profile');
      await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'preferences': {
            'theme': _themeMode == ThemeMode.light ? 'light' : (_themeMode == ThemeMode.system ? 'system' : 'dark'),
            'language': _languageCode,
            'font_scale': _fontScale,
            'accent_color': _accentColorKey,
          }
        }),
      );
    } catch (e) {
      // Ignorer silencieusement si hors-ligne
    }
  }
}
