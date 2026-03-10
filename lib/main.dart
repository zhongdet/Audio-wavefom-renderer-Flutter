import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'components/more_option_btn.dart';
import 'models/music_items.dart';
import 'package:provider/provider.dart';
import 'providers/audio_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AudioProvider(),
      child: const MyApp(),
    ),
  );
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
    return Stack(
      children: [
        const Center(child: Text('Waveform Area')),
        Positioned(
          bottom: 40,
          right: 20,
          child: Row(
            children: [
              PrimaryButton(
                onPressed: () {},
                shape: ButtonShape.circle,
                child: const Icon(Icons.play_arrow),
              ),
              MoreOptionsBtn(
                openMusicList: () {
                  openMusicList(context);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void openMusicList(BuildContext context) {
  final audioProvider = Provider.of<AudioProvider>(context, listen: false);

  final List<MusicItem> musicList = [
    MusicItem(
      title: 'Sample Song 1',
      id: 'assets/file_example_MP3_700KB.mp3',
      size: 5 * 1024 * 1024,
      duration: '2:45',
    ),
    MusicItem(
      title: 'Sample Song 2',
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
              final isSelected = audioProvider.currentItem?.id == item.id;
              return GestureDetector(
                onTap: () async {
                  await audioProvider.selectMusic(item);
                  Navigator.pop(context);
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
