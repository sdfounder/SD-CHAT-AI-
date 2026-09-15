import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceStatus {
  idle,
  listening,
  error,
  permissionDenied,
  unavailable,
}

class VoiceService extends ChangeNotifier {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();

  VoiceStatus _status = VoiceStatus.idle;
  VoiceStatus get status => _status;
  bool get isListening => _status == VoiceStatus.listening;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  double _soundLevel = 0.0;
  double get soundLevel => _soundLevel;

  bool _isInitialized = false;

  /// Initialiser le moteur de reconnaissance vocale natif Android
  Future<bool> initSpeech() async {
    if (_isInitialized) return true;

    try {
      final available = await _speech.initialize(
        onError: (errorNotification) {
          debugPrint('SpeechRecognizer error: ${errorNotification.errorMsg} (permanent: ${errorNotification.permanent})');
          final msg = errorNotification.errorMsg.toLowerCase();

          if (msg.contains('permission')) {
            _status = VoiceStatus.permissionDenied;
            _errorMessage = 'Permission microphone refusée. Activez-la dans les paramètres Android.';
          } else if (msg.contains('no_match') || msg.contains('speech_timeout')) {
            // Fin normale de parole ou aucun mot détecté
            _status = VoiceStatus.idle;
          } else if (msg.contains('busy')) {
            _status = VoiceStatus.error;
            _errorMessage = 'Microphone déjà utilisé par une autre application.';
          } else {
            _status = VoiceStatus.error;
            _errorMessage = 'Erreur reconnaissance vocale (${errorNotification.errorMsg}).';
          }
          notifyListeners();
        },
        onStatus: (statusStr) {
          debugPrint('SpeechRecognizer status: $statusStr');
          if (statusStr == 'listening') {
            _status = VoiceStatus.listening;
          } else if (statusStr == 'notListening' || statusStr == 'done') {
            if (_status == VoiceStatus.listening) {
              _status = VoiceStatus.idle;
            }
          }
          notifyListeners();
        },
      );

      _isInitialized = available;
      if (!available) {
        _status = VoiceStatus.unavailable;
        _errorMessage = 'Reconnaissance vocale native indisponible sur cet appareil.';
        notifyListeners();
      }
      return available;
    } catch (e) {
      debugPrint('Exception in initSpeech: $e');
      _status = VoiceStatus.unavailable;
      _errorMessage = 'Impossible d\'initialiser le service vocal Android: $e';
      notifyListeners();
      return false;
    }
  }

  /// Démarrer l'écoute vocale en continu (dictée)
  Future<void> startListening({
    required void Function(String recognizedWords, bool isFinal) onResult,
    String? localeId,
  }) async {
    final available = await initSpeech();
    if (!available) {
      return;
    }

    _errorMessage = '';
    _status = VoiceStatus.listening;
    notifyListeners();

    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: (level) {
          _soundLevel = level;
          notifyListeners();
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          localeId: localeId,
        ),
      );
    } catch (e) {
      debugPrint('Error starting speech listening: $e');
      _status = VoiceStatus.error;
      _errorMessage = 'Erreur au démarrage de l\'écoute: $e';
      notifyListeners();
    }
  }

  /// Arrêter l'écoute et finaliser le texte
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    _status = VoiceStatus.idle;
    notifyListeners();
  }

  /// Annuler l'écoute sans conserver le résultat intermédiaire
  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
    _status = VoiceStatus.idle;
    notifyListeners();
  }
}
