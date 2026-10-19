import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _popPlayer = AudioPlayer();
  final AudioPlayer _chimePlayer = AudioPlayer();
  bool isMuted = false;

  Future<void> init() async {
    await _popPlayer.setAudioContext(AudioContext(
      android: const AudioContextAndroid(isSpeakerphoneOn: true),
      iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    ));
  }

  void playPopSound() {
    if (isMuted) return;
    _popPlayer.play(AssetSource('sounds/pop.mp3'));
  }

  void playGoldenChime() {
    if (isMuted) return;
    _chimePlayer.play(AssetSource('sounds/chime.mp3'));
  }

  void playRainbowChime() {
    if (isMuted) return;
    _chimePlayer.play(AssetSource('sounds/rainbow.mp3'));
  }

  void playHeartDing() {
    if (isMuted) return;
    _chimePlayer.play(AssetSource('sounds/heart.mp3'));
  }

  void playRewardFanfare() {
    if (isMuted) return;
    _chimePlayer.play(AssetSource('sounds/fanfare.mp3'));
  }
}
