class Dream {
  String content;
  bool isLucid;
  int vividness;

  Dream({
    required this.content,
    this.isLucid = false,
    this.vividness = 3, // default vividness value
  });

  Map<String, dynamic> toJson() => {
    'content': content,
    'isLucid': isLucid,
    'vividness': vividness,
  };

  factory Dream.fromJson(Map<String, dynamic> json) => Dream(
    content: json['content'],
    isLucid: json['isLucid'] ?? false,
    vividness: json['vividness'] ?? 3,
  );
}

class DreamEntry {
  final String id;
  final DateTime date;
  List<Dream> dreams;

  DreamEntry({
    required this.id,
    required this.date,
    required this.dreams,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'dreams': dreams.map((dream) => dream.toJson()).toList(),
  };

  factory DreamEntry.fromJson(Map<String, dynamic> json) => DreamEntry(
    id: json['id'],
    date: DateTime.parse(json['date']),
    dreams: (json['dreams'] as List<dynamic>?)
            ?.map((dream) => Dream.fromJson(dream as Map<String, dynamic>))
            .toList() ??
        [],
  );
}
