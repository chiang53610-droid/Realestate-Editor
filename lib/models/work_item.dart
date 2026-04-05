import 'dart:convert';

class WorkItem {
  final String id;
  final String title;
  final String date;
  final int videoCount;
  final bool usedRemoveFiller;
  final bool usedSubtitle;
  final bool usedBusinessCard;

  WorkItem({
    required this.id,
    required this.title,
    required this.date,
    required this.videoCount,
    required this.usedRemoveFiller,
    required this.usedSubtitle,
    required this.usedBusinessCard,
  });

  // 把物件轉成 JSON（方便存進小筆記本）
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date,
        'videoCount': videoCount,
        'usedRemoveFiller': usedRemoveFiller,
        'usedSubtitle': usedSubtitle,
        'usedBusinessCard': usedBusinessCard,
      };

  // 從 JSON 讀回物件
  factory WorkItem.fromJson(Map<String, dynamic> json) => WorkItem(
        id: json['id'],
        title: json['title'],
        date: json['date'],
        videoCount: json['videoCount'],
        usedRemoveFiller: json['usedRemoveFiller'],
        usedSubtitle: json['usedSubtitle'],
        usedBusinessCard: json['usedBusinessCard'],
      );

  // 把整個列表轉成字串存起來
  static String encodeList(List<WorkItem> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  // 把字串讀回列表
  static List<WorkItem> decodeList(String jsonString) =>
      (jsonDecode(jsonString) as List)
          .map((e) => WorkItem.fromJson(e))
          .toList();
}
