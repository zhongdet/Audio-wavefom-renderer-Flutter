import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../core/export_settings.dart';
import '../providers/export_queue_provider.dart';
import '../providers/visualizer_provider.dart';
import '../providers/visualizer_settings_provider.dart';

Widget buildToast(
  BuildContext context,
  ToastOverlay overlay, {
  required String title,
  required String subtitle,
}) {
  return SurfaceCard(
    child: Basic(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: PrimaryButton(
        size: ButtonSize.small,
        onPressed: () {
          overlay.close();
        },
        child: const Text('OK'),
      ),
      trailingAlignment: Alignment.center,
    ),
  );
}

void openExportSettings(BuildContext context, WidgetRef ref) {
  final visState = ref.read(visualizerProvider);
  if (visState.filePath == null) {
    showToast(
      context: context,
      builder: (context, overlay) =>
          buildToast(context, overlay, title: "No Audio loaded", subtitle: "INFO"),
      location: ToastLocation.topRight,
    );
    return;
  }

  openDrawer(
    context: context,
    position: OverlayPosition.bottom,
    builder: (drawerContext) => _ExportSettingsContent(
      rootContext: context,
      audioFilePath: visState.filePath!,
      audioFileName: visState.filePath!.split('/').last,
    ),
  );
}

class _ExportSettingsContent extends ConsumerStatefulWidget {
  final BuildContext rootContext;
  final String audioFilePath;
  final String audioFileName;

  const _ExportSettingsContent({
    required this.rootContext,
    required this.audioFilePath,
    required this.audioFileName,
  });

  @override
  ConsumerState<_ExportSettingsContent> createState() =>
      _ExportSettingsContentState();
}

class _ExportSettingsContentState
    extends ConsumerState<_ExportSettingsContent> {
  void _handleAddToQueue() {
    final visualizerSettings = ref.read(visualizerSettingsProvider);
    ref
        .read(exportQueueProvider.notifier)
        .addToQueue(
          widget.audioFilePath,
          widget.audioFileName,
          visualizerSettings,
        );
    showToast(
      context: widget.rootContext,
      builder: (context, overlay) => buildToast(context, overlay, title: "Add to renderer queue", subtitle: "INFO"),
      location: ToastLocation.topRight,
    );
    closeOverlay(context);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(visualizerSettingsProvider);
    return SizedBox(
      height: 600,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const Text('Export Settings'),
            const Gap(16),
            const Divider(),
            const Gap(16),
            Expanded(
              child: ListView(
                children: [
                  _SelectRow<ExportResolution>(
                    label: 'Resolution',
                    value: settings.resolution,
                    items: ExportResolution.values,
                    itemLabel: (r) => '${r.width}x${r.height}',
                    onChanged: (v) {
                      if (v != null) {
                        ref
                            .read(visualizerSettingsProvider.notifier)
                            .patch(resolution: v);
                      }
                    },
                  ),
                  _SelectRow<ExportFps>(
                    label: 'FPS',
                    value: settings.fps,
                    items: ExportFps.values,
                    itemLabel: (f) => '${f.value} fps',
                    onChanged: (v) {
                      if (v != null) {
                        ref
                            .read(visualizerSettingsProvider.notifier)
                            .patch(fps: v);
                      }
                    },
                  ),
                  _SelectRow<ExportPreset>(
                    label: 'Preset',
                    value: settings.preset,
                    items: ExportPreset.values,
                    itemLabel: (p) => p.value,
                    onChanged: (v) {
                      if (v != null) {
                        ref
                            .read(visualizerSettingsProvider.notifier)
                            .patch(preset: v);
                      }
                    },
                  ),
                  _ToggleRow(
                    label: 'Green Screen',
                    value: settings.greenScreen,
                    onChanged: (v) {
                      ref
                          .read(visualizerSettingsProvider.notifier)
                          .patch(greenScreen: v);
                    },
                  ),
                  _ToggleRow(
                    label: 'Spectrum Bars',
                    value: settings.includeSpectrumBars,
                    onChanged: (v) {
                      ref
                          .read(visualizerSettingsProvider.notifier)
                          .patch(includeSpectrumBars: v);
                    },
                  ),
                  _ToggleRow(
                    label: 'Include Audio',
                    value: settings.includeAudio,
                    onChanged: (v) {
                      ref
                          .read(visualizerSettingsProvider.notifier)
                          .patch(includeAudio: v);
                    },
                  ),
                  _SliderRow(
                    label: 'Quality (CRF)',
                    value: settings.crf.toDouble(),
                    min: 0,
                    max: 51,
                    onChanged: (v) {
                      ref
                          .read(visualizerSettingsProvider.notifier)
                          .patch(crf: v.toInt());
                    },
                  ),
                ],
              ),
            ),
            const Gap(16),
            PrimaryButton(
              onPressed: _handleAddToQueue,
              child: const Text('Add to Render Queue'),
            ),
            const Gap(16),
          ],
        ),
      ),
    );
  }
}

class _SelectRow<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _SelectRow({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          SizedBox(
            width: 140,
            child: Select<T>(
              value: value,
              onChanged: onChanged,
              itemBuilder: (context, v) => Text(itemLabel(v)),
              popup: (context) {
                return SelectPopup<T>(
                  items: SelectItemList(
                    children: items.map((item) {
                      return SelectItemButton<T>(
                        value: item,
                        child: Text(itemLabel(item)),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              const Spacer(),
              Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          Slider(
            value: SliderValue.single(
              ((value - min) / (max - min)).clamp(0.0, 1.0),
            ),
            onChanged: (v) {
              onChanged(min + v.value * (max - min));
            },
          ),
        ],
      ),
    );
  }
}
