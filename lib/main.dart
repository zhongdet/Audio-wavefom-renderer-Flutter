import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'components/components.dart';
import 'components/visualizer.dart';
import 'components/export_settings_drawer.dart';
import 'components/render_queue_drawer.dart';
import 'providers/providers.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: ColorSchemes.darkZinc),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
      menuHandler: OverlayHandler.popover,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      child: Stack(
        children: [
          const MainVisualizer(),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: PlaybackControls(),
            ),
          ),
        ],
      ),
    );
  }
}

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const MainVisualizer(),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: PlaybackControls(),
          ),
        ),
      ],
    );
  }
}

class PlaybackControls extends ConsumerWidget {
  const PlaybackControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioAsync = ref.watch(audioNotifierProvider);

    return audioAsync.when(
      data: (state) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SeekSlider(state: state, ref: ref),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PrimaryButton(
                  onPressed: () {
                    ref.read(audioNotifierProvider.notifier).playPause();
                  },
                  shape: ButtonShape.circle,
                  child: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
                MoreOptionsBtn(
                  uploadAudio: () =>
                      ref.read(visualizerProvider.notifier).pickAndLoadAudio(),
                  openRenderQueue: () => openRenderQueueDrawer(context, ref),
                  addToRenderQueue: () => openExportSettings(context, ref),
                  openMusicList: () => openMusicList(context, ref),
                  openWaveformSettings: () => openSettingsControl(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (err, stack) => const Icon(Icons.error),
    );
  }
}

class _SeekSlider extends ConsumerStatefulWidget {
  final AudioState state;
  final WidgetRef ref;

  const _SeekSlider({required this.state, required this.ref});

  @override
  ConsumerState<_SeekSlider> createState() => _SeekSliderState();
}

class _SeekSliderState extends ConsumerState<_SeekSlider> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final duration = widget.state.duration;
    final position = widget.state.position;
    final totalSeconds = duration.inSeconds.toDouble();
    final currentSeconds = position.inSeconds.toDouble();
    final value = totalSeconds > 0 ? currentSeconds / totalSeconds : 0.0;
    final displayValue = _dragValue ?? value;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Text(
                _formatDuration(
                  Duration(seconds: (displayValue * totalSeconds).toInt()),
                ),
                style: const TextStyle(fontSize: 12),
              ),
              Flexible(
                child: Slider(
                  value: SliderValue.single(displayValue.clamp(0.0, 1.0)),
                  onChanged: (v) {
                    setState(() => _dragValue = v.value);
                  },
                  onChangeEnd: (v) {
                    setState(() => _dragValue = null);
                    final seekTo = Duration(
                      seconds: (v.value * totalSeconds).toInt(),
                    );
                    widget.ref
                        .read(audioNotifierProvider.notifier)
                        .seek(seekTo);
                  },
                ),
              ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = d.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

void openMusicList(BuildContext context, WidgetRef ref) {
  openDrawer(
    context: context,
    position: OverlayPosition.bottom,
    builder: (context) {
      return SizedBox(
        height: 600,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const Text('Music List'),
              Gap(16),
              const Divider(),
              Gap(16),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final musicListState = ref.watch(musicListProvider);
                    final audioState = ref.watch(audioNotifierProvider).value;

                    if (musicListState.items.isEmpty) {
                      return const Center(
                        child: Text(
                          'No audio files loaded.\nUse Upload Audio to add files.',
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: musicListState.items.length,
                      itemBuilder: (context, index) {
                        final item = musicListState.items[index];
                        final isSelected =
                            musicListState.selectedId == item.id ||
                            audioState?.currentItem?.id == item.id;

                        return GestureDetector(
                          onTap: () async {
                            final isLoading = audioState?.isLoading ?? false;
                            if (isLoading) return;

                            ref
                                .read(musicListProvider.notifier)
                                .selectItem(item.id);

                            await ref
                                .read(visualizerProvider.notifier)
                                .loadAudioFile(item.id);

                            if (context.mounted) {
                              closeOverlay(context);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.music_note),
                                Gap(12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.title),
                                      Text(
                                        '${(item.size / 1024 / 1024).toStringAsFixed(1)} MB',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check, color: Colors.green),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void openSettingsControl(BuildContext context, WidgetRef ref) {
  openVisualizerSettings(context, ref);
}
