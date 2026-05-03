import 'package:flutter/material.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../providers/visualizer_settings_provider.dart';
import 'settings_input.dart';

void openVisualizerSettings(BuildContext context, WidgetRef ref) {
  openDrawer(
    context: context,
    position: OverlayPosition.bottom,
    builder: (drawerContext) => const _VisualizerSettingsContent(),
  );
}

class _VisualizerSettingsContent extends ConsumerWidget {
  const _VisualizerSettingsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 600,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const Text('Visualizer Settings').h1(),
            const Gap(16),
            const Divider(),
            const Gap(16),
            Expanded(
              child: material.DefaultTabController(
                length: 4,
                child: Column(
                  children: [
                    material.TabBar(
                      tabs: [
                        material.Tab(child: Text('Bars')),
                        material.Tab(child: Text('Physics')),
                        material.Tab(child: Text('Frequency')),
                        material.Tab(child: Text('Style')),
                      ],
                    ),
                    const Gap(16),
                    Expanded(
                      child: material.TabBarView(
                        children: [
                          _BarsSettings(ref: ref),
                          _PhysicsSettings(ref: ref),
                          _FrequencySettings(ref: ref),
                          _StyleSettings(ref: ref),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarsSettings extends StatelessWidget {
  final WidgetRef ref;

  const _BarsSettings({required this.ref});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SettingsInput(
          label: "Bar Count",
          min: 1,
          max: 256,
          step: 1,
          selector: (s) => s.barCount.toDouble(),
          onUpdate: (n, val) {
            final settings = ref.read(visualizerSettingsProvider);
            final newBarCount = val.toInt();
            final newSpacing = settings.totalWidth / newBarCount;
            n.patch(barCount: newBarCount, spacing: newSpacing);
          },
        ),
        const Gap(16),
        SettingsInput(
          label: "Bar Width",
          min: 1,
          max: 20,
          selector: (s) => s.barWidth,
          onUpdate: (n, val) => n.patch(barWidth: val),
        ),
        const Gap(16),
        SettingsInput(
          label: "Total Width",
          min: 1,
          max: 2560,
          selector: (s) => s.totalWidth,
          onUpdate: (n, val) {
            final settings = ref.read(visualizerSettingsProvider);
            final newTotalWidth = val;
            final newSpacing = newTotalWidth / settings.barCount;
            n.patch(totalWidth: newTotalWidth, spacing: newSpacing);
          },
        ),
        const Gap(16),
        SettingsInput(
          label: "Spacing",
          min: 0,
          max: 50,
          selector: (s) => s.spacing,
          onUpdate: (n, val) {
            final settings = ref.read(visualizerSettingsProvider);
            final newSpacing = val;
            final newTotalWidth = newSpacing * settings.barCount;
            n.patch(spacing: newSpacing, totalWidth: newTotalWidth);
          },
        ),
        const Gap(16),
        SettingsInput(
          label: "Corner Radius",
          min: 0,
          max: 20,
          selector: (s) => s.cornerRadius,
          onUpdate: (n, val) => n.patch(cornerRadius: val),
        ),
        const Gap(16),
        SettingsInput(
          label: "Positive Height Scale",
          min: 0.1,
          max: 3.0,
          selector: (s) => s.positiveHeightScale,
          onUpdate: (n, val) => n.patch(positiveHeightScale: val),
        ),
        const Gap(16),
        SettingsInput(
          label: "Negative Height Scale",
          min: 0.0,
          max: 3.0,
          selector: (s) => s.negativeHeightScale,
          onUpdate: (n, val) => n.patch(negativeHeightScale: val),
        ),
      ],
    );
  }
}

class _PhysicsSettings extends StatelessWidget {
  final WidgetRef ref;

  const _PhysicsSettings({required this.ref});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SettingsInput(
          label: "Attack",
          min: 0.01,
          max: 1.0,
          selector: (s) => s.attack,
          onUpdate: (n, val) => n.patch(attack: val),
          step: 0.01,
        ),
        const Gap(16),
        SettingsInput(
          label: "Decay",
          min: 0.01,
          max: 1.0,
          selector: (s) => s.decay,
          onUpdate: (n, val) => n.patch(decay: val),
          step: 0.01,
        ),
        const Gap(16),
        SettingsInput(
          label: "Contrast",
          min: 0.1,
          max: 5.0,
          selector: (s) => s.contrast,
          onUpdate: (n, val) => n.patch(contrast: val),
          step: 0.01,
        ),
        const Gap(16),
        SettingsInput(
          label: "Bar Height Multiplier",
          min: 0.1,
          max: 5.0,
          selector: (s) => s.barHeightMultiplier,
          onUpdate: (n, val) => n.patch(barHeightMultiplier: val),
          step: 0.1,
        ),
        const Gap(16),
        SettingsInput(
          label: "Soft Ceiling Threshold",
          min: 0.0,
          max: 1.0,
          step: 0.1,
          selector: (s) => s.softCeilingThreshold,
          onUpdate: (n, val) => n.patch(softCeilingThreshold: val),
        ),
        const Gap(16),
        SettingsInput(
          label: "Soft Ceiling Strength",
          min: 0.1,
          step: 0.1,
          max: 10.0,
          selector: (s) => s.softCeilingStrength,
          onUpdate: (n, val) => n.patch(softCeilingStrength: val),
        ),
        const Gap(16),
        SettingsInput(
          label: "Reference FPS",
          min: 30,
          max: 120,
          step: 1,
          selector: (s) => s.referenceFps.toDouble(),
          onUpdate: (n, val) => n.patch(referenceFps: val.toInt()),
        ),
      ],
    );
  }
}

class _FrequencySettings extends StatelessWidget {
  final WidgetRef ref;

  const _FrequencySettings({required this.ref});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SettingsInput(
          label: "Min Frequency (Hz)",
          min: 20,
          max: 500,
          step: 1,
          selector: (s) => s.minFreq.toDouble(),
          onUpdate: (n, val) => n.patch(minFreq: val.toInt()),
        ),
        const Gap(16),
        SettingsInput(
          label: "Max Frequency (Hz)",
          min: 2000,
          max: 22000,
          step: 100,
          selector: (s) => s.maxFreq.toDouble(),
          onUpdate: (n, val) => n.patch(maxFreq: val.toInt()),
        ),
      ],
    );
  }
}

