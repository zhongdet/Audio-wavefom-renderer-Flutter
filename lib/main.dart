import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'components/more_option_btn.dart';

void main() {
  runApp(const MyApp());
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
                child: const Icon(Icons.play_arrow),
                onPressed: () {},
                shape: ButtonShape.circle,
              ),
              MoreOptionsBtn(),
            ],
          ),
        ),
      ],
    );
  }
}
