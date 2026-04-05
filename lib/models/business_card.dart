import 'dart:convert';

/// 名片片尾的資料模型
class BusinessCard {
  final String name;       // 姓名
  final String title;      // 職稱，例：資深經理
  final String company;    // 公司名稱
  final String phone;      // 電話
  final String email;      // Email（可選）
  final String line;       // LINE ID（可選）
  final int styleIndex;    // 名片樣式編號

  const BusinessCard({
    this.name = '',
    this.title = '',
    this.company = '',
    this.phone = '',
    this.email = '',
    this.line = '',
    this.styleIndex = 0,
  });

  bool get isEmpty => name.isEmpty && company.isEmpty && phone.isEmpty;

  BusinessCard copyWith({
    String? name,
    String? title,
    String? company,
    String? phone,
    String? email,
    String? line,
    int? styleIndex,
  }) {
    return BusinessCard(
      name: name ?? this.name,
      title: title ?? this.title,
      company: company ?? this.company,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      line: line ?? this.line,
      styleIndex: styleIndex ?? this.styleIndex,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'title': title,
        'company': company,
        'phone': phone,
        'email': email,
        'line': line,
        'styleIndex': styleIndex,
      };

  factory BusinessCard.fromJson(Map<String, dynamic> json) => BusinessCard(
        name: json['name'] ?? '',
        title: json['title'] ?? '',
        company: json['company'] ?? '',
        phone: json['phone'] ?? '',
        email: json['email'] ?? '',
        line: json['line'] ?? '',
        styleIndex: json['styleIndex'] ?? 0,
      );

  String encode() => jsonEncode(toJson());

  static BusinessCard decode(String jsonString) =>
      BusinessCard.fromJson(jsonDecode(jsonString));
}
