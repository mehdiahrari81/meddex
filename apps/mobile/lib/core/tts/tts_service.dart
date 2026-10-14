import 'package:flutter_tts/flutter_tts.dart';

abstract interface class TextToSpeechService {
  Future<void> speak(String text, {required String locale});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> setSpeed(double speed);
  Future<List<String>> voices({required String locale});
  Future<void> dispose();
}

class PlatformTextToSpeechService implements TextToSpeechService {
  PlatformTextToSpeechService(this._tts);

  final FlutterTts _tts;
  bool _disposed = false;
  String? _pausedText;
  String _locale = 'en';
  double _speed = 0.43;

  @override
  Future<void> speak(String text, {required String locale}) async {
    _ensureActive();
    _pausedText = text;
    _locale = locale;
    await _tts.stop();
    await _tts.setLanguage(locale == 'ur' ? 'ur-PK' : 'en-US');
    await _tts.setSpeechRate(_speed);
    await _tts.awaitSpeakCompletion(true);
    await _tts.speak(text);
  }

  @override
  Future<void> pause() async {
    if (!_disposed) await _tts.pause();
  }

  @override
  Future<void> resume() async {
    final text = _pausedText;
    if (text != null && !_disposed) await speak(text, locale: _locale);
  }

  @override
  Future<void> setSpeed(double speed) async {
    _ensureActive();
    _speed = speed.clamp(0.25, 0.75);
    await _tts.setSpeechRate(_speed);
  }

  @override
  Future<List<String>> voices({required String locale}) async {
    _ensureActive();
    final values = await _tts.getVoices;
    if (values is! List) return const [];
    final prefix = locale == 'ur' ? 'ur' : 'en';
    return values
        .whereType<Map>()
        .where(
          (value) => value['locale']?.toString().startsWith(prefix) ?? false,
        )
        .map((value) => value['name']?.toString() ?? value.toString())
        .toList(growable: false);
  }

  @override
  Future<void> stop() async {
    if (!_disposed) await _tts.stop();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _tts.stop();
  }

  void _ensureActive() {
    if (_disposed) throw StateError('Text-to-speech service is disposed.');
  }
}

class UnavailableTextToSpeechService implements TextToSpeechService {
  const UnavailableTextToSpeechService();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> speak(String text, {required String locale}) async {
    throw UnsupportedError('Text-to-speech is not configured.');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<List<String>> voices({required String locale}) async => const [];
}
