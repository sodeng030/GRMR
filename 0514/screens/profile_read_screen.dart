import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';

import '../config/app_config.dart';
import '../models/app_colors.dart';
import '../components/bottom_bar.dart';

class ParticipantProfileScreen extends StatefulWidget {
  final String targetUid;
  final Color avatarColor;

  const ParticipantProfileScreen({
    super.key,
    required this.targetUid,
    required this.avatarColor,
  });

  @override
  State<ParticipantProfileScreen> createState() => _ParticipantProfileScreenState();
}

class _ParticipantProfileScreenState extends State<ParticipantProfileScreen> {
  bool _isLoading = true;
  double _rating = 4.5; // 기본 평점 -> 나중에 백엔드 데이터로 덮어씌움
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
                        fontSize: 34,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 40),

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
