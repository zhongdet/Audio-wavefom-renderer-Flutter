# Audio Waveform Visualizer (Flutter)

A Flutter mobile app that renders real-time audio spectrum visualizers and exports them as MP4 videos. Features a physics-based bar animation engine, FFT spectrum analysis, and multiple export pipelines (hardware encoder + FFmpeg).

## Features

- **Real-time spectrum visualization** — 64 bar columns (configurable 1 to 256) mapped to logarithmic frequency bands (20 Hz to 16 kHz) via 4096-point FFT with Hanning window.
- **Physics-based animation** — Attack/decay smoothing with configurable soft-ceiling compression for natural-looking bar movement.
- **Audio playback** — Play, pause, and seek through loaded tracks via `just_audio`.
- **Music list** — Load multiple audio files and switch between them.
- **Export to MP4** — Render the visualizer as a video with two backends:
  - **Hardware encoder** — `flutter_quick_video_encoder` for on-device GPU encoding.
  - **FFmpeg** — `ffmpeg_kit_flutter` for libx264 software encoding with configurable CRF and preset.
- **Audio mux** — When audio is included in the export, the app renders a silent video via the hardware encoder then muxes the original audio track with FFmpeg.
- **Export queue** — Batch export multiple tracks with settings; jobs render sequentially with progress tracking.
- **Comprehensive settings** — Four tabs (Bars, Physics, Frequency, Style) with sliders and color pickers.
  - Bars: count, width, total width, spacing, corner radius, height scales.
  - Physics: attack, decay, contrast, height multiplier, soft ceiling threshold/strength, reference FPS.
  - Frequency: min/max frequency range.
  - Style: background, positive/negative bar colors, Y offset.
- **Export options** — Resolution (480p / 720p / 1080p), FPS (24/30/60), FFmpeg preset (ultrafast to veryslow), CRQ quality (0-51), green screen toggle, audio inclusion toggle.

## Architecture

```
lib/
  main.dart                    # App entry, ShadcnApp, Scaffold with visualizer + playback controls
  components/
    visualizer.dart            # MainVisualizer widget, SpectrumBarsPainter
    visualizer_settings_drawer.dart  # Settings UI (4-tab drawer)
    export_settings_drawer.dart        # Export settings UI
    render_tasks_drawer.dart         # Export queue UI
    more_option_btn.dart           # Action button overlay
    settings_input.dart            # Reusable slider + text input widget
  core/
    physics_engine.dart          # Attack/decay step simulation per frequency band
    visualizer_renderer.dart     # Orchestrates FFT bands + physics engine
    visualizer_frame.dart        # FFT magnitude frame container
    spectrum_painter.dart        # Canvas2D drawing of spectrum bars
    frequency_bands.dart         # Logarithmic band-to-FFT-bin mapping
    constants.dart               # kFftSize=4096, kMinFreq=20, kMaxFreq=16000, etc.
    visualizer_settings.dart     # Core physics settings (attack, decay, etc.)
    export_settings.dart         # Export enums (Resolution, Fps, Preset)
  audio/
    audio_processor.dart         # Audio decode to WAV, PCM parsing, per-frame FFT
  export/
    export_coordinator.dart      # Orchestrates frame rendering + export pipeline
    offscreen_renderer.dart      # PictureRecorder -> RGBA pixel buffer
    hardware_exporter.dart       # flutter_quick_video_encoder wrapper
    ffmpeg_exporter.dart         # Raw video + libx264 + audio mux via FFmpeg
  providers/
    visualizer_provider.dart     # Main state: processor, preview, export coordinator
    audio_provider.dart          # Audio playback state (just_audio wrapper)
    visualizer_settings_provider.dart  # Global settings singleton
    music_list_provider.dart     # Loaded tracks list
    export_queue_provider.dart   # Batch export queue
  models/
    visualizer_settings.dart     # Full settings model (UI + export options)
    music_items.dart             # MusicItem model
```

## Tech Stack

