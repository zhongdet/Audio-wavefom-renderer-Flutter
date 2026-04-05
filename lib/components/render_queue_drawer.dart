import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../providers/export_queue_provider.dart';

void openRenderQueueDrawer(BuildContext context, WidgetRef ref) {
  openDrawer(
    context: context,
    position: OverlayPosition.bottom,
    builder: (context) {
      return SizedBox(
        height: 500,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Render Queue'),
                  const Spacer(),
                  OutlineButton(
                    child: const Text('Clear Done'),
                    onPressed: () {
                      ref.read(exportQueueProvider.notifier).clearCompleted();
                    },
                  ),
                ],
              ),
              const Gap(16),
              const Divider(),
              const Gap(16),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final queueState = ref.watch(exportQueueProvider);

                    if (queueState.items.isEmpty) {
                      return const Center(
                        child: Text(
                          'Queue is empty.\nAdd items from the menu.',
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: queueState.items.length,
                      itemBuilder: (context, index) {
                        final item = queueState.items[index];
                        return _QueueItemTile(item: item, ref: ref);
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

class _QueueItemTile extends StatelessWidget {
  final ExportQueueItem item;
  final WidgetRef ref;

  const _QueueItemTile({required this.item, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statusIcon(item.status),
                const Gap(8),
                Expanded(
                  child: Text(
                    item.audioFileName,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _actionButton(item, ref),
              ],
            ),
            const Gap(4),
            Text(
              '${item.settings.resolution.width}x${item.settings.resolution.height} @ ${item.settings.fps.value}fps',
              style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
            ),
            const Gap(4),
            if (item.status == ExportStatus.rendering) ...[
              LinearProgressIndicator(value: item.progress),
              const Gap(2),
              Text(
                '${(item.progress * 100).toInt()}%',
                style: const TextStyle(fontSize: 11),
              ),
            ] else if (item.status == ExportStatus.completed) ...[
              Text(
                'Saved: ${item.outputPath ?? "unknown"}',
                style: const TextStyle(fontSize: 10, color: Colors.green),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ] else if (item.status == ExportStatus.failed) ...[
              Text(
                'Error: ${item.errorMessage ?? "unknown"}',
                style: const TextStyle(fontSize: 10, color: Colors.red),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(ExportStatus status) {
    switch (status) {
      case ExportStatus.queued:
        return const Icon(Icons.schedule, size: 18, color: Colors.orange);
      case ExportStatus.rendering:
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case ExportStatus.completed:
        return const Icon(Icons.check_circle, size: 18, color: Colors.green);
      case ExportStatus.failed:
        return const Icon(Icons.error, size: 18, color: Colors.red);
      case ExportStatus.cancelled:
        return const Icon(Icons.cancel, size: 18, color: Color(0xFF888888));
    }
  }

  Widget _actionButton(ExportQueueItem item, WidgetRef ref) {
    switch (item.status) {
      case ExportStatus.queued:
        return OutlineButton(
          child: const Text('Remove'),
          onPressed: () {
            ref.read(exportQueueProvider.notifier).removeFromQueue(item.id);
          },
        );
      case ExportStatus.rendering:
        return OutlineButton(
          child: const Text('Cancel'),
          onPressed: () {
            ref.read(exportQueueProvider.notifier).cancelItem(item.id);
          },
        );
      case ExportStatus.completed:
      case ExportStatus.failed:
      case ExportStatus.cancelled:
        return OutlineButton(
          child: const Text('Remove'),
          onPressed: () {
            ref.read(exportQueueProvider.notifier).removeFromQueue(item.id);
          },
        );
    }
  }
}
