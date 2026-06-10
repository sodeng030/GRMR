import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../config/app_config.dart';
import '../models/app_colors.dart';
import '../models/post_item.dart';
import '../components/bottom_bar.dart';
import '../components/top_status_banner.dart';
import '../screens/location_selection_screen.dart';

import 'add_screen.dart';
import 'detail_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<String> _category = ['취미', '식사', '동행'];

  final Color tabHobbyColor = const Color(0xFFFFC943);
  final Color tabMealColor = const Color(0xFFFFAC4B);
  final Color tabCompanionColor = const Color(0xFFFF8E52);

  bool _hasActiveMeeting = false;
  String _activeAppointmentId = '';
  String _meetingTitle = '';
  int _minutesLeft = 0;
  int _distanceMeter = 0;
  int _arrivalCount = 0;
  int _movingCount = 0;
  int _readyCount = 0;
  int _awayCount = 0;

  bool _isStarted = false;

  String _cUid = '';
  String _a1Uid = '';
  String _a2Uid = '';
  String _a3Uid = '';

  double? _currentLat;
  double? _currentLng;
  double? _meetingLat;
  double? _meetingLng;

  List<PostItem> allPosts = [];
  bool isLoading = true;

  String _sortBy = 'time';
  bool _genderFirst = false;

  // 소켓
  IO.Socket? _socket;

  // GPS 갱신 타이머 (소켓 emit용, 15초)
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _initLocationAndFetch();
    _fetchActiveStatus(); // 초기 1회 HTTP 호출은 유지
  }

  // ───────────── 소켓 ─────────────

  void _connectSocket() {
    if (_socket != null) return; // 이미 연결된 경우 중복 방지

    _socket = IO.io(
      AppConfig.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      log('[Socket] 연결 완료: ${_socket!.id}');
      // 약속 방에 조인
      _socket!.emit('join_appointment', {
        'uid': AppConfig.currentUserUid,
        'appointmentId': _activeAppointmentId,
      });
      log('[Socket] join_appointment 전송: $_activeAppointmentId');

      // 연결 직후 GPS 위치를 즉시 한 번 emit
      _emitLocationUpdate();

      // 15초마다 GPS emit 시작
      _locationTimer?.cancel();
      _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _emitLocationUpdate();
      });
    });

    // 서버에서 status_updated 이벤트 수신
    _socket!.on('status_updated', (data) {
      if (!mounted) return;
      setState(() {
        _arrivalCount = data['arrivalCount'] ?? _arrivalCount;
        _movingCount  = data['movingCount']  ?? _movingCount;
        _readyCount   = data['readyCount']   ?? _readyCount;
        _awayCount    = data['awayCount']    ?? _awayCount;
        if (data['minutesLeft'] != null) {           // 추가
          _minutesLeft = data['minutesLeft'];         // 추가
        }
        if (data['currentDistance'] != null) {
          final double distKm = double.tryParse(data['currentDistance'].toString()) ?? 0;
          _distanceMeter = (distKm * 1000).round();
        }
      });
    });

    _socket!.onDisconnect((_) {
      log('[Socket] 연결 해제됨');
      _locationTimer?.cancel();
    });

    _socket!.onConnectError((err) {
      log('[Socket] 연결 에러: $err');
    });
  }

  void _disconnectSocket() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    log('[Socket] 소켓 해제 완료');
  }

  // GPS 위치를 소켓으로 emit
  Future<void> _emitLocationUpdate({String? action}) async {
    if (_socket == null || !(_socket!.connected)) return;
    if (_activeAppointmentId.isEmpty) return;

    await _refreshCurrentLocation();

    if (_currentLat == null || _currentLng == null) return;

    final payload = {
      'uid': AppConfig.currentUserUid,
      'appointmentId': _activeAppointmentId,
      'lat': _currentLat,
      'lng': _currentLng,
      if (action != null) 'action': action,
    };

    _socket!.emit('update_status', payload);
    log('[Socket 송신 - update_status]: $payload');
  }

  // ───────────── GPS ─────────────

  Future<void> _refreshCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        if (mounted) {
          setState(() {
            _currentLat = position.latitude;
            _currentLng = position.longitude;
          });
        }
      }
    } catch (e) {
      log('❌ GPS 위치를 가져오는데 실패했습니다: $e');
    }
  }

  Future<void> _initLocationAndFetch() async {
    await _refreshCurrentLocation();
    _fetchPosts();
    _fetchActiveStatus();
  }

  // ───────────── 배너 콜백 ─────────────

  // 배너에서 일정 시작 버튼 눌렀을 때 콜백
  void _onMeetingStarted() {
    setState(() => _isStarted = true);
    // 'start' action으로 소켓 emit → 서버에서 base_distance 저장
    _emitLocationUpdate(action: 'start');
  }

  // ───────────── HTTP ─────────────

  Future<void> _fetchPosts() async {
    setState(() => isLoading = true);
    try {
      String url =
          '${AppConfig.baseUrl}/api/posts?sortBy=$_sortBy&genderFirst=$_genderFirst';

      if (_sortBy == 'distance' && _currentLat != null && _currentLng != null) {
        url += '&lat=$_currentLat&lng=$_currentLng';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'uid': AppConfig.currentUserUid},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          allPosts = data.map((json) => PostItem.fromJson(json)).toList();
          isLoading = false;
        });
      } else {
        log('⚠️ [게시글 로드 실패] 상태 코드: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      log('💥 [네트워크 에러] 원인: $e');
      setState(() => isLoading = false);
    }
  }

  Color _getMyAvatarColor() {
    List<String> uids = [_cUid, _a1Uid, _a2Uid, _a3Uid];
    int myIndex = uids.indexOf(AppConfig.currentUserUid);
    if (myIndex == -1) return AppConfig.myAvatarColor;
    return AppColors.avatarColors[myIndex % AppColors.avatarColors.length];
  }

  Future<void> _fetchActiveStatus() async {
    if (AppConfig.currentUserUid.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/appointments/active'),
        headers: {'uid': AppConfig.currentUserUid},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final int minutesLeft = data['minutesLeft'] ?? 0;
        final bool hasMeeting =
            (data['hasActiveMeeting'] ?? false) && minutesLeft > 0;
        final String appointmentId =
            data['id']?.toString() ?? data['appointmentId']?.toString() ?? '';

        final bool appointmentChanged = appointmentId != _activeAppointmentId;

        setState(() {
          _hasActiveMeeting = hasMeeting;
          _activeAppointmentId = appointmentId;
          _meetingTitle = data['title'] ?? '약속 정보 없음';
          _minutesLeft = minutesLeft;
          _distanceMeter = data['distanceMeter'] ?? 0;
          _arrivalCount = data['arrivalCount'] ?? 0;
          _movingCount = data['movingCount'] ?? 0;
          _readyCount = data['readyCount'] ?? 0;
          _awayCount = data['awayCount'] ?? 0;
          _cUid = data['c_uid'] ?? '';
          _a1Uid = data['a1_uid'] ?? '';
          _a2Uid = data['a2_uid'] ?? '';
          _a3Uid = data['a3_uid'] ?? '';
          AppConfig.myAvatarColor = _getMyAvatarColor();

          if (data['lat'] != null) {
            _meetingLat = double.tryParse(data['lat'].toString());
          } else if (data['latitude'] != null) {
            _meetingLat = double.tryParse(data['latitude'].toString());
          }

          if (data['lng'] != null) {
            _meetingLng = double.tryParse(data['lng'].toString());
          } else if (data['longitude'] != null) {
            _meetingLng = double.tryParse(data['longitude'].toString());
          }

          if (!hasMeeting) {
            _isStarted = false;
          }
        });

        // 약속이 있고, appointmentId가 새로 생겼거나 바뀐 경우 소켓 연결/재연결
        if (hasMeeting && appointmentId.isNotEmpty) {
          if (appointmentChanged || _socket == null || !(_socket!.connected)) {
            _disconnectSocket();
            _connectSocket();
          }
        } else {
          // 약속이 없으면 소켓 해제
          _disconnectSocket();
        }
      }
    } catch (e) {
      log('배너 데이터 로딩 에러: $e');
    }
  }

  // 변경 후
  @override
  void dispose() {
    _disconnectSocket();
    super.dispose();
  }

  // ───────────── UI ─────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildTopBanner(),
            const SizedBox(height: 30),
            Expanded(
              child: Stack(
                children: [
                  Positioned(top: 0, left: 0, right: 0, child: _buildTabs()),
                  Positioned(
                    top: 65,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                      ),
                      child: Column(
                        children: [
                          _buildSubHeader(context),
                          Expanded(
                            child: isLoading
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : _buildListView(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildTopBanner() {
    return TopStatusBanner(
      hasMeeting: _hasActiveMeeting,
      appointmentId: _activeAppointmentId,
      title: _meetingTitle,
      minutesLeft: _minutesLeft,
      distanceMeter: _distanceMeter,
      arrivalCount: _arrivalCount,
      movingCount: _movingCount,
      readyCount: _readyCount,
      awayCount: _awayCount,
      targetLat: _meetingLat,
      targetLng: _meetingLng,
      myLat: _currentLat,
      myLng: _currentLng,
      isStarted: _isStarted,
      onMeetingStarted: _onMeetingStarted,
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        _buildTabItem(index: 0, title: '취미', bgColor: tabHobbyColor),
        _buildTabItem(index: 1, title: '식사', bgColor: tabMealColor),
        _buildTabItem(index: 2, title: '동행', bgColor: tabCompanionColor),
      ],
    );
  }

  Widget _buildTabItem({
    required int index,
    required String title,
    required Color bgColor,
  }) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(44),
          ),
          child: Stack(
            children: [
              if (!isSelected)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(44),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withAlpha(217),
                        Colors.white.withAlpha(0),
                      ],
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.textMain
                          : AppColors.textMain.withAlpha(102),
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddScreen(currentCategory: _category[_selectedIndex]),
                ),
              );
              if (result == true) {
                _fetchPosts();
              }
            },
            child: const Icon(Icons.add, size: 36, color: AppColors.textMain),
          ),
          const Spacer(),
          const SizedBox(width: 15),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.3),
                builder: (context) => FilterDialog(
                  initialSortBy: _sortBy,
                  initialGenderFirst: _genderFirst,
                  initialLat: _currentLat,
                  initialLng: _currentLng,
                  onFilterApplied: (String newSortBy, bool newGenderFirst,
                      double? newLat, double? newLng) {
                    setState(() {
                      _sortBy = newSortBy;
                      _genderFirst = newGenderFirst;
                      _currentLat = newLat;
                      _currentLng = newLng;
                    });
                    _fetchPosts();
                  },
                ),
              );
            },
            child:
                const Icon(Icons.tune, size: 32, color: AppColors.textMain),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    String currentCategory = _category[_selectedIndex];
    List<PostItem> filteredPosts =
        allPosts.where((post) => post.category == currentCategory).toList();

    if (filteredPosts.isEmpty) {
      return Center(
        child: Text(
          '등록된 글이 없어요.',
          style: TextStyle(
            color: AppColors.textMain.withAlpha(128),
            fontSize: 20,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      itemCount: filteredPosts.length,
      itemBuilder: (context, index) {
        final post = filteredPosts[index];
        return _buildListItem(post);
      },
    );
  }

  Widget _buildListItem(PostItem post) {
    String displayLocation = post.category == '동행'
        ? '${post.location} -> ${post.destination}'
        : post.destination;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DetailScreen(post: post)),
        ).then((_) => _fetchPosts());
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(23),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3F000000),
              blurRadius: 4,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  post.title,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  ' (${post.now_count}/${post.max_count})',
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${post.date} ${post.time}\n$displayLocation',
              style: const TextStyle(
                color: AppColors.textMain,
                fontSize: 18,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FilterDialog extends StatefulWidget {
  final String initialSortBy;
  final bool initialGenderFirst;
  final double? initialLat;
  final double? initialLng;
  final Function(String sortBy, bool genderFirst, double? lat, double? lng)
      onFilterApplied;

  const FilterDialog({
    super.key,
    required this.initialSortBy,
    required this.initialGenderFirst,
    this.initialLat,
    this.initialLng,
    required this.onFilterApplied,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late bool _isTimeSort;
  late bool _isDistanceSort;
  late bool _isGenderSort;
  double? _selectedLat;
  double? _selectedLng;

  @override
  void initState() {
    super.initState();
    _isTimeSort = widget.initialSortBy == 'time';
    _isDistanceSort = widget.initialSortBy == 'distance';
    _isGenderSort = widget.initialGenderFirst;
    _selectedLat = widget.initialLat;
    _selectedLng = widget.initialLng;
  }

  void _toggleTimeSort(bool val) {
    setState(() {
      _isTimeSort = val;
      if (val) _isDistanceSort = false;
    });
    _applyFilters();
  }

  Future<void> _toggleDistanceSort(bool val) async {
    if (val) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LocationSelectionScreen(),
        ),
      );

      if (result != null && result is Map<String, double>) {
        setState(() {
          _selectedLat = result['lat'];
          _selectedLng = result['lng'];
          _isDistanceSort = true;
          _isTimeSort = false;
        });
        _applyFilters();
      } else {
        setState(() {
          if (_selectedLat != null) {
            _isDistanceSort = true;
            _isTimeSort = false;
            _applyFilters();
          } else {
            _isDistanceSort = false;
          }
        });
      }
    } else {
      setState(() => _isDistanceSort = false);
      _applyFilters();
    }
  }

  void _toggleGenderSort(bool val) {
    setState(() => _isGenderSort = val);
    _applyFilters();
  }

  void _applyFilters() {
    String sortBy = '';
    if (_isTimeSort) {
      sortBy = 'time';
    } else if (_isDistanceSort) {
      sortBy = 'distance';
    }
    widget.onFilterApplied(sortBy, _isGenderSort, _selectedLat, _selectedLng);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 335,
        padding: const EdgeInsets.symmetric(horizontal: 37, vertical: 43),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(23),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('시간순', style: _titleStyle),
                _buildCustomSwitch(_isTimeSort, _toggleTimeSort),
              ],
            ),
            const SizedBox(height: 35),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('거리순', style: _titleStyle),
                    Text(
                      '기준 위치 설정하기',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontFamily: 'Paperlogy',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                _buildCustomSwitch(
                    _isDistanceSort, (val) => _toggleDistanceSort(val)),
              ],
            ),
            const SizedBox(height: 35),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('성별 우선', style: _titleStyle),
                _buildCustomSwitch(_isGenderSort, _toggleGenderSort),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const TextStyle _titleStyle = TextStyle(
    color: Color(0xFF331F07),
    fontSize: 36,
    fontFamily: 'Paperlogy',
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  Widget _buildCustomSwitch(bool value, Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 70,
        height: 35,
        decoration: BoxDecoration(
          color: value ? const Color(0xFFFFAC4B) : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(27),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              left: value ? 35 : 5,
              child: Container(
                width: 29,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFDD89),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x3F000000),
                        blurRadius: 3,
                        offset: Offset(0, 3))
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
