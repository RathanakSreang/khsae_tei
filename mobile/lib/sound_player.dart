import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

/// A pool of real whip-crack recordings; a random one plays per gesture so
/// repeated whips don't sound identical.
const _whipClips = [
  'sounds/universfield-whip-crack-02-244949.mp3',
  'sounds/universfield-whip-crack-123738.mp3',
  'sounds/universfield-whip-crack-252032.mp3',
  'sounds/universfield-whip-snap-242215.mp3',
  'sounds/freesound_community-mixed-whip-crack-1-102825.mp3',
];

class SoundPlayer {
  final _player = AudioPlayer();
  final _random = Random();

  Future<void> playWhip() async {
    await _player.stop();
    final clip = _whipClips[_random.nextInt(_whipClips.length)];
    await _player.play(AssetSource(clip));
  }

  void dispose() {
    _player.dispose();
  }
}
