import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;

  /// Initialize the speech engine
  Future<bool> initialize() async {
    // 1. Ask for permission (mobile only)
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        return false; // User said no
      }
    }

    // 2. Warm up the engine (mobile only)
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      _isAvailable = await _speech.initialize(
        onStatus: (status) => debugPrint('Voice Status: $status'),
        onError: (error) => debugPrint('Voice Error: $error'),
      );
    } else {
      _isAvailable = false;
      debugPrint('Voice Service not supported on this platform');
    }

    return _isAvailable;
  }

  /// Start listening and stream words back as they are spoken
  void startListening({required Function(String) onResult}) {
    if (!_isAvailable) return;

    _speech.listen(
      onResult: (val) => onResult(val.recognizedWords),
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
      listenOptions: stt.SpeechListenOptions(
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  /// Stop listening manually
  void stop() {
    _speech.stop();
  }

  /// Is the mic currently active?
  bool get isListening => _speech.isListening;
}
