import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'components/more_option_btn.dart';
import 'models/music_items.dart';
import 'providers/audio_provider.dart';

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
    return const Scaffold(child: MainLayout());
  }
}

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Center(child: Text('Waveform Area')),
        Positioned(bottom: 40, right: 20, child: PlaybackControls()),
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
      data: (state) => Row(
        children: [
          PrimaryButton(
            onPressed: () {
              ref.read(audioNotifierProvider.notifier).playPause();
            },
            shape: ButtonShape.circle,
            child: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
          ),
          MoreOptionsBtn(openMusicList: () => openMusicList(context, ref)),
        ],
      ),
      loading: () => const CircularProgressIndicator(),
      error: (err, stack) => const Icon(Icons.error),
    );
  }
}

void openMusicList(BuildContext context, WidgetRef ref) {
  final audioState = ref.watch(audioNotifierProvider).value;

  final List<MusicItem> musicList = [
    MusicItem(
      title: 'test mp3',
      id: 'assets/file_example_MP3_700KB.mp3',
      size: 5 * 1024 * 1024,
      duration: '2:45',
    ),
    MusicItem(
      title: 'test wav',
      id: 'assets/file_example_WAV_1MG.wav',
      size: 8 * 1024 * 1024,
      duration: '2:45',
    ),
  ];

  openDrawer(
    context: context,
    position: OverlayPosition.bottom,
    builder: (context) {
      return SizedBox(
        height: 400,
        child: Column(
          children: [
            const Text('Music List'),
            const Divider(),
            ...musicList.map((item) {
              final isSelected = audioState?.currentItem?.id == item.id;
              return GestureDetector(
                onTap: () async {
                  if (audioState?.isLoading ?? false) return;

                  await ref
                      .read(audioNotifierProvider.notifier)
                      .selectMusic(item);

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
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
            }),
          ],
        ),
      );
    },
  );
}

void openSettingsControl(BuildContext context) {}
