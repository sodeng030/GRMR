import 'package:flutter/material.dart';

class TopStatusBanner extends StatefulWidget {
  final bool hasMeeting;
  final String title;
  final int minutesLeft;
  final int distanceMeter;
  final int arrivalCount;
  final int departureCount;
  final int readyCount;

  const TopStatusBanner({
    super.key,
    required this.hasMeeting,
    this.title = '',
    this.minutesLeft = 0,
    this.distanceMeter = 0,
    this.arrivalCount = 0,
    this.departureCount = 0,
    this.readyCount = 0,
  });

  @override
  State<TopStatusBanner> createState() => _TopStatusBannerState();
}

class _TopStatusBannerState extends State<TopStatusBanner> {
  bool _isSelectionMode = false;
  String _myStatus = '준비'; // 기본 상태

  late int _currentArrivalCount;
  late int _currentDepartureCount;
  late int _currentReadyCount;

  @override
  void initState() {
    super.initState();
    _currentArrivalCount = widget.arrivalCount;
    _currentDepartureCount = widget.departureCount;
    _currentReadyCount = widget.readyCount;
  }

  // 상태 변경 및 인원수 증감 로직
  void _changeStatus(String tappedStatus) {
    String oldStatus = _myStatus;
    String nextStatus = tappedStatus;

    // 이미 선택한 상태를 다시 누르면 '준비' 상태로 복구
    if (oldStatus == tappedStatus) {
      nextStatus = '준비';
    }

    setState(() {
      // 1. 기존 상태 인원수 -1
      if (oldStatus == '준비') { _currentReadyCount--; }
      else if (oldStatus == '출발') { _currentDepartureCount--; }
      else if (oldStatus == '도착') { _currentArrivalCount--; }

      // 2. 변경될 상태 인원수 +1
      if (nextStatus == '준비') { _currentReadyCount++; }
      else if (nextStatus == '출발') { _currentDepartureCount++; }
      else if (nextStatus == '도착') { _currentArrivalCount++; }

      _myStatus = nextStatus;
      _isSelectionMode = false; // 선택 완료 후 창 닫기
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 바깥쪽(또는 배너의 빈 공간) 터치 시 선택창 열기/닫기 토글
      onTap: () {
        if (widget.hasMeeting) { // 약속이 있는 상태에서만 작동
          setState(() {
            _isSelectionMode = !_isSelectionMode;
          });
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
              color: Color(0x3F000000),
              blurRadius: 4,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 1. 기존 배너 내용
            Center(
              child: widget.hasMeeting ? _buildActiveMeetingView() : _buildNoMeetingView(),
            ),

            // 2. 터치 시 나타나는 출발/도착 선택 블럭 (보내주신 디자인 코드 적용)
            if (_isSelectionMode && widget.hasMeeting)
              Positioned.fill(
                child: _buildSelectionOverlay(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveMeetingView() {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 0),
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
                text: '약속까지 ${widget.minutesLeft}분 \n장소까지 ${widget.distanceMeter}m\n상대 상태 : 도착($_currentArrivalCount)  출발($_currentDepartureCount)  준비($_currentReadyCount)',
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
    );
  }

  Widget _buildNoMeetingView() {
    return const Text(
      '아직 상대를\n만나지 못했어요...',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color(0xFF331F07),
        fontSize: 20,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
    );
  }

  // 채연님이 작성하신 UI 코드 적용 및 기능 연결
  Widget _buildSelectionOverlay() {
    return Container(
      decoration: ShapeDecoration(
        color: const Color(0xFFFFF8E6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
      child: Row(
        children: [
          // 출발 버튼 영역
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _changeStatus('출발'),
              child: const Center(
                child: Text(
                  '출발',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 36,
                    fontFamily: 'Ria Sans',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          
          // 가운데 구분선
          Container(
            width: 1,
            height: 155,
            color: Colors.black,
          ),
          
          // 도착 버튼 영역
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _changeStatus('도착'),
              child: const Center(
                child: Text(
                  '도착',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 36,
                    fontFamily: 'Ria Sans',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}