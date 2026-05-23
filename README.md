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

### Data Flow Overview

```
Audio File (mp3/m4a/flac/ogg/wav)
  -> Decoded to temporary WAV (audio_decoder)
  -> WAV header parsed (sampleRate, bitDepth, channels, PCM offset)
  -> PCM data read on demand (RandomAccessFile, no full-file load)
  -> FFT applied (4096-point, Hanning window)
  -> Magnitude spectrum (2048 bins, 20Hz - 16kHz)
  -> Logarithmic band grouping (configurable bar count)
  -> Physics engine step (attack/decay smoothing)
  -> Bar heights (Float64List)
  -> Rendered to screen (preview) OR written to video (export)
```

### Audio Loading Pipeline

```
User picks file
  -> FilePicker (mp3, m4a, flac, ogg, wav)
  -> VisualizerNotifier.loadAudioFile(path)
    -> AudioProcessor.load(path)
      -> AudioDecoder.convertToWav(inputPath, tempWavPath)
      -> RandomAccessFile.openSync(tempWavPath)
      -> Parse WAV header (RIFF/WAVE chunks, fmt/data blocks)
      -> Extract: sampleRate, bitsPerSample, numChannels, totalSamples, pcmOffset
      -> Compute totalFrameCount = totalSamples / (kFftSize * kHopRatio)
    -> AudioPlayer.setFilePath(path) (just_audio, for playback)
    -> Create PreviewController + ExportCoordinator (both hold AudioProcessor)
    -> Add MusicItem to list
```

### Frame Computation (Preview & Export Shared)

```
Given: audio position (Duration) or frame index
  -> Calculate frameIndex = (position / totalDuration) * totalFrameCount
  -> Compute sampleStart = frameIndex * hopSize  (hopSize = 2048 samples)
  -> Read PCM chunk from WAV file at sampleStart
    -> Parse bytes to normalized float64 (handles 8/16/32-bit, multi-channel mix)
  -> Run FFT (fftea, 4096-point, Hanning window)
    -> For each of 2048 frequency bins: magnitude = sqrt(real² + imag²) / (fftSize/2)
  -> Return VisualizerFrame { magnitudes: Float32List[2048] }
```

### Preview (Real-time) Pipeline

```
User presses Play
  -> AudioPlayer starts playback (just_audio)
  -> VisualizerNotifier listens to play/pause state
    -> On play: record wall-clock time + current position
    -> Start Timer.periodic(intervalMs)
       intervalMs = 1000 / (sampleRate / (kFftSize * kHopRatio))  ≈ 42ms (~23.4Hz)
  -> Each timer tick:
    -> Compute interpolated position = playbackStartPosition + (now - playbackStartTime)
    -> PreviewController.tick(interpolatedPosition)
      -> AudioProcessor.getFrameAt(position)
        -> Frame index calculation + PCM read + FFT
        -> Return VisualizerFrame
      -> VisualizerRenderer.computeHeights(magnitudes, dt)
        -> PhysicsEngine.step(magnitudes, dt)
          -> For each band (logarithmic frequency group):
            -> localMax = max(magnitudes[bandStart..bandEnd])
            -> target = pow(localMax, contrast) * barHeightMultiplier
            -> Soft ceiling compression (threshold + exponential falloff)
            -> Attack (rise) or Decay (fall) based on dtRatio
          -> Return Float64List heights
      -> notifyListeners()
    -> Flutter rebuilds
    -> CustomPaint -> SpectrumBarsPainter -> Canvas.drawRRect()
    -> Display 16:9 bar visualization (scaled to screen)
  -> On pause / settings change:
    -> Stop timer, reset physics engine
```

### Export Pipeline

