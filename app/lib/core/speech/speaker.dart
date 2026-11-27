import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Lecture à voix haute, pour qui lit difficilement.
abstract interface class Speaker {
  /// Lit [text] et se termine à la fin de la lecture. Faux si le téléphone
  /// ne sait pas lire le français à voix haute.
  Future<bool> speak(String text);

  /// Interrompt la lecture en cours.
  Future<void> stop();
}

/// Synthèse vocale du téléphone (Android), en français, sans connexion
/// quand la voix est installée. Rien n'est envoyé par SafeLink.
final class DeviceSpeaker implements Speaker {
  FlutterTts? _tts;
  bool _ready = false;

  /// Débit un peu plus lent que la normale (0,5), pour être bien compris.
  static const rate = 0.42;

  Future<bool> _prepare() async {
    if (_ready) return true;
    final tts = _tts ??= FlutterTts();
    await tts.awaitSpeakCompletion(true);
    for (final language in const ['fr-FR', 'fr']) {
      if (await tts.isLanguageAvailable(language) == true &&
          _ok(await tts.setLanguage(language))) {
        await tts.setSpeechRate(rate);
        return _ready = true;
      }
    }
    return false;
  }

  static bool _ok(Object? result) => result == 1 || result == true;

  @override
  Future<bool> speak(String text) async {
    try {
      if (!await _prepare()) return false;
      return _ok(await _tts!.speak(text));
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts?.stop();
    } on PlatformException {
      // Rien à interrompre.
    } on MissingPluginException {
      // Rien à interrompre.
    }
  }
}

/// Lecteur à voix haute de l'application.
final speakerProvider = Provider<Speaker>((ref) {
  final speaker = DeviceSpeaker();
  ref.onDispose(speaker.stop);
  return speaker;
});

/// Termine [text] par un point s'il n'a pas déjà une ponctuation finale,
/// pour que la voix marque une pause entre les phrases.
String spokenSentence(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return trimmed;
  return RegExp(r'[.!?…:]$').hasMatch(trimmed) ? trimmed : '$trimmed.';
}
