import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:audio_decoder/audio_decoder.dart';
import 'package:fftea/fftea.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';
import '../core/visualizer_frame.dart';

class AudioProcessorException implements Exception {
  AudioProcessorException(this.message);
  final String message;

  @override
  String toString() => 'AudioProcessorException: $message';
}

class _IsolateMessage {
  final Float64List samples;
  final int sampleRate;
  final int fftSize;
  final int hopSize;
  final SendPort sendPort;

  _IsolateMessage({
    required this.samples,
    required this.sampleRate,
    required this.fftSize,
    required this.hopSize,
    required this.sendPort,
  });
}

class AudioProcessor {
  List<VisualizerFrame> _frames = [];
  int _sampleRate = 0;
  Duration _totalDuration = Duration.zero;

  List<VisualizerFrame> get frames => _frames;
  int get sampleRate => _sampleRate;
  Duration get totalDuration => _totalDuration;
  int get totalFrameCount => _frames.length;

  Future<void> load(String filePath) async {
    // Step 1: Decode audio to WAV on main isolate (uses platform channels)
    final tempDir = await getTemporaryDirectory();
    final wavPath =
        '${tempDir.path}/decoded_${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await AudioDecoder.convertToWav(filePath, wavPath);
    } catch (e) {
      throw AudioProcessorException('Failed to decode audio: $e');
    }

    // Step 2: Read WAV and parse PCM on main isolate
    final wavFile = File(wavPath);
    final wavBytes = await wavFile.readAsBytes();
    final pcmData = _parseWavFile(wavBytes);
    await wavFile.delete();

    _sampleRate = pcmData.sampleRate;
    _totalDuration = Duration(
      microseconds: (pcmData.samples.length / pcmData.sampleRate * 1000000)
          .toInt(),
    );

    // Step 3: Spawn isolate for CPU-heavy STFT
    final receivePort = ReceivePort();
    final completer = Completer<List<Map<String, dynamic>>>();

    final rawFrames = <Map<String, dynamic>>[];

    receivePort.listen((message) {
      if (message == null) {
        completer.complete(rawFrames);
        return;
      }

      if (message is Map && message.containsKey('error')) {
        completer.completeError(
          AudioProcessorException(message['error'] as String),
        );
        return;
      }

      if (message is Map && message.containsKey('magnitudes')) {
        rawFrames.add(message as Map<String, dynamic>);
      }
    });

    final hopSize = (kFftSize * kHopRatio).round();
    await Isolate.spawn(
      _stftIsolateEntryPoint,
      _IsolateMessage(
        samples: pcmData.samples,
        sampleRate: pcmData.sampleRate,
        fftSize: kFftSize,
        hopSize: hopSize,
        sendPort: receivePort.sendPort,
      ),
    );

    try {
      final results = await completer.future;
      _frames = results
          .map(
            (r) => VisualizerFrame(
              magnitudes: r['magnitudes'] as Float64List,
              waveformSamples: r['waveform'] as Float32List,
            ),
          )
          .toList();
    } catch (e) {
      throw AudioProcessorException('STFT processing failed: $e');
    }
  }

  VisualizerFrame getFrameAt(Duration position) {
    if (_frames.isEmpty) {
      throw StateError('No frames available. Call load() first.');
    }

    final totalMicroseconds = _totalDuration.inMicroseconds;
    if (totalMicroseconds <= 0) return _frames.first;

    final posMicroseconds = position.inMicroseconds.clamp(
      0,
      totalMicroseconds - 1,
    );
    final frameIndex = (posMicroseconds / totalMicroseconds * _frames.length)
        .floor();
    return _frames[frameIndex.clamp(0, _frames.length - 1)];
  }

  static void _stftIsolateEntryPoint(_IsolateMessage message) {
    try {
      final sendPort = message.sendPort;
      final samples = message.samples;
      final totalSamples = samples.length;

      final stft = STFT(message.fftSize, Window.hanning(message.fftSize));
      final hopSize = message.hopSize;
      var index = 0;

      while (index + message.fftSize <= totalSamples) {
        final chunk = Float64List(message.fftSize);
        final waveform = Float32List(message.fftSize);

        for (int i = 0; i < message.fftSize; i++) {
          chunk[i] = samples[index + i];
          waveform[i] = samples[index + i];
        }

        final magnitudes = Float64List(message.fftSize ~/ 2);
        stft.run(chunk, (freq) {
          for (int i = 0; i < message.fftSize ~/ 2; i++) {
            final real = freq[i].x;
            final imag = freq[i].y;
            magnitudes[i] = real * real + imag * imag;
          }
        });

        sendPort.send({'magnitudes': magnitudes, 'waveform': waveform});

        index += hopSize;
      }

      sendPort.send(null);
    } catch (e) {
      message.sendPort.send({'error': e.toString()});
    }
  }

  static ({Float64List samples, int sampleRate}) _parseWavFile(
    List<int> bytes,
  ) {
    if (bytes.length < 44) {
      throw FormatException('File too small to be a valid WAV file');
    }

    if (bytes[0] != 0x52 ||
        bytes[1] != 0x49 ||
        bytes[2] != 0x46 ||
        bytes[3] != 0x46) {
      throw FormatException('Not a valid WAV file (missing RIFF header)');
    }

    if (bytes[8] != 0x57 ||
        bytes[9] != 0x41 ||
        bytes[10] != 0x56 ||
        bytes[11] != 0x45) {
      throw FormatException('Not a valid WAV file (missing WAVE format)');
    }

    int offset = 12;
    int sampleRate = 0;
    int numChannels = 0;
    int bitsPerSample = 0;
    int dataSize = 0;

    while (offset < bytes.length - 8) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize =
          bytes[offset + 4] |
          (bytes[offset + 5] << 8) |
          (bytes[offset + 6] << 16) |
          (bytes[offset + 7] << 24);

      if (chunkId == 'fmt ') {
        final audioFormat = bytes[offset + 8] | (bytes[offset + 9] << 8);
        if (audioFormat != 1) {
          throw FormatException(
            'Unsupported audio format: $audioFormat (expected PCM)',
          );
        }
        numChannels = bytes[offset + 10] | (bytes[offset + 11] << 8);
        sampleRate =
            bytes[offset + 12] |
            (bytes[offset + 13] << 8) |
            (bytes[offset + 14] << 16) |
            (bytes[offset + 15] << 24);
        bitsPerSample = bytes[offset + 22] | (bytes[offset + 23] << 8);
      } else if (chunkId == 'data') {
        dataSize = chunkSize;
        offset += 8;
        break;
      }

      offset += 8 + chunkSize;
    }

    if (sampleRate == 0 || dataSize == 0) {
      throw FormatException('Invalid WAV file: missing required chunks');
    }

    final numSamples = dataSize ~/ (bitsPerSample ~/ 8) ~/ numChannels;
    final samples = Float64List(numSamples);

    int sampleIndex = 0;
    final bytesPerSample = bitsPerSample ~/ 8;

    for (int i = 0; i < numSamples; i++) {
      double sum = 0;
      for (int ch = 0; ch < numChannels; ch++) {
        final sampleOffset = offset + (i * numChannels + ch) * bytesPerSample;
        double sampleValue;

        if (bitsPerSample == 16) {
          final raw = bytes[sampleOffset] | (bytes[sampleOffset + 1] << 8);
          sampleValue = (raw > 32767 ? raw - 65536 : raw) / 32768.0;
        } else if (bitsPerSample == 32) {
          final raw =
              bytes[sampleOffset] |
              (bytes[sampleOffset + 1] << 8) |
              (bytes[sampleOffset + 2] << 16) |
              (bytes[sampleOffset + 3] << 24);
          sampleValue = raw / 2147483648.0;
        } else if (bitsPerSample == 8) {
          sampleValue = (bytes[sampleOffset] - 128) / 128.0;
        } else {
          throw FormatException('Unsupported bits per sample: $bitsPerSample');
        }

        sum += sampleValue;
      }
      samples[sampleIndex++] = sum / numChannels;
    }

    return (samples: samples, sampleRate: sampleRate);
  }

  void dispose() {
    _frames.clear();
  }
}
