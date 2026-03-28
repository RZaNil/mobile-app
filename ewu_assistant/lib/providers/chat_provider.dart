import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import '../models/student_profile.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/speech_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({ApiService? apiService, SpeechService? speechService})
    : _apiService = apiService ?? ApiService(),
      _speechService = speechService ?? SpeechService();

  static const String _autoSpeakKey = 'auto_speak_enabled';

  final ApiService _apiService;
  final SpeechService _speechService;
  final List<ChatMessage> _messages = <ChatMessage>[];

  bool _initialized = false;
  bool _loading = false;
  bool _listening = false;
  bool _speaking = false;
  bool _autoSpeak = true;
  bool _serverOnline = false;
  bool _disposed = false;
  bool _voicePermissionBlocked = false;
  int _requestVersion = 0;
  String _partialText = '';
  String _lastFinalSpeech = '';
  String? _voiceErrorMessage;
  StudentProfile? _studentProfile;

  List<ChatMessage> get messages => List<ChatMessage>.unmodifiable(_messages);
  bool get loading => _loading;
  bool get listening => _listening;
  bool get speaking => _speaking;
  bool get autoSpeak => _autoSpeak;
  bool get serverOnline => _serverOnline;
  bool get voicePermissionBlocked => _voicePermissionBlocked;
  String get partialText => _partialText;
  String? get voiceErrorMessage => _voiceErrorMessage;
  StudentProfile? get studentProfile => _studentProfile;

  Future<void> initialize() async {
    if (_initialized || _disposed) {
      return;
    }
    _initialized = true;

    final List<Object?> bootstrapResults =
        await Future.wait<Object?>(<Future<Object?>>[
          SharedPreferences.getInstance(),
          _speechService.initialize(),
          AuthService.getProfile(),
        ]);
    if (_disposed) {
      return;
    }

    final SharedPreferences prefs = bootstrapResults[0] as SharedPreferences;
    _autoSpeak = prefs.getBool(_autoSpeakKey) ?? true;
    _studentProfile = bootstrapResults[2] as StudentProfile?;
    _notifySafely();
    unawaited(_refreshServerStatus());
  }

  Future<void> refreshProfile() async {
    if (_disposed) {
      return;
    }
    _studentProfile = await AuthService.getProfile();
    _notifySafely();
  }

  Future<void> _refreshServerStatus() async {
    final bool online = await _apiService.checkHealth();
    if (_disposed || online == _serverOnline) {
      return;
    }
    _serverOnline = online;
    _notifySafely();
  }

  Future<void> setAutoSpeak(bool value) async {
    if (_disposed) {
      return;
    }
    _autoSpeak = value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_disposed) {
      return;
    }
    await prefs.setBool(_autoSpeakKey, value);
    _notifySafely();
  }

  Future<bool> startListening() async {
    if (_disposed || _listening || _loading) {
      return false;
    }

    await _speechService.stopSpeaking();
    _speaking = false;
    _partialText = '';
    _lastFinalSpeech = '';
    _voiceErrorMessage = null;
    _voicePermissionBlocked = false;
    _listening = true;
    _notifySafely();

    final bool started = await _speechService.startListening(
      (String text, bool isFinal) {
        if (_disposed) {
          return;
        }
        _partialText = text;
        _notifySafely();

        if (!isFinal) {
          return;
        }

        final String finalText = text.trim();
        if (finalText.isEmpty || finalText == _lastFinalSpeech) {
          return;
        }

        _voiceErrorMessage = null;
        _lastFinalSpeech = finalText;
        _listening = false;
        _partialText = '';
        _notifySafely();
        sendMessage(finalText);
      },
      () {
        if (_disposed) {
          return;
        }
        _listening = false;
        _notifySafely();
      },
    );
    if (!_disposed && !started) {
      _listening = false;
      _voiceErrorMessage = _speechService.lastErrorMessage;
      _voicePermissionBlocked = _speechService.permissionPermanentlyDenied;
      _notifySafely();
    }
    return started;
  }

  Future<void> stopListening() async {
    if (_disposed) {
      return;
    }
    await _speechService.stopListening();
    _listening = false;
    _partialText = '';
    _notifySafely();
  }

  Future<void> sendMessage(String text) async {
    if (_disposed || _loading) {
      return;
    }
    final String trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }

    if (_listening) {
      await stopListening();
    }

    await _speechService.stopSpeaking();
    _speaking = false;

    _messages.add(ChatMessage(text: trimmedText, isUser: true));
    _loading = true;
    _notifySafely();

    final int requestVersion = ++_requestVersion;
    final ApiResponse response = await _apiService.askQuestion(trimmedText);
    if (_disposed || requestVersion != _requestVersion) {
      return;
    }

    _messages.add(
      ChatMessage(
        text: response.answer,
        isUser: false,
        intent: response.intent,
        source: response.source,
        suggestions: response.suggestions,
        responseTimeMs: response.responseTimeMs,
      ),
    );

    _serverOnline = response.source != 'offline_fallback';
    _loading = false;
    _notifySafely();

    if (_autoSpeak && response.answer.isNotEmpty) {
      _speaking = true;
      _notifySafely();
      try {
        await _speechService.speak(response.answer);
      } finally {
        if (!_disposed && requestVersion == _requestVersion) {
          _speaking = false;
          _notifySafely();
        }
      }
    }
  }

  Future<void> stopSpeaking() async {
    if (_disposed) {
      return;
    }
    await _speechService.stopSpeaking();
    _speaking = false;
    _notifySafely();
  }

  void clearMessages() {
    if (_disposed) {
      return;
    }
    _requestVersion++;
    _messages.clear();
    _partialText = '';
    _lastFinalSpeech = '';
    _voiceErrorMessage = null;
    _voicePermissionBlocked = false;
    _loading = false;
    _listening = false;
    _speaking = false;
    unawaited(_speechService.stopListening());
    unawaited(_speechService.stopSpeaking());
    _apiService.resetSession();
    _notifySafely();
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _apiService.dispose();
    _speechService.dispose();
    super.dispose();
  }
}
