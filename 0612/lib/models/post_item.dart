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

  final double? lat; 
  final double? lng;

  final String gender_filter;

  final String c_uid;
  final String? a1_uid;
  final String? a2_uid;
  final String? a3_uid;

  final String state;

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

    this.lat,
    this.lng,

    this.gender_filter = 'all',

    required this.c_uid,
    this.a1_uid,
    this.a2_uid,
    this.a3_uid,
    this.state = 'active',
  });

  static String _trimSeconds(String time) {
    if (time.length >= 5 && time[2] == ':') {
      return time.substring(0, 5);
    }
    return time;
  }

  factory PostItem.fromJson(Map<String, dynamic> json) {
    final rawTitle = json['title'];
    final String extractedTitle = (rawTitle is Map) 
        ? (rawTitle['title']?.toString() ?? '제목 없음') 
        : (rawTitle?.toString() ?? '제목 없음');
    
    final participants = json['participants'] as Map<String, dynamic>?;

    return PostItem(
      id: json['id'],
      category: json['category'] ?? '',
      title: extractedTitle,
      now_count: json['now_count'] is int
          ? json['now_count']
          : int.tryParse(json['now_count'].toString()) ?? 1,
      max_count: json['max_count'] is int
          ? json['max_count']
          : int.tryParse(json['max_count'].toString()) ?? 1,
      date: json['target_date'] ?? json['date'] ?? '',
      time: _trimSeconds(json['target_time'] ?? json['time'] ?? '시간 미정'),
      location: json['location'] ?? '',
      destination: json['destination'] ?? '',

      lat: json['lat'] != null ? double.tryParse(json['lat'].toString()) : json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      lng: json['lng'] != null ? double.tryParse(json['lng'].toString()) : json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,

      gender_filter: json['gender_filter']?.toString() ?? 'all',
      
      c_uid: json['c_uid'] ?? '',
      a1_uid: participants?['a1_uid']?.toString() ?? json['a1_uid']?.toString() ?? '',
      a2_uid: participants?['a2_uid']?.toString() ?? json['a2_uid']?.toString() ?? '',
      a3_uid: participants?['a3_uid']?.toString() ?? json['a3_uid']?.toString() ?? '',

      state: json['state'] ?? 'active',
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

      'lat': lat, 
      'lng': lng,

      'gender_filter': gender_filter,

      'c_uid': c_uid,
      'a1_uid': a1_uid ?? '',
      'a2_uid': a2_uid ?? '',
      'a3_uid': a3_uid ?? '',
    };
  }
}
