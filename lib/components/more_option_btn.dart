import 'package:shadcn_flutter/shadcn_flutter.dart';

class MoreOptionsBtn extends StatefulWidget {
  const MoreOptionsBtn({super.key});
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
        return const DropdownMenu(
          children: [
            // MenuLabel(child: Text('More Actions')),
            // MenuDivider(),
            MenuButton(leading: Icon(Icons.list), child: Text('Music List')),
            MenuButton(leading: Icon(Icons.queue), child: Text('Render Queue')),
            MenuButton(
              leading: Icon(Icons.settings),
              child: Text('Waveform Settings'),
            ),
            MenuDivider(),
            // MenuLabel(child: Text('Other')),
            MenuButton(child: Text('info')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlineButton(
      shape: ButtonShape.circle,
      child: const Icon(Icons.more_horiz),
      onPressed: _toggleMenu,
    );
  }
}
