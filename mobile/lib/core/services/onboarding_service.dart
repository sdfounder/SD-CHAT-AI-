import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService extends ChangeNotifier {
  static final OnboardingService instance = OnboardingService._internal();
  factory OnboardingService() => instance;
  OnboardingService._internal();

  static const String _prefOnboardingCompletedKey = 'sd_chat_onboarding_completed_v1';

  bool _isInitialized = false;
  bool _isOnboardingCompleted = false;

  bool get isInitialized => _isInitialized;
  bool get isOnboardingCompleted => _isOnboardingCompleted;

  /// Initialise le service et charge l'état depuis le stockage local persistant
  Future<void> initialize({bool force = false}) async {
    if (_isInitialized && !force) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isOnboardingCompleted = prefs.getBool(_prefOnboardingCompletedKey) ?? false;
    } catch (e) {
      debugPrint('Erreur chargement état onboarding: $e');
      _isOnboardingCompleted = false;
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// Marque l'onboarding comme terminé de façon définitive sur cet appareil
  Future<void> completeOnboarding() async {
    _isOnboardingCompleted = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefOnboardingCompletedKey, true);
    } catch (e) {
      debugPrint('Erreur sauvegarde état onboarding: $e');
    }
  }

  /// Méthode de réinitialisation utilitaire (pour tests automatisés)
  @visibleForTesting
  Future<void> resetForTesting() async {
    _isOnboardingCompleted = false;
    _isInitialized = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefOnboardingCompletedKey);
    } catch (_) {}
  }
}