| Area | Library |
|---|---|
| UI framework | Flutter 3.11+ |
| UI components | shadcn_flutter (dark zinc theme) |
| State management | flutter_riverpod 3.x |
| Audio playback | just_audio |
| Audio decode | audio_decoder (to WAV) |
| FFT | fftea (4096-point, Hanning window) |
| Hardware video | flutter_quick_video_encoder |
| Software video | ffmpeg_kit_flutter_new (libx264) |
| File picker | file_picker |
| Storage | path_provider |

## Getting Started

### Prerequisites

- Flutter SDK 3.11.1 or later
- Android device/emulator (export features require native codecs)

### Setup

```bash
cd ~/Projects/Audio-wavefom-renderer-Flutter
flutter pub get
flutter run
```

### Build

```bash
flutter build apk --release
```

## How It Works

### Audio Processing Pipeline

1. **Decode** — Input audio (mp3, m4a, flac, ogg, wav) is decoded to a temporary WAV file using `audio_decoder`.
2. **WAV parsing** — The app reads the WAV header (sample rate, bit depth, channels, PCM offset) via `RandomAccessFile` without loading the full file into memory.
3. **Frame extraction** — For each playback position, a 4096-sample PCM chunk is read, converted to normalized float64, and passed through an FFT. Magnitudes are computed from complex frequency bins.
4. **Band mapping** — 4096 FFT bins are divided into N logarithmic frequency bands (configurable count, min/max frequency). Each band's local maximum magnitude drives its bar height.

### Physics Engine

Each frame, the physics engine applies:

1. **Target computation** — `magnitude ^ contrast * barHeightMultiplier`, capped by soft ceiling: `threshold + (1 - exp(-excess * strength)) / strength`.
2. **Attack** — When target > current: `current += (target - current) * (1 - pow(1 - attack, dtRatio))`.
3. **Decay** — When target <= current: `current *= pow(decay, dtRatio)`.
4. **Minimum clamp** — Heights never drop below 0.001.

`dtRatio` normalizes timing to a 60 FPS reference, ensuring consistent behavior at different frame rates.

### Export Pipeline

1. **Pre-compute** all frames (iterates through entire audio duration).
2. **Render** each frame offscreen (PictureRecorder -> RGBA buffer) by drawing spectrum bars on a colored background.
3. **Encode** — Either hardware encoder (direct MP4 output) or FFmpeg (raw RGBA -> libx264).
4. **Mux audio** (if enabled) — FFmpeg remuxes the original audio track into the video.
5. **Clean up** — Temporary files (decoded WAV, raw frames) are deleted.

## Configuration Defaults

| Setting | Default |
|---|---|
| Bar count | 64 |
| Bar width | 4.0 px |
| FFT size | 4096 |
| Min frequency | 20 Hz |
| Max frequency | 16000 Hz |
| Attack | 0.26 |
| Decay | 0.92 |
| Contrast | 1.0 |
| Export resolution | 1280x720 (HD) |
| Export FPS | 30 |
| Export preset | ultrafast |
| CRF | 23 |
| Positive color | White (#FFFFFF) |
| Negative color | Dark gray (#484848) |

## Project Structure Notes

- **Two `VisualizerSettings` classes**: The model in `lib/models/visualizer_settings.dart` contains the full UI/export settings (colors, resolution, encoder type). The core version in `lib/core/visualizer_settings.dart` contains only physics parameters. The model converts between them via `toCoreSettings()`.
- **Export method selection**: The visualizer state includes an `encoder` field (`AudioEncoder.webcodecHw`, `AudioEncoder.webcodecSw`, `AudioEncoder.ffmpeg`) that routes to the appropriate export backend. When audio is included, hardware encoding is always used for the silent video + FFmpeg mux to avoid large intermediate files.
- **Export queue**: The queue provider processes items sequentially. Each item creates its own `AudioProcessor` and `ExportCoordinator`, with proper cleanup on completion or cancellation.

## Known Limitations

- Exporting all frames is synchronous per-frame — long tracks may take significant time to process.
- The WAV decode creates a temporary file in the app's cache directory.
- FFmpeg export writes raw RGBA frames to disk before encoding, which can use substantial storage for high-resolution, long-duration exports.

## TODOs

- Test in a extreme environment, such as 10 minutes audio
- Isolate process applying on: export tasks, audio decode 