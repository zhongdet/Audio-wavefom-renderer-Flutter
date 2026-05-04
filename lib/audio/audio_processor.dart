import 'dart:io';
import 'dart:math';
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

class AudioProcessor {
  String? _wavFilePath;
  int _sampleRate = 0;
  Duration _totalDuration = Duration.zero;

  // WAV 文件信息
  int _pcmOffset = 0;
  int _bitsPerSample = 0;
  int _numChannels = 0;
  int _totalSamples = 0;
  bool _disposed = false;

  Duration get totalDuration => _totalDuration;
  int get sampleRate => _sampleRate;
  int get totalFrameCount {
    if (_totalSamples == 0) return 0;
    final hopSize = (kFftSize * kHopRatio).round();
    return (_totalSamples / hopSize).ceil();
  }

  Future<void> load(String filePath) async {
    // 清理舊數據
    dispose();
    _disposed = false;

    // Step 1: 解碼音頻到 WAV
    final tempDir = await getTemporaryDirectory();
    final wavPath =
        '${tempDir.path}/decoded_${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await AudioDecoder.convertToWav(filePath, wavPath);
    } catch (e) {
      throw AudioProcessorException('Failed to decode audio: $e');
    }

    // Step 2: 解析 WAV 頭部（使用 RandomAccessFile，不讀取整個文件）
    final wavFile = File(wavPath);
    final raf = await wavFile.open(mode: FileMode.read);

