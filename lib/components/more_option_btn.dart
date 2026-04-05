import 'package:shadcn_flutter/shadcn_flutter.dart';

class MoreOptionsBtn extends StatefulWidget {
  final VoidCallback openMusicList;
  final VoidCallback openRenderQueue;
  final VoidCallback addToRenderQueue;
  final VoidCallback uploadAudio;
  final VoidCallback openWaveformSettings;
  final VoidCallback openInfo;

  const MoreOptionsBtn({
    super.key,
    this.openMusicList = _openMusicList,
    this.openRenderQueue = _openRenderQueue,
    this.addToRenderQueue = _addToRenderQueue,
    this.uploadAudio = _uploadAudio,
    this.openWaveformSettings = _openWaveformSettings,
    this.openInfo = _openInfo,
  });

  static void _openMusicList() {
    print("open music list");
  }

  static void _openRenderQueue() {
    print("open render queue");
  }

  static void _addToRenderQueue() {
    print("add to render queue");
  }

  static void _uploadAudio() {
    print("upload video");
  }

  static void _openWaveformSettings() {
    print("open wave form settings");
  }

  static void _openInfo() {
    print("open info");
  }

  @override
  State<MoreOptionsBtn> createState() => _MoreOptionsBtnState();
}

class _MoreOptionsBtnState extends State<MoreOptionsBtn> {
  final _controller = PopoverController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_controller.hasOpenPopover) {
      _controller.close();
      return;
    }

    _controller.show(
      context: context,
      alignment: Alignment.topRight,
      anchorAlignment: Alignment.bottomRight,
      handler: OverlayHandler.popover,
      offset: Offset(0, 12),
      builder: (context) {
        return DropdownMenu(
          children: [
            MenuButton(
              leading: Icon(Icons.upload),
              child: Text('Upload Audio'),
              onPressed: (context) {
                widget.uploadAudio();
              },
            ),
            MenuButton(
              leading: Icon(Icons.list),
              child: Text('Music List'),
              onPressed: (context) {
                widget.openMusicList();
              },
            ),
            MenuButton(
              leading: Icon(Icons.queue),
              child: Text('Render Queue'),
              onPressed: (context) {
                widget.openRenderQueue();
              },
            ),
            MenuButton(
              leading: Icon(Icons.playlist_add),
              child: Text('Add to Render Queue'),
              onPressed: (context) {
                widget.addToRenderQueue();
              },
            ),
            MenuButton(
              leading: Icon(Icons.playlist_add),
              child: Text('Add to Render Queue'),
              onPressed: (context) {
                widget.addToRenderQueue();
              },
            ),
            MenuButton(
              leading: Icon(Icons.settings),
              child: Text('Waveform Settings'),
              onPressed: (context) {
                widget.openWaveformSettings();
              },
            ),
            MenuDivider(),
            // MenuLabel(child: Text('Other')),
            MenuButton(
              child: Text('info'),
              onPressed: (context) {
                widget.openInfo();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlineButton(
      shape: ButtonShape.circle,
      onPressed: _toggleMenu,
      child: const Icon(Icons.more_horiz),
    );
  }
}
