import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

abstract interface class VoiceInputService {
  Future<bool> initialize();
  Future<void> listen({
    required String locale,
    required void Function(String words, bool finalResult) onResult,
  });
  Future<void> stop();
  Future<void> cancel();
}

class PlatformVoiceInputService implements VoiceInputService {
  PlatformVoiceInputService(this._speech);
  final SpeechToText _speech;

  @override
  Future<bool> initialize() => _speech.initialize();

  @override
  Future<void> listen({
    required String locale,
    required void Function(String words, bool finalResult) onResult,
  }) => _speech.listen(
    listenOptions: SpeechListenOptions(
      localeId: locale == 'ur' ? 'ur_PK' : 'en_US',
    ),
    onResult: (SpeechRecognitionResult result) =>
        onResult(result.recognizedWords, result.finalResult),
  );

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}

class UnavailableVoiceInputService implements VoiceInputService {
  const UnavailableVoiceInputService();
  @override
  Future<bool> initialize() async => false;
  @override
  Future<void> listen({
    required String locale,
    required void Function(String words, bool finalResult) onResult,
  }) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
}
