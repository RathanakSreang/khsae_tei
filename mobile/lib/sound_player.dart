import 'package:audioplayers/audioplayers.dart';

class SoundPlayer {
  final _player = AudioPlayer();

  Future<void> playWhip() async {
    await _player.stop();
    await _player.play(AssetSource('sounds/whip.wav'));
  }

  void dispose() {
    _player.dispose();
  }
}
