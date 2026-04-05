import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/export/ffmpeg_exporter.dart';

void main() {
  group('FFmpegExporter', () {
    test('FFmpegExportException can be constructed', () {
      final exception = FFmpegExportException('test error');
      expect(exception.message, 'test error');
    });

    test('FFmpegExporter can be instantiated', () {
      final exporter = FFmpegExporter();
      expect(exporter, isNotNull);
    });

    test('closePipe is safe to call without setupPipe', () async {
      final exporter = FFmpegExporter();
      await exporter.closePipe();
    });
  });
}