    try {
      final header = await _parseWavHeader(raf);
      _wavFilePath = wavPath;
      _sampleRate = header.sampleRate;
      _bitsPerSample = header.bitsPerSample;
      _numChannels = header.numChannels;
      _totalSamples = header.totalSamples;
      _pcmOffset = header.pcmOffset;

      _totalDuration = Duration(
        microseconds: (_totalSamples / _sampleRate * 1000000).toInt(),
      );
    } finally {
      await raf.close();
    }
  }

  Future<_WavHeader> _parseWavHeader(RandomAccessFile raf) async {
    // 讀取足夠的字節來解析頭部
    final bytes = await raf.read(256);

    if (bytes.length < 44) {
      throw FormatException('File too small to be a valid WAV file');
    }

    // 檢查 RIFF 標識
    if (bytes[0] != 0x52 ||
        bytes[1] != 0x49 ||
        bytes[2] != 0x46 ||
        bytes[3] != 0x46) {
      throw FormatException('Not a valid WAV file (missing RIFF header)');
    }

    // 檢查 WAVE 標識
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
    int dataOffset = 0;

    while (offset < bytes.length - 8) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = bytes[offset + 4] |
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
        sampleRate = bytes[offset + 12] |
            (bytes[offset + 13] << 8) |
            (bytes[offset + 14] << 16) |
            (bytes[offset + 15] << 24);
        bitsPerSample = bytes[offset + 22] | (bytes[offset + 23] << 8);
      } else if (chunkId == 'data') {
        dataSize = chunkSize;
        dataOffset = offset + 8;
        break;
      }

      offset += 8 + chunkSize;
    }

    if (sampleRate == 0 || dataSize == 0) {
      throw FormatException('Invalid WAV file: missing required chunks');
    }

    final totalSamples = dataSize ~/ (bitsPerSample ~/ 8) ~/ numChannels;

    return _WavHeader(
      sampleRate: sampleRate,
      bitsPerSample: bitsPerSample,
      numChannels: numChannels,
      totalSamples: totalSamples,
      pcmOffset: dataOffset,
    );
  }

  VisualizerFrame getFrameAt(Duration position) {
    if (_wavFilePath == null || _disposed) {
      return _getEmptyFrame();
    }

    final totalMicroseconds = _totalDuration.inMicroseconds;
    if (totalMicroseconds <= 0) return _getEmptyFrame();

    final posMicroseconds = position.inMicroseconds.clamp(
      0,
      totalMicroseconds - 1,
    );

    final totalFrames = totalFrameCount;
    if (totalFrames == 0) return _getEmptyFrame();

    final frameIndex =
        (posMicroseconds / totalMicroseconds * totalFrames).floor();
    final clampedIndex = frameIndex.clamp(0, totalFrames - 1);

    return _computeFrameSync(clampedIndex);
  }

  VisualizerFrame _computeFrameSync(int frameIndex) {
    final hopSize = (kFftSize * kHopRatio).round();
    final sampleStart = frameIndex * hopSize;
    final samplesRemaining = _totalSamples - sampleStart;
    final sampleCount = samplesRemaining >= kFftSize ? kFftSize : samplesRemaining;

    if (sampleCount <= 0) return _getEmptyFrame();

    // 讀取 PCM 數據
    final samples = _readPcmChunkSync(sampleStart, sampleCount);

    // 執行 STFT
    final stft = STFT(kFftSize, Window.hanning(kFftSize));
    final magnitudes = Float32List(kFftSize ~/ 2);

    stft.run(samples, (freq) {
      for (int i = 0; i < kFftSize ~/ 2; i++) {
        final real = freq[i].x;
        final imag = freq[i].y;
        final magnitude = sqrt(real * real + imag * imag) / (kFftSize / 2);
        magnitudes[i] = magnitude;
      }
    });

    return VisualizerFrame(magnitudes: magnitudes);
  }

  Float64List _readPcmChunkSync(int sampleStart, int sampleCount) {
    final bytesPerSample = _bitsPerSample ~/ 8;
    final fileOffset = _pcmOffset + sampleStart * bytesPerSample * _numChannels;

    final file = File(_wavFilePath!);
    final raf = file.openSync();
    try {
      raf.setPositionSync(fileOffset);

      final bytesToRead = sampleCount * bytesPerSample * _numChannels;
      final bytes = raf.readSync(bytesToRead);

      // 解析 PCM 數據
      final samples = Float64List(kFftSize);
      int sampleIndex = 0;
      for (int i = 0; i < sampleCount && sampleIndex < kFftSize; i++) {
        double sum = 0;
        for (int ch = 0; ch < _numChannels; ch++) {
          final offset = (i * _numChannels + ch) * bytesPerSample;
          double sampleValue;

          if (_bitsPerSample == 16) {
            if (offset + 1 < bytes.length) {
              final raw = bytes[offset] | (bytes[offset + 1] << 8);
              sampleValue = (raw > 32767 ? raw - 65536 : raw) / 32768.0;
            } else {
              sampleValue = 0;
            }
          } else if (_bitsPerSample == 32) {
            if (offset + 3 < bytes.length) {
              final raw = bytes[offset] |
                  (bytes[offset + 1] << 8) |
                  (bytes[offset + 2] << 16) |
                  (bytes[offset + 3] << 24);
              sampleValue = raw / 2147483648.0;
            } else {
              sampleValue = 0;
            }
          } else if (_bitsPerSample == 8) {
            if (offset < bytes.length) {
              sampleValue = (bytes[offset] - 128) / 128.0;
            } else {
              sampleValue = 0;
            }
          } else {
            sampleValue = 0;
          }
          sum += sampleValue;
        }
        samples[sampleIndex++] = sum / _numChannels;
      }
      return samples;
    } finally {
      raf.closeSync();
    }
  }

  VisualizerFrame _getEmptyFrame() {
    return VisualizerFrame(
      magnitudes: Float32List(kFftSize ~/ 2),
    );
  }

  // 為了向後兼容和導出功能，提供 frames getter
  // 注意：這會計算所有幀，可能耗時
  List<VisualizerFrame> get frames {
    final totalFrames = totalFrameCount;
    final result = <VisualizerFrame>[];
    for (int i = 0; i < totalFrames; i++) {
      result.add(_computeFrameSync(i));
    }
    return result;
  }

  // 異步獲取所有幀（為了兼容導出）
  Future<List<VisualizerFrame>> getAllFrames() async {
    final totalFrames = totalFrameCount;
    final result = <VisualizerFrame>[];
    for (int i = 0; i < totalFrames; i++) {
      result.add(_computeFrameSync(i));
      // 每計算 10 個幀讓出一次事件循環
      if (i % 10 == 0) {
        await Future.delayed(Duration.zero);
      }
    }
    return result;
  }

  void dispose() {
    _disposed = true;

    // 刪除臨時 WAV 文件
    if (_wavFilePath != null) {
      final file = File(_wavFilePath!);
      if (file.existsSync()) {
        file.deleteSync();
      }
      _wavFilePath = null;
    }

    _sampleRate = 0;
    _totalDuration = Duration.zero;
    _pcmOffset = 0;
    _bitsPerSample = 0;
    _numChannels = 0;
    _totalSamples = 0;
  }
}

class _WavHeader {
  final int sampleRate;
  final int bitsPerSample;
  final int numChannels;
  final int totalSamples;
  final int pcmOffset;

  _WavHeader({
    required this.sampleRate,
    required this.bitsPerSample,
    required this.numChannels,
    required this.totalSamples,
    required this.pcmOffset,
  });
}
