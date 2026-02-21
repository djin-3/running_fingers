/// 1回のプレイ記録
class RecordData {
  final double value; // タイムアタック: 秒数 / タップチャレンジ: タップ数
  final DateTime date;
  final bool hadFalseStart;
  final bool usedTicket;
  final int fingerMode; // 1 or 2

  const RecordData({
    required this.value,
    required this.date,
    required this.hadFalseStart,
    required this.usedTicket,
    required this.fingerMode,
  });

  Map<String, dynamic> toJson() => {
        'value': value,
        'date': date.toIso8601String(),
        'hadFalseStart': hadFalseStart,
        'usedTicket': usedTicket,
        'fingerMode': fingerMode,
      };

  factory RecordData.fromJson(Map<String, dynamic> json) => RecordData(
        value: (json['value'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        hadFalseStart: json['hadFalseStart'] as bool,
        usedTicket: json['usedTicket'] as bool,
        fingerMode: json['fingerMode'] as int,
      );
}
