import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'dart:async';

import '../config/app_config.dart';

// FSM 상태 정의
enum MeetingStatus { ready, moving, arrived, away }

class TopStatusBanner extends StatefulWidget {
  final bool hasMeeting;
  final String title;
  final int minutesLeft;
  final int distanceMeter;
  final int arrivalCount;
  final int departureCount;
  final int readyCount;
  final int awayCount;
  final String appointmentId;

  final double? targetLat;
  final double? targetLng;
  final double? myLat;
  final double? myLng;

  const TopStatusBanner({
    super.key,
    required this.hasMeeting,
    this.title = '',
    this.minutesLeft = 0,
    this.distanceMeter = 0,
    this.arrivalCount = 0,
    this.departureCount = 0,
    this.readyCount = 0,
    this.awayCount = 0,
    this.appointmentId = '',
    this.targetLat,
    this.targetLng,
    this.myLat,
    this.myLng,
  });

  @override
  State<TopStatusBanner> createState() => _TopStatusBannerState();
}

class _TopStatusBannerState extends State<TopStatusBanner> {
  // 상태
  MeetingStatus _myStatus = MeetingStatus.ready;
  bool _isStarted = false; // 일정 시작 버튼을 눌렀는지
  double? _baseDistance; // 일정 시작 시점의 거리 M

  // 상대방 카운트
  late int _currentArrivalCount;
  late int _currentDepartureCount;
  late int _currentReadyCount;
  late int _currentAwayCount;

  // 쿨타임
  DateTime? _lastTransitionTime;
  static const int _cooldownSeconds = 10;

  // 폴링 타이머
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _currentArrivalCount = widget.arrivalCount;
    _currentDepartureCount = widget.departureCount;
    _currentReadyCount = widget.readyCount;
    _currentAwayCount = widget.awayCount;
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ── 거리 계산 ──────────────────────────────────────
  int _calculateDistanceInMeters(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000;
    double dLat = _degToRad(lat2 - lat1);
    double dLng = _degToRad(lng2 - lng1);
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return (earthRadius * c).round();
  }

  double _degToRad(double deg) => deg * (math.pi / 180);

  int _getDisplayDistance() {
    if (widget.myLat != null && widget.myLng != null &&
        widget.targetLat != null && widget.targetLng != null) {
      return _calculateDistanceInMeters(
        widget.myLat!, widget.myLng!,
        widget.targetLat!, widget.targetLng!,
      );
    }
    return widget.distanceMeter;
  }

  // ── 시간 포맷 ──────────────────────────────────────
  String _getFormattedTime(int totalMinutes) {
    if (totalMinutes < 0) return '시간 초과';
    int days = totalMinutes ~/ (24 * 60);
    int hours = (totalMinutes % (24 * 60)) ~/ 60;
    int minutes = totalMinutes % 60;
    if (days > 0) return '$days일 $hours시간 $minutes분';
    if (hours > 0) return '$hours시간 $minutes분';
    return '$minutes분';
  }

  // ── 쿨타임 체크 ────────────────────────────────────
  bool _isCooldownActive() {
    if (_lastTransitionTime == null) return false;
    final elapsed = DateTime.now().difference(_lastTransitionTime!).inSeconds;
    return elapsed < _cooldownSeconds;
  }

  // ── 일정 시작 버튼 ─────────────────────────────────
  Future<void> _onStartMeeting() async {
    final currentDistance = _getDisplayDistance().toDouble();

    setState(() {
      _isStarted = true;
      _baseDistance = currentDistance;
      _lastTransitionTime = DateTime.now();

      if (currentDistance <= 600) {
        _myStatus = MeetingStatus.moving;
        log('🚀 거리 ${currentDistance}m: 준비 건너뛰고 즉시 이동 상태');
      } else {
        _myStatus = MeetingStatus.ready;
        log('🚀 거리 ${currentDistance}m: 준비 상태로 시작');
      }
    });

    // 시작 시 action: 'start' + 좌표 전송
    await _sendStatusToServer(_myStatus, isStart: true);

    // 30초 폴링 시작
    _startPolling();
  }

