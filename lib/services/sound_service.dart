import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sound effects for the whole app, synthesised in code as tiny WAV
/// buffers: there are no audio files to ship or manage.
///
/// The character is soft throughout (short sine notes, quick decays,
/// low gains) and turns playful only where the moment earns it: the
/// word reveal sweeps up, and twinning plays a little rising chime.
/// Everything is gated by one on/off flag, saved on the device and
/// switched from the Settings sheet.
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  static const _enabledKey = 'sound_enabled';
  static const _sampleRate = 22050;

  final AudioPlayer _player = AudioPlayer();
  final Map<String, Uint8List> _cache = {};

  bool _enabled = true;
  bool get enabled => _enabled;

  /// Reads the saved on/off flag. Called once from AppSession.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? true;
      await _player.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {
      // Sound is decoration. If the platform refuses, stay silent
      // rather than taking the app down with it.
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (_) {}
    // A short preview so the player hears what just turned on.
    if (value) lockIn();
  }

  // -- Events ---------------------------------------------------------

  /// The faintest tick, for tab switches.
  void tick() => _play('tick', const [
        _Tone(1560, start: 0, seconds: 0.03, gain: 0.05),
      ]);

  /// Your word is in: a soft two-note pop.
  void lockIn() => _play('lockIn', const [
        _Tone(523.25, start: 0, seconds: 0.10, gain: 0.20),
        _Tone(783.99, start: 0.06, seconds: 0.14, gain: 0.20),
      ]);

  /// Your partner locked in and is waiting on you: one quiet ding.
  void partnerDing() => _play('partnerDing', const [
        _Tone(880, start: 0, seconds: 0.22, gain: 0.16),
      ]);

  /// A nudge arrived: the ding, twice, still soft.
  void nudge() => _play('nudge', const [
        _Tone(987.77, start: 0, seconds: 0.10, gain: 0.16),
        _Tone(987.77, start: 0.14, seconds: 0.18, gain: 0.16),
      ]);

  /// The round's words are revealed: a short rising sweep.
  void reveal() => _play('reveal', const [
        _Tone(420, start: 0, seconds: 0.24, gain: 0.15, slideTo: 840),
      ]);

  /// You twinned: the one playful sound, a rising four-note chime.
  void twin() => _play('twin', const [
        _Tone(523.25, start: 0, seconds: 0.12, gain: 0.22),
        _Tone(659.25, start: 0.09, seconds: 0.12, gain: 0.22),
        _Tone(783.99, start: 0.18, seconds: 0.12, gain: 0.22),
        _Tone(1046.50, start: 0.27, seconds: 0.40, gain: 0.24),
      ]);

  /// The game ended without a match: two low notes, gently falling.
  void gameEnd() => _play('gameEnd', const [
        _Tone(392, start: 0, seconds: 0.16, gain: 0.15),
        _Tone(329.63, start: 0.15, seconds: 0.32, gain: 0.15),
      ]);

  /// A chat message leaves: a quick pop.
  void send() => _play('send', const [
        _Tone(659.25, start: 0, seconds: 0.07, gain: 0.16),
        _Tone(987.77, start: 0.04, seconds: 0.09, gain: 0.12),
      ]);

  /// A chat message arrives while you are in the thread: one blip.
  void receive() => _play('receive', const [
        _Tone(739.99, start: 0, seconds: 0.10, gain: 0.11),
      ]);

  /// Something was refused (bad code, failed join): a low, soft tone.
  void error() => _play('error', const [
        _Tone(185, start: 0, seconds: 0.18, gain: 0.13),
      ]);

  // -- Playback -------------------------------------------------------

  void _play(String name, List<_Tone> tones) {
    if (!_enabled) return;
    final bytes = _cache.putIfAbsent(name, () => _renderWav(tones));
    unawaited(_playBytes(bytes));
  }

  Future<void> _playBytes(Uint8List bytes) async {
    try {
      await _player.stop();
      await _player.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('sound failed: $e');
    }
  }

  // -- Synthesis ------------------------------------------------------

  /// Renders the tones into one 16-bit mono WAV. Each note is a sine
  /// with a 4ms attack and an exponential decay, so nothing clicks or
  /// rings harshly; a note may glide to a second frequency (the sweep).
  Uint8List _renderWav(List<_Tone> tones) {
    var totalSeconds = 0.0;
    for (final tone in tones) {
      totalSeconds = math.max(totalSeconds, tone.start + tone.seconds);
    }
    final frameCount = (totalSeconds * _sampleRate).ceil();
    final pcm = Int16List(frameCount);

    for (final tone in tones) {
      final startFrame = (tone.start * _sampleRate).round();
      final frames = (tone.seconds * _sampleRate).round();
      final attackFrames = math.max(1, (0.004 * _sampleRate).round());
      for (var i = 0; i < frames; i++) {
        final t = i / _sampleRate;
        final freq = tone.slideTo == null
            ? tone.freq
            : tone.freq *
                math.pow(tone.slideTo! / tone.freq, t / tone.seconds);
        final envelope = i < attackFrames
            ? i / attackFrames
            : math.exp(-2.8 * (t / tone.seconds));
        final sample = math.sin(2 * math.pi * freq * t) * envelope * tone.gain;
        final index = startFrame + i;
        final mixed = pcm[index] / 32767.0 + sample;
        pcm[index] = (mixed.clamp(-1.0, 1.0) * 32767).round();
      }
    }

    final dataSize = frameCount * 2;
    final out = ByteData(44 + dataSize);
    void writeAscii(int offset, String text) {
      for (var i = 0; i < text.length; i++) {
        out.setUint8(offset + i, text.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    out.setUint32(4, 36 + dataSize, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    out.setUint32(16, 16, Endian.little);
    out.setUint16(20, 1, Endian.little); // PCM
    out.setUint16(22, 1, Endian.little); // mono
    out.setUint32(24, _sampleRate, Endian.little);
    out.setUint32(28, _sampleRate * 2, Endian.little);
    out.setUint16(32, 2, Endian.little);
    out.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    out.setUint32(40, dataSize, Endian.little);
    for (var i = 0; i < frameCount; i++) {
      out.setInt16(44 + i * 2, pcm[i], Endian.little);
    }
    return out.buffer.asUint8List();
  }
}

/// One note in a sound: a sine at [freq] Hz (gliding to [slideTo] if
/// given), starting [start] seconds in, lasting [seconds], at [gain]
/// (0 to 1, kept low: these sounds sit under the app, not over it).
class _Tone {
  const _Tone(
    this.freq, {
    required this.start,
    required this.seconds,
    required this.gain,
    this.slideTo,
  });

  final double freq;
  final double start;
  final double seconds;
  final double gain;
  final double? slideTo;
}
