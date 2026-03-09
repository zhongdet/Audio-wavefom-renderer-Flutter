class MusicItem {
  final String title;
  final String id;
  final int size;
  final String duration;

  MusicItem({
    required this.title,
    required this.id,
    required this.size,
    required this.duration,
  });

  // toJson / fromJson for 儲存
  Map<String, dynamic> toJson() => {'title': title, 'id': id, 'size': size};
  factory MusicItem.fromJson(Map<String, dynamic> json) => MusicItem(
    title: json['title'],
    id: json['id'],
    size: json['size'],
    duration: json['duration'],
  );

  // copyWith for immutable 更新
  MusicItem copyWith({
    String? title,
    String? id,
    int? size,
    String? duration,
  }) => MusicItem(
    title: title ?? this.title,
    id: id ?? this.id,
    size: size ?? this.size,
    duration: duration ?? this.duration,
  );
}