class _StyleSettings extends StatelessWidget {
  final WidgetRef ref;

  const _StyleSettings({required this.ref});

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(visualizerSettingsProvider);

    return ListView(
      children: [
        _ColorSettingRow(
          label: "Background Color",
          color: settings.backgroundColor,
          onChanged: (color) => ref
              .read(visualizerSettingsProvider.notifier)
              .patch(backgroundColor: color),
        ),
        const Gap(16),
        _ColorSettingRow(
          label: "Positive Color",
          color: settings.positiveColor,
          onChanged: (color) => ref
              .read(visualizerSettingsProvider.notifier)
              .patch(positiveColor: color),
        ),
        const Gap(16),
        _ColorSettingRow(
          label: "Negative Color",
          color: settings.negativeColor,
          onChanged: (color) => ref
              .read(visualizerSettingsProvider.notifier)
              .patch(negativeColor: color),
        ),
        const Gap(16),
        SettingsInput(
          label: "Y Offset",
          min: -500,
          max: 500,
          selector: (s) => s.yOffset,
          onUpdate: (n, val) => n.patch(yOffset: val),
        ),
      ],
    );
  }
}

class _ColorSettingRow extends StatelessWidget {
  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;

  const _ColorSettingRow({
    required this.label,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label),
        const Spacer(),
        GestureDetector(
          onTap: () => _showColorPicker(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.gray),
            ),
          ),
        ),
      ],
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select $label'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ColorButton(color: Colors.red, onChanged: onChanged),
              _ColorButton(color: Colors.orange, onChanged: onChanged),
              _ColorButton(color: Colors.yellow, onChanged: onChanged),
              _ColorButton(color: Colors.green, onChanged: onChanged),
              _ColorButton(color: Colors.blue, onChanged: onChanged),
              _ColorButton(color: Colors.purple, onChanged: onChanged),
              _ColorButton(color: Colors.white, onChanged: onChanged),
              _ColorButton(color: Colors.black, onChanged: onChanged),
              _ColorButton(
                color: const Color(0xFF00E5FF),
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onChanged;

  const _ColorButton({required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: GestureDetector(
        onTap: () {
          onChanged(color);
          Navigator.of(context).pop();
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.gray),
          ),
        ),
      ),
    );
  }
}
