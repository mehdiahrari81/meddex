import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_service.dart';

final textToSpeechProvider = Provider<TextToSpeechService>((ref) {
  final service = PlatformTextToSpeechService(FlutterTts());
  ref.onDispose(service.dispose);
  return service;
});