```
User clicks "Add to Render Tasks" (or "Export")
  -> ExportCoordinator created with: AudioProcessor + VisualizerSettings + audioFilePath
    -> Method defaults to: Hardware + Mux Audio

startExport()
  |
  +-> Step 1: Pre-compute all frames
  |     AudioProcessor.getAllFrames()
  |       -> For frameIndex 0..totalFrameCount-1:
  |          -> Read PCM + FFT -> VisualizerFrame (same as preview)
  |          -> Yield every 10 frames (await Future.delayed(Duration.zero))
  |       -> Return List<VisualizerFrame>
  |
  +-> Step 2: Choose encode path based on settings
  |
  +--- [includeAudio == true]  (default — most common)
  |     |
  |     +-> _exportWithHardware(frames, fpsOverride=correctFps)
  |     |     |
  |     |     +-> OffscreenRenderer.renderFrame(heights, settings) for each frame
  |     |     |   -> PictureRecorder + Canvas + SpectrumPainter
  |     |     |   -> toImage() -> toByteData(RGBA) -> Uint8List
  |     |     |
  |     |     +-> HardwareExporter.appendVideoFrame(rgbaPixels)
  |     |     |   -> flutter_quick_video_encoder (native GPU encoding)
  |     |     |
  |     |     +-> HardwareExporter.finish() -> Returns silentVideoPath (.mp4)
  |     |
  |     +-> FFmpegExporter.muxAudio(silentVideoPath, audioPath, outputPath)
  |     |   -> ffmpeg -i video.mp4 -i audio.mp3
  |     |            -c:v copy -c:a aac -b:a 192k
  |     |            -map 0:v -map 1:a -shortest
  |     |            output_with_audio.mp4
  |     |
  |     +-> Delete silentVideoPath (cleanup)
  |     +-> Return outputPath
  |
  +--- [includeAudio == false && method == Hardware]
  |     |
  |     +-> _exportWithHardware(frames)
  |         -> Same as above, no mux step
  |         -> Returns MP4 directly
  |
  +--- [method == FFmpeg]
  |     |
  |     +-> FFmpegExporter.setupRawFile()
  |     |   -> Create temp directory -> output.rgba + output.mp4
  |     |
  |     +-> For each frame:
  |     |   -> OffscreenRenderer.renderFrame(heights, settings) -> Uint8List RGBA
  |     |   -> FFmpegExporter.writeFrame(pixels) -> append to .rgba file
  |     |
  |     +-> FFmpegExporter.executeCommand(width, height, fps, preset, crf)
  |     |   -> ffmpeg -f rawvideo -pixel_format rgba -video_size 1280x720
  |     |            -framerate 30 -i frames.rgba
  |     |            -c:v libx264 -pix_fmt yuv420p
  |     |            -preset ultrafast -crf 23 output.mp4
  |     |
  |     +-> FFmpegExporter.cleanup() -> Delete .rgba file
  |     +-> Return outputPath
  |
  +-> Progress stream: 0.0 -> 1.0 (per-frame)
  +-> Return final outputPath
```

### Export Queue Pipeline

```
User adds multiple export tasks
  -> ExportQueueNotifier.addToQueue(audioPath, fileName, settings)
    -> Create ExportQueueItem (status: queued)
    -> Append to items list
    -> _processNext()
       |
       +-> Find first item with status == queued
       +-> _renderItem(itemIndex)
       |   -> Create new AudioProcessor() -> load(audioPath)
       |   -> Create ExportCoordinator(processor, settings, audioPath)
       |   -> Set status = rendering
       |   -> Subscribe to coordinator.progress stream
       |   -> coordinator.startExport() -> await
       |   -> On success: status = completed, outputPath set
       |   -> On failure: status = failed, errorMessage set
       |   -> Cleanup: dispose processor + coordinator
       |
       +-> Loop back to _processNext() (handles next queued item)
  -> All items processed sequentially (one at a time)
  -> UI shows progress per item via exportQueueProvider
```

### Core Rendering Engine

```
Input: Float32List magnitudes[2048] + double dt
  -> Frequency bands generated (once, on construction)
     -> Logarithmic spacing: f0 = 20Hz, f1 = 16kHz
     -> For N bars: band[i] = [logScale(minFreq, maxFreq, i), logScale(minFreq, maxFreq, i+1)]
     -> Map to FFT bins: bin = floor(freq * fftSize / sampleRate)
  -> For each bar b (0..barCount-1):
     -> (bandStart, bandEnd) = bands[b]
     -> localMax = max(magnitudes[bandStart..bandEnd])
     -> target = pow(localMax, contrast) * barHeightMultiplier
     -> Soft ceiling: if target > threshold:
                    target = threshold + (1 - exp(-(target - threshold) * strength)) / strength
     -> If target > current[b]: current[b] += (target - current[b]) * (1 - pow(1 - attack, dtRatio))
     -> If target <= current[b]: current[b] *= pow(decay, dtRatio)
     -> current[b] = max(0.001, current[b])
  -> Return Float64List heights
```

### UI Painting (Preview & Export Shared)

```
Input: Float64List heights[barCount] + Size + VisualizerSettings
  -> Compute bar dimensions (scaled by resolution ratio)
  -> centerX = (canvasWidth - totalBarWidth) / 2
  -> centerY = canvasHeight / 2
  -> For each bar i:
     -> h = heights[i] * canvasHeight * positiveHeightScale
     -> x = i * (barWidth + spacing) + centerX
     -> y = centerY - h / 2  (bars grow up and down from center)
     -> Draw RRect with top corner radius
  -> Paint uses positiveColor (default: white)
```

### Configuration Defaults

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
