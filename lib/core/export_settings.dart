enum ExportResolution {
  hd720(1280, 720),
  fullHD1080(1920, 1080),
  square720(720, 720),
  vertical1080(1080, 1920);

  const ExportResolution(this.width, this.height);
  final int width;
  final int height;
}

enum ExportFps {
  fps24(24),
  fps30(30),
  fps60(60);

  const ExportFps(this.value);
  final int value;
}

enum ExportPreset {
  ultrafast('ultrafast'),
  fast('fast'),
  medium('medium');

  const ExportPreset(this.value);
  final String value;
}

class ExportSettings {
  final ExportResolution resolution;
  final ExportFps fps;
  final ExportPreset preset;
  final int crf;
  final bool greenScreen;
  final bool includeWaveform;
  final bool includeSpectrumBars;
  final int barCount;
  final double barColorR;
  final double barColorG;
  final double barColorB;
  final double waveColorR;
  final double waveColorG;
  final double waveColorB;

  const ExportSettings({
    this.resolution = ExportResolution.hd720,
    this.fps = ExportFps.fps30,
    this.preset = ExportPreset.ultrafast,
    this.crf = 23,
    this.greenScreen = false,
    this.includeWaveform = true,
    this.includeSpectrumBars = true,
    this.barCount = 64,
    this.barColorR = 0.0,
    this.barColorG = 0.898,
    this.barColorB = 1.0,
    this.waveColorR = 1.0,
    this.waveColorG = 1.0,
    this.waveColorB = 1.0,
  });

  ExportSettings copyWith({
    ExportResolution? resolution,
    ExportFps? fps,
    ExportPreset? preset,
    int? crf,
    bool? greenScreen,
    bool? includeWaveform,
    bool? includeSpectrumBars,
    int? barCount,
    double? barColorR,
    double? barColorG,
    double? barColorB,
    double? waveColorR,
    double? waveColorG,
    double? waveColorB,
  }) {
    return ExportSettings(
      resolution: resolution ?? this.resolution,
      fps: fps ?? this.fps,
      preset: preset ?? this.preset,
      crf: crf ?? this.crf,
      greenScreen: greenScreen ?? this.greenScreen,
      includeWaveform: includeWaveform ?? this.includeWaveform,
      includeSpectrumBars: includeSpectrumBars ?? this.includeSpectrumBars,
      barCount: barCount ?? this.barCount,
      barColorR: barColorR ?? this.barColorR,
      barColorG: barColorG ?? this.barColorG,
      barColorB: barColorB ?? this.barColorB,
      waveColorR: waveColorR ?? this.waveColorR,
      waveColorG: waveColorG ?? this.waveColorG,
      waveColorB: waveColorB ?? this.waveColorB,
    );
  }
}
