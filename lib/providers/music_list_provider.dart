import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/music_items.dart';

class MusicListState {
  final List<MusicItem> items;
  final String? selectedId;

  const MusicListState({this.items = const [], this.selectedId});

  MusicListState copyWith({List<MusicItem>? items, String? selectedId}) {
    return MusicListState(
      items: items ?? this.items,
      selectedId: selectedId ?? this.selectedId,
    );
  }
}

class MusicListNotifier extends Notifier<MusicListState> {
  @override
  MusicListState build() {
    return const MusicListState();
  }

  void addItem(MusicItem item) {
    final existing = state.items.indexWhere((i) => i.id == item.id);
    if (existing >= 0) {
      final updated = List<MusicItem>.from(state.items);
      updated[existing] = item;
      state = state.copyWith(items: updated, selectedId: item.id);
    } else {
      state = state.copyWith(
        items: [...state.items, item],
        selectedId: item.id,
      );
    }
  }

  void selectItem(String id) {
    state = state.copyWith(selectedId: id);
  }

  void removeItem(String id) {
    state = state.copyWith(
      items: state.items.where((i) => i.id != id).toList(),
      selectedId: state.selectedId == id ? null : state.selectedId,
    );
  }

  void clear() {
    state = const MusicListState();
  }
}

final musicListProvider = NotifierProvider<MusicListNotifier, MusicListState>(
  MusicListNotifier.new,
);
