import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';

import '../config/app_config.dart';
import '../models/app_colors.dart';
import '../components/bottom_bar.dart';

class RatingProfileScreen extends StatefulWidget {
  final String targetUid;
  final Color avatarColor;

  const RatingProfileScreen({
    super.key,
    required this.targetUid,
    required this.avatarColor,
  });

  @override
  State<RatingProfileScreen> createState() => _RatingProfileScreenState();
}

class _RatingProfileScreenState extends State<RatingProfileScreen> {
  bool _isLoading = true;
  double _rating = 4.5;
  List<String> _userTags = [];
  late Color _profileBgColor;

  final Color _tagBgColor = const Color(0xFFFFDF91);
  final Color _tagTextColor = const Color(0xFFFFC943);

  @override
  void initState() {
    super.initState();
    _profileBgColor = widget.avatarColor;
    _fetchParticipantProfile();
  }

  Future<void> _fetchParticipantProfile() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/user/profile/${widget.targetUid}'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        
        if (mounted) {
          setState(() {
            if (data['tags'] != null) {
              _userTags = List<String>.from(data['tags']);
            }
            if (data['rating'] != null) {
              _rating = (data['rating'] as num).toDouble();
            }
            if (data['colorCode'] != null && data['colorCode'].toString().isNotEmpty) {
              String hexColor = data['colorCode'].toString().replaceAll('#', '');
              if (hexColor.length == 6) hexColor = 'FF$hexColor';
              _profileBgColor = Color(int.parse(hexColor, radix: 16));
            }
            _isLoading = false;
          });
        }
      } else {
        log('상대방 프로필 불러오기 실패: ${response.statusCode}');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      log('서버 통신 에러: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 평점 남기기 다이얼로그
  void _showRatingDialog() {
    double tempRating = _rating;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text(
                '평점 남기기',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tempRating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.textMain),
                  ),
                  Slider(
                    value: tempRating,
                    min: 0.0,
                    max: 5.0,
                    divisions: 10,
                    activeColor: const Color(0xFF665641),
                    inactiveColor: Colors.grey.withAlpha(100),
                    onChanged: (value) {
                      setDialogState(() {
                        tempRating = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.black)),
                ),
                TextButton(
                  onPressed: () async {
                    // TODO: 백엔드에 평점 업데이트 API 연결 (예: PUT /api/user/profile/{uid}/rating)
                    // 지금은 화면에 바로 반영되는 형태만 구현
                    setState(() {
                      _rating = tempRating;
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('평점이 반영되었습니다! (서버 연동 필요)')),
                    );
                  },
                  child: const Text(
                    '확인',
                    style: TextStyle(color: Color(0xFFEF9666), fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    Container(
                      width: 218,
                      height: 218,
                      decoration: ShapeDecoration(
                        color: _profileBgColor,
                        shape: const OvalBorder(),
                      ),
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.person_fill,
                          size: 150,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    Text(
                      '평점 ${_rating.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: AppColors.textMain,
                        fontSize: 30,
                        fontFamily: 'Paperlogy',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 10),

                    GestureDetector(
                      onTap: _showRatingDialog,
                      child: const Icon(
                        Icons.edit_square,
                        size: 50,
                        color: Color(0xFF4A3E2D),
                      ),
                    ),
                    const SizedBox(height: 30),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: _userTags.isEmpty
                          ? const Text(
                              '등록된 특징이 없습니다.',
                              style: TextStyle(fontSize: 20, color: Colors.black54),
                            )
                          : Wrap(
                              spacing: 15,
                              runSpacing: 15,
                              alignment: WrapAlignment.center,
                              children: _userTags.map((tag) => _buildTagItem(tag)).toList(),
                            ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const CustomBottomNavBar(),
    );
  }

  Widget _buildTagItem(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 42,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: _tagBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: _tagTextColor,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
