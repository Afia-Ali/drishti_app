// ignore_for_file: avoid_print

import 'package:audioplayers/audioplayers.dart';

class BanglaTTS {
  final AudioPlayer _player = AudioPlayer();
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    try {
      _isSpeaking = true;

      await _player.stop();

      final chunks = _chunkText(text, 180);

      for (final chunk in chunks) {
        if (!_isSpeaking) break;
        await _playChunk(chunk);
      }
    } catch (e) {
      print('Bangla TTS error: $e');
    } finally {
      _isSpeaking = false;
    }
  }

  Future<void> _playChunk(String text) async {
    final encoded = Uri.encodeComponent(text);
    final url = 'https://translate.google.com/translate_tts'
        '?ie=UTF-8'
        '&q=$encoded'
        '&tl=bn'
        '&client=tw-ob';

    try {
      await _player.play(UrlSource(url));
      await _player.onPlayerComplete.first;
    } catch (e) {
      print('Bangla chunk play error: $e');
    }
  }

  List<String> _chunkText(String text, int maxLen) {
    if (text.length <= maxLen) return [text];

    final chunks = <String>[];
    final words = text.split(' ');
    var current = '';

    for (final word in words) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (candidate.length > maxLen) {
        if (current.isNotEmpty) chunks.add(current);
        current = word;
      } else {
        current = candidate;
      }
    }

    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }

  Future<void> stop() async {
    _isSpeaking = false;
    await _player.stop();
  }

  void dispose() {
    _isSpeaking = false;
    _player.dispose();
  }
}
