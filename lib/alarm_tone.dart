import 'dart:math' as math;
import 'dart:typed_data';

/// Represents a selectable alarm tone.
class AlarmToneOption {
  AlarmToneOption({
    required this.id,
    required this.label,
    required this.frequency,
    this.durationSeconds = 3.0,
  });

  final String id;
  final String label;
  final double frequency;
  final double durationSeconds;

  Uint8List? _cachedBytes;

  /// Lazily generated WAV bytes for the tone.
  Uint8List get bytes => _cachedBytes ??= _generateSineWave(
        frequency: frequency,
        seconds: durationSeconds,
      );
}

/// List of built-in tone options for the alarm.
final List<AlarmToneOption> alarmToneOptions = [
  AlarmToneOption(id: 'classic', label: 'Classic Chime', frequency: 660),
  AlarmToneOption(id: 'sunrise', label: 'Gentle Sunrise', frequency: 520),
  AlarmToneOption(id: 'pulse', label: 'Bright Pulse', frequency: 880),
];

Uint8List _generateSineWave({
  required double frequency,
  double seconds = 3.0,
  int sampleRate = 44100,
}) {
  final totalSamples = (sampleRate * seconds).round();
  final bytes = BytesBuilder();

  final bytesPerSample = 2;
  final dataSize = totalSamples * bytesPerSample;

  void writeString(String value) {
    bytes.add(value.codeUnits);
  }

  void writeUint32(int value) {
    bytes.add([
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ]);
  }

  void writeUint16(int value) {
    bytes.add([
      value & 0xFF,
      (value >> 8) & 0xFF,
    ]);
  }

  // WAV header
  writeString('RIFF');
  writeUint32(36 + dataSize);
  writeString('WAVE');
  writeString('fmt ');
  writeUint32(16); // PCM chunk size
  writeUint16(1); // Audio format (PCM)
  writeUint16(1); // Mono
  writeUint32(sampleRate);
  writeUint32(sampleRate * bytesPerSample);
  writeUint16(bytesPerSample);
  writeUint16(8 * bytesPerSample);
  writeString('data');
  writeUint32(dataSize);

  // PCM data with a smooth fade-in/out envelope to avoid clicks.
  for (var i = 0; i < totalSamples; i++) {
    final t = i / sampleRate;
    final rawSample = math.sin(2 * math.pi * frequency * t);
    final envelope = _applyEnvelope(i, totalSamples);
    final value = (rawSample * envelope * 32767).clamp(-32768, 32767).round();
    final sample = value & 0xFFFF;
    bytes.add([sample & 0xFF, (sample >> 8) & 0xFF]);
  }

  return bytes.toBytes();
}

double _applyEnvelope(int sample, int totalSamples) {
  if (totalSamples <= 0) {
    return 1.0;
  }
  final fadeSamples = (totalSamples * 0.02).clamp(1, totalSamples / 2).round();
  if (sample < fadeSamples) {
    return sample / fadeSamples;
  }
  if (sample > totalSamples - fadeSamples) {
    return (totalSamples - sample) / fadeSamples;
  }
  return 1.0;
}
