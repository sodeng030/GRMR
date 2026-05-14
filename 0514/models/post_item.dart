// ignore_for_file: non_constant_identifier_names

class PostItem {
  final int? id;
  final String category;
  final String title;
  final int now_count;
  final int max_count;
  final String date;
  final String time;
  final String location;
  final String destination;

  final String c_uid;
  final String? a1_uid;
  final String? a2_uid;
  final String? a3_uid;

  PostItem({
    this.id,
    required this.category,
    required this.title,
    required this.now_count,
    required this.max_count,
    required this.date,
    required this.time,
    required this.location,
    required this.destination,

    required this.c_uid,
    this.a1_uid,
    this.a2_uid,
    this.a3_uid,
  });

  factory PostItem.fromJson(Map<String, dynamic> json) {
    return PostItem(
      id: json['id'],
      category: json['category'] ?? '',
      title: json['title'] ?? '',
      now_count: json['now_count'] is int
          ? json['now_count']
          : int.tryParse(json['now_count'].toString()) ?? 1,
      max_count: json['max_count'] is int
          ? json['max_count']
          : int.tryParse(json['max_count'].toString()) ?? 1,
      date: json['date'] ?? '',
      time: json['time'] ?? '시간 미정',
      location: json['location'] ?? '',
      destination: json['destination'] ?? '',

      c_uid: json['c_uid'] ?? '',
      a1_uid: json['a1_uid'] ?? '',
      a2_uid: json['a2_uid'] ?? '',
      a3_uid: json['a3_uid'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'title': title,
      'now_count': now_count,
      'max_count': max_count,
      'date': date,
      'time': time,
      'location': location,
      'destination': destination,

      'c_uid': c_uid,
      'a1_uid': a1_uid ?? '',
      'a2_uid': a2_uid ?? '',
      'a3_uid': a3_uid ?? '',
    };
  }
}
