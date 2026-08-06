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

/// Plays once the desktop acks a whip (the command actually landed) - a cow
/// moo, because a whip made a cow move.
const _successClips = [
  'sounds/universfield-cow-moo-122255.mp3',
  'sounds/scottishperson-sound-effect-cow-mooing-356517.mp3',
  'sounds/ribhavagrawal-cow-mooing-type-03-293302.mp3',
];

class SoundPlayer {
  // Separate players so an ack arriving mid-crack doesn't cut the whip
  // sound off to play the success sound instead - both should be audible.
  final _whipPlayer = AudioPlayer();
  final _successPlayer = AudioPlayer();
  final _random = Random();

  Future<void> playWhip() async {
    await _whipPlayer.stop();
    await _whipPlayer.play(AssetSource(_randomOf(_whipClips)));
  }

  Future<void> playSuccess() async {
    await _successPlayer.stop();
    await _successPlayer.play(AssetSource(_randomOf(_successClips)));
  }

  String _randomOf(List<String> clips) => clips[_random.nextInt(clips.length)];

  void dispose() {
    _whipPlayer.dispose();
    _successPlayer.dispose();
  }
}
