import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'voice_service.dart';

final voiceInputProvider = Provider<VoiceInputService>(
  (ref) => PlatformVoiceInputService(SpeechToText()),
);
