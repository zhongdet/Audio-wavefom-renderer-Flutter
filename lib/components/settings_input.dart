import '../providers/visualizer_settings_provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/visualizer_settings.dart';

class SettingsInput extends ConsumerStatefulWidget {
  final String label;
  // final double value;
  // final Function(double)? onChange;
  final double Function(VisualizerSettings) selector;
  final void Function(VisualizerSettingsNotifier, double) onUpdate;
  // final VoidCallback? onReset;
  final double min;
  final double max;
  final num step;
  final double? unit;

  const SettingsInput({
    super.key,
    required this.label,
    required this.selector,
    required this.onUpdate,
    required this.min,
    required this.max,
    this.step = 1,
    this.unit,
  });

  @override
  ConsumerState<SettingsInput> createState() => _SettingsInputState();
}

class _SettingsInputState extends ConsumerState<SettingsInput> {
  late SliderValue sliderValue;
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    final initV = widget.selector(ref.read(visualizerSettingsProvider));
    sliderValue = SliderValue.single(initV);
    controller = TextEditingController(text: initV.toString());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _handleUpdate(double newValue) {
    final newV = newValue.clamp(widget.min, widget.max);
    setState(() {
      sliderValue = SliderValue.single(newV);
      controller.text = newV.toString();
    });
    final notifier = ref.read(visualizerSettingsProvider.notifier);
    widget.onUpdate(notifier, newV);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(visualizerSettingsProvider, (prev, next) {
      final nextV = widget.selector(next);
      if (nextV != sliderValue.value) {
        setState(() {
          sliderValue = SliderValue.single(nextV);
          controller.text = nextV.toString();
        });
      }
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(widget.label),
            SizedBox(
              width: 160,
              child: TextField(
                controller: controller,
                textAlign: TextAlign.center,
                onChanged: (v) {
                  final newV = double.tryParse(v);
                  if (newV != null) _handleUpdate(newV);
                },
                features: [
                  InputFeature.decrementButton(
                    position: InputFeaturePosition.leading,
                  ),
                  InputFeature.incrementButton(),
                ],
                submitFormatters: [TextInputFormatters.mathExpression()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          divisions: (widget.max - widget.min) ~/ (widget.step),
          max: widget.max,
          min: widget.min,
          value: sliderValue,
          onChanged: (v) => _handleUpdate(v.value),
        ),
      ],
    );
  }
}
