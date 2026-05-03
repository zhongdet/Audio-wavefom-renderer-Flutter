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
  final bool includeSpectrumBars;
  final double barColorR;
  final double barColorG;
  final double barColorB;

  const ExportSettings({
    this.resolution = ExportResolution.hd720,
    this.fps = ExportFps.fps30,
    this.preset = ExportPreset.ultrafast,
    this.crf = 23,
    this.greenScreen = false,
    this.includeSpectrumBars = true,
    this.barColorR = 0.0,
    this.barColorG = 0.898,
    this.barColorB = 1.0,
  });

  ExportSettings copyWith({
    ExportResolution? resolution,
    ExportFps? fps,
    ExportPreset? preset,
    int? crf,
    bool? greenScreen,
    bool? includeSpectrumBars,
    double? barColorR,
    double? barColorG,
    double? barColorB,
  }) {
    return ExportSettings(
      resolution: resolution ?? this.resolution,
      fps: fps ?? this.fps,
      preset: preset ?? this.preset,
      crf: crf ?? this.crf,
      greenScreen: greenScreen ?? this.greenScreen,
      includeSpectrumBars: includeSpectrumBars ?? this.includeSpectrumBars,
      barColorR: barColorR ?? this.barColorR,
      barColorG: barColorG ?? this.barColorG,
      barColorB: barColorB ?? this.barColorB,
    );
  }
}
