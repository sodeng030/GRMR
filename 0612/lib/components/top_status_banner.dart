import 'package:flutter/material.dart';
import 'dart:math' as math;

class TopStatusBanner extends StatelessWidget {
  final bool hasMeeting;
  final String title;
  final int minutesLeft;
  final int distanceMeter;
  final int arrivalCount;
  final int movingCount;
  final int readyCount;
  final int awayCount;
  final String appointmentId;

  final double? targetLat;
  final double? targetLng;
  final double? myLat;
  final double? myLng;

  final bool isStarted;
  final VoidCallback onMeetingStarted;

  const TopStatusBanner({
    super.key,
    required this.hasMeeting,
    this.title = '',
    this.minutesLeft = 0,
    this.distanceMeter = 0,
    this.arrivalCount = 0,
    this.movingCount = 0,
    this.readyCount = 0,
    this.awayCount = 0,
    this.appointmentId = '',
    this.targetLat,
    this.targetLng,
    this.myLat,
    this.myLng,
    required this.isStarted,
    required this.onMeetingStarted,
  });

  int _calculateDistanceInMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000;
    double dLat = _degToRad(lat2 - lat1);
    double dLng = _degToRad(lng2 - lng1);
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return (earthRadius * c).round();
  }

  double _degToRad(double deg) => deg * (math.pi / 180);

  int _getDisplayDistance() {
    if (myLat != null &&
        myLng != null &&
        targetLat != null &&
        targetLng != null) {
      return _calculateDistanceInMeters(
        myLat!, myLng!, targetLat!, targetLng!,
      );
    }
    return distanceMeter;
  }

  String _getFormattedTime(int totalMinutes) {
    if (totalMinutes < 0) return '시간 초과';
    int days = totalMinutes ~/ (24 * 60);
    int hours = (totalMinutes % (24 * 60)) ~/ 60;
    int minutes = totalMinutes % 60;
    if (days > 0) return '$days일 $hours시간 $minutes분';
    if (hours > 0) return '$hours시간 $minutes분';
    return '$minutes분';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (hasMeeting && !isStarted) {
          _showStartDialog(context);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 27),
        width: double.infinity,
        height: 155,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E6),
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [
            BoxShadow(
                color: Color(0x3F000000), blurRadius: 4, offset: Offset(0, 5)),
          ],
        ),
        child: hasMeeting ? _buildActiveMeetingView() : _buildNoMeetingView(),
      ),
    );
  }

  void _showStartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFBF1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          '일정 시작',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          '현재 위치를 기준으로\n일정을 시작할까요?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onMeetingStarted();
            },
            child: const Text(
              '시작',
              style: TextStyle(
                color: Color(0xFFEF9666),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMeetingView() {
    int displayDistance = _getDisplayDistance();
    String distanceText = displayDistance >= 1000
        ? '${(displayDistance / 1000).toStringAsFixed(1)}km'
        : '${displayDistance}m';
    String timeText = _getFormattedTime(minutesLeft);

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(left: 24),
        child: SizedBox(
          width: double.infinity,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$title\n',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 28,
                    fontFamily: 'Paperlogy',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(
                  text: '\n',
                  style: TextStyle(fontSize: 5),
                ),
                TextSpan(
                  text: '약속까지 $timeText\n장소까지 $distanceText\n준비($readyCount)  이동($movingCount)  도착($arrivalCount)  이탈($awayCount)',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontFamily: 'Paperlogy',
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoMeetingView() {
    return const Center(
      child: Text(
        '아직 상대를\n만나지 못했어요...',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF331F07),
          fontSize: 20,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
      ),
    );
  }
}
