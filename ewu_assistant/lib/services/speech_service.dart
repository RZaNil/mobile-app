import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef SpeechResultCallback = void Function(String text, bool isFinal);

class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _speechInitialized = false;
  bool _ttsInitialized = false;
  bool _isListening = false;
  bool _disposed = false;
  bool _permissionPermanentlyDenied = false;
  String? _lastErrorMessage;
  VoidCallback? _onListeningDone;

  bool get isListening => _isListening;
  bool get permissionPermanentlyDenied => _permissionPermanentlyDenied;
  String? get lastErrorMessage => _lastErrorMessage;

  Future<bool> initialize() async {
    return _initializeTts();
  }

  Future<bool> _initializeTts() async {
    if (_disposed) {
      return false;
    }
    if (_ttsInitialized) {
      return true;
    }

    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.awaitSpeakCompletion(true);
      _ttsInitialized = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _prepareSpeechRecognition() async {
    if (_disposed) {
      _setVoiceError(
        'Voice recognition is unavailable because the service is closed.',
      );
      return false;
    }

    final PermissionStatus currentStatus = await Permission.microphone.status;
    if (currentStatus.isPermanentlyDenied || currentStatus.isRestricted) {
      _setVoiceError(
        currentStatus.isPermanentlyDenied
            ? 'Microphone permission is turned off for EWU Assistant. Enable it from Android app settings to use voice mode.'
            : 'Microphone access is restricted on this device right now.',
        permissionPermanentlyDenied: currentStatus.isPermanentlyDenied,
      );
      return false;
    }

    final PermissionStatus status = currentStatus.isGranted
        ? currentStatus
        : await Permission.microphone.request();
    if (!status.isGranted) {
      _setVoiceError(
        status.isPermanentlyDenied
            ? 'Microphone permission is turned off for EWU Assistant. Enable it from Android app settings to use voice mode.'
            : 'Microphone permission was denied, so voice mode cannot start yet.',
        permissionPermanentlyDenied: status.isPermanentlyDenied,
      );
      return false;
    }

    _clearVoiceError();

    if (_speechInitialized) {
      return true;
    }

    try {
      final bool available = await _speechToText.initialize(
        onStatus: (String statusText) {
          final String lower = statusText.toLowerCase();
          if (lower == 'done' || lower == 'notlistening') {
            _finishListening();
          }
        },
        onError: (SpeechRecognitionError _) {
          _finishListening();
        },
      );
      _speechInitialized = available;
      if (!available) {
        _setVoiceError(
          'Speech recognition is not available on this phone right now.',
        );
      }
      return available;
    } catch (_) {
      _setVoiceError(
        'Speech recognition could not start right now. Please try again in a moment.',
      );
      return false;
    }
  }

  Future<bool> startListening(
    SpeechResultCallback onResult,
    VoidCallback onListeningDone,
  ) async {
    final bool ready = await _prepareSpeechRecognition();
    if (!ready) {
      _finishListening(onListeningDone);
      return false;
    }

    _onListeningDone = onListeningDone;
    _isListening = true;

    try {
      await _speechToText.listen(
        localeId: 'en_US',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
        onResult: (SpeechRecognitionResult result) {
          onResult(result.recognizedWords, result.finalResult);
        },
      );
      _clearVoiceError();
      return true;
    } catch (_) {
      _setVoiceError(
        'Voice listening could not start. Please check your microphone access and try again.',
      );
      _finishListening();
      return false;
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    _onListeningDone = null;
    if (_disposed) {
      return;
    }

    try {
      await _speechToText.stop();
    } catch (_) {
      // Ignore stop failures so the UI can recover gracefully.
    }
  }

  Future<void> speak(String text) async {
    if (_disposed || text.trim().isEmpty) {
      return;
    }

    final bool ready = await _initializeTts();
    if (!ready) {
      return;
    }

    try {
      await _flutterTts.stop();
      await _flutterTts.speak(_expandForSpeech(text));
    } catch (_) {
      // TTS is optional. Fail silently so the rest of the app keeps working.
    }
  }

  Future<void> stopSpeaking() async {
    if (_disposed) {
      return;
    }

    try {
      await _flutterTts.stop();
    } catch (_) {
      // Ignore stop failures so the rest of the flow can continue.
    }
  }

  void dispose() {
    _disposed = true;
    _isListening = false;
    _onListeningDone = null;

    try {
      _speechToText.cancel();
    } catch (_) {
      // Ignore plugin cleanup issues during disposal.
    }

    try {
      _flutterTts.stop();
    } catch (_) {
      // Ignore plugin cleanup issues during disposal.
    }
  }

  String _expandForSpeech(String input) {
    String text = input;

    const Map<String, String> replacements = <String, String>{
      'EWU': 'E W U',
      'CSE': 'C S E',
      'ECE': 'E C E',
      'EEE': 'E E E',
      'BBA': 'B B A',
      'MBA': 'M B A',
      'BDT': 'Taka',
      'TK': 'Taka',
    };

    replacements.forEach((String key, String value) {
      text = text.replaceAllMapped(
        RegExp('\\b$key\\b', caseSensitive: false),
        (_) => value,
      );
    });

    return text;
  }

  void _clearVoiceError() {
    _lastErrorMessage = null;
    _permissionPermanentlyDenied = false;
  }

  void _setVoiceError(
    String message, {
    bool permissionPermanentlyDenied = false,
  }) {
    _lastErrorMessage = message;
    _permissionPermanentlyDenied = permissionPermanentlyDenied;
  }

  void _finishListening([VoidCallback? fallback]) {
    _isListening = false;
    final VoidCallback? callback = _onListeningDone ?? fallback;
    _onListeningDone = null;
    callback?.call();
  }
}
