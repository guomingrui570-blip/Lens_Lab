import 'package:audioplayers/audioplayers.dart';

class AudioUtil {
  static final AudioPlayer _player = AudioPlayer();

  /// 通用短音效播放
  static Future<void> play(String fileName, {double volume = 0.6}) async {
    await _player.stop();
    await _player.setVolume(volume);
    await _player.play(AssetSource('sounds/$fileName'));
  }

  /// 全局点击音效
  static Future<void> playClick() => play("click.mp3");

  /// 答题正确
  static Future<void> playCorrect() => play("correct.mp3", volume: 0.7);

  /// 答题错误
  static Future<void> playIncorrect() => play("incorrect.mp3", volume: 0.7);

  /// 发送AI消息
  static Future<void> playMessage() => play("message.mp3");

  static void dispose() {
    _player.dispose();
  }
}