  // ── 폴링 시작 ──────────────────────────────────────
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _evaluateFSM();
      _fetchStatusFromServer();
    });
  }

  // ── FSM 평가 (매 5초마다 실행) ─────────────────────
  void _evaluateFSM() {
    if (!_isStarted || _baseDistance == null) return;
    if (_isCooldownActive()) {
      log('⏳ 쿨타임 중 - FSM 전이 스킵');
      return;
    }

    final currentDistance = _getDisplayDistance().toDouble();
    final M = _baseDistance!;
    MeetingStatus newStatus = _myStatus;

    switch (_myStatus) {
      case MeetingStatus.ready:
        // M*75% 이하 → 이동
        if (currentDistance <= M * 0.75) {
          newStatus = MeetingStatus.moving;
          log('🔄 준비 → 이동 (현재: ${currentDistance}m, 기준: ${M * 0.75}m)');
        }
        break;

      case MeetingStatus.moving:
        // 100m 이하 → 도착
        if (currentDistance <= 100) {
          newStatus = MeetingStatus.arrived;
          log('🔄 이동 → 도착 (현재: ${currentDistance}m)');
        }
        break;

      case MeetingStatus.arrived:
        // 300m 초과 → 자리비움
        if (currentDistance > 300) {
          newStatus = MeetingStatus.away;
          log('🔄 도착 → 자리비움 (현재: ${currentDistance}m)');
        }
        break;

      case MeetingStatus.away:
        // 600m 이하 → 이동 복귀
        if (currentDistance <= 600) {
          newStatus = MeetingStatus.moving;
          log('🔄 자리비움 → 이동 (현재: ${currentDistance}m)');
        }
        break;
    }

    if (newStatus != _myStatus) {
      setState(() {
        _myStatus = newStatus;
        _lastTransitionTime = DateTime.now();
      });
      _sendStatusToServer(newStatus);
    }
  }

  // ── 서버에 상태 전송 ───────────────────────────────
  Future<void> _sendStatusToServer(MeetingStatus status, {bool isStart = false}) async {
    String action;
    switch (status) {
      case MeetingStatus.ready:
        action = 'ready';
        break;
      case MeetingStatus.moving:
        action = 'moving';
        break;
      case MeetingStatus.arrived:
        action = 'arrival';
        break;
      case MeetingStatus.away:
        action = 'away';
        break;
    }

    try {
      final body = {
        'uid': AppConfig.currentUserUid,
        'appointmentId': widget.appointmentId,
        'lat': widget.myLat,
        'lng': widget.myLng,
        if (isStart) 'action': 'start' else 'action': action,
      };

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/appointments/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _currentArrivalCount = data['arrivalCount'] ?? _currentArrivalCount;
          _currentDepartureCount = data['departureCount'] ?? _currentDepartureCount;
          _currentReadyCount = data['readyCount'] ?? _currentReadyCount;
          _currentAwayCount = data['awayCount'] ?? _currentAwayCount;
        });
        log('✅ 상태 전송 성공: ${isStart ? 'start' : action}');
      }
    } catch (e) {
      log('❌ 상태 전송 실패: $e');
    }
  }

  // ── 서버에서 상태 폴링 ─────────────────────────────
  Future<void> _fetchStatusFromServer() async {
    if (widget.appointmentId.isEmpty) return;

    try {
      final body = {
        'uid': AppConfig.currentUserUid,
        'appointmentId': widget.appointmentId,
        'lat': widget.myLat,
        'lng': widget.myLng,
      };

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/appointments/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _currentArrivalCount = data['arrivalCount'] ?? _currentArrivalCount;
          _currentDepartureCount = data['departureCount'] ?? _currentDepartureCount;
          _currentReadyCount = data['readyCount'] ?? _currentReadyCount;
          _currentAwayCount = data['awayCount'] ?? _currentAwayCount;
        });
      }
    } catch (e) {
      log('❌ 상태 폴링 실패: $e');
    }
  }

  // ── 상태 한글 텍스트 ───────────────────────────────
  String _getStatusText() {
    switch (_myStatus) {
      case MeetingStatus.ready:
        return '준비';
      case MeetingStatus.moving:
        return '이동';     // 👈 이동 중 → 이동
      case MeetingStatus.arrived:
        return '도착';
      case MeetingStatus.away:
        return '이탈';     // 👈 자리비움 → 이탈
    }
  }

  @override
  void didUpdateWidget(covariant TopStatusBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.arrivalCount != widget.arrivalCount ||
        oldWidget.departureCount != widget.departureCount ||
        oldWidget.readyCount != widget.readyCount ||
        oldWidget.awayCount != widget.awayCount) {
      setState(() {
        _currentArrivalCount = widget.arrivalCount;
        _currentDepartureCount = widget.departureCount;
        _currentReadyCount = widget.readyCount;
        _currentAwayCount = widget.awayCount;
      });
    }
  }

  // ── 빌드 ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.hasMeeting && !_isStarted) {
          _showStartDialog();  // 시작 전에만 탭으로 다이얼로그
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
            BoxShadow(color: Color(0x3F000000), blurRadius: 4, offset: Offset(0, 5)),
          ],
        ),
        child: widget.hasMeeting
            ? _buildActiveMeetingView()
            : _buildNoMeetingView(),
      ),
    );
  }

  // ── 일정 시작 다이얼로그 ───────────────────────────
  void _showStartDialog() {
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
              _onStartMeeting();
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

  // ── 활성 약속 뷰 ───────────────────────────────────
  Widget _buildActiveMeetingView() {
    int displayDistance = _getDisplayDistance();
    String distanceText = displayDistance >= 1000
        ? '${(displayDistance / 1000).toStringAsFixed(1)}km'
        : '${displayDistance}m';
    String timeText = _getFormattedTime(widget.minutesLeft);

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(left: 24),
        child: SizedBox(
          width: double.infinity,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${widget.title}\n',
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
                  text: _isStarted
                      ? '약속까지 $timeText\n장소까지 $distanceText\n내 상태 : ${_getStatusText()}\n도착($_currentArrivalCount)  이동($_currentDepartureCount)  준비($_currentReadyCount)  이탈($_currentAwayCount)'
                      : '약속까지 $timeText\n장소까지 $distanceText\n도착($_currentArrivalCount)  이동($_currentDepartureCount)  준비($_currentReadyCount)  이탈($_currentAwayCount)',
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

  // ── 약속 없음 뷰 ───────────────────────────────────
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