import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';

import '../config/app_config.dart';
import '../models/app_colors.dart';
import '../components/bottom_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final List<String> _userTags = ['ENTP', '운동', '수원 거주', '음악', '수다'];
  bool _isExpanded = false;

  bool _isLoading = true;
  String userName = '';
  String userGender = '';
  String userBirth = '';
  String userEmail = '';

  Color _profileBgColor = AppColors.primaryButton;

  final Color _tagBgColor = const Color(0xFFFFDF91);
  final Color _tagTextColor = const Color(0xFFFFC943);
  final Color _accentColor = const Color(0xFFEF9666);

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    if (AppConfig.currentUserUid.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/user/profile/${AppConfig.currentUserUid}'), 
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          userName = data['name'] ?? '정보 없음';
          userEmail = data['email'] ?? '정보 없음';
          userGender = data['gender'] ?? '정보 없음';
          userBirth = data['birth'] ?? '정보 없음';

          if (data['colorCode'] != null) {
            String hexColor = data['colorCode'].toString().replaceAll('#', '');
            if (hexColor.length == 6) {
              hexColor = 'FF$hexColor';
            }
            _profileBgColor = Color(int.parse(hexColor, radix: 16));
          }

          _isLoading = false;
        });
      } else {
        log('프로필 불러오기 실패: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      log('서버 통신 에러: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showAddTagDialog() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            '특징 추가',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: controller,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: '특징 입력 (예: ENTP)',
              hintStyle: TextStyle(color: Colors.black.withAlpha(100)),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _accentColor),
              ),
            ),
            cursorColor: _accentColor,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _userTags.add(controller.text.trim());
                  });
                  Navigator.pop(context);
                }
              },
              child: Text(
                '추가',
                style: TextStyle(color: _accentColor, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

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
                    const SizedBox(height: 40),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Wrap(
                        spacing: 15,
                        runSpacing: 15,
                        alignment: WrapAlignment.center,
                        children: [
                          ..._userTags.map((tag) => _buildTagItem(tag)),
                          GestureDetector(
                            onTap: _showAddTagDialog,
                            child: _buildAddTagButton(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 150),
                  ],
                ),
              ),
            ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: 0,
              right: 0,
              bottom: _isExpanded ? 0 : -350,
              height: 440,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(33),
                      topRight: Radius.circular(33),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFFCA44),
                        blurRadius: 50,
                        offset: Offset(0, -4),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        '본인 인증 정보',
                        style: TextStyle(
                          color: _accentColor,
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _isLoading
                                    ? const Center(child: CircularProgressIndicator())
                                    : Text.rich(
                                        TextSpan(
                                          style: const TextStyle(
                                            color: AppColors.textMain,
                                            fontSize: 28,
                                          ),
                                          children: [
                                            const TextSpan(
                                              text: '이름 \n',
                                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                                            ),
                                            TextSpan(
                                              text: ' $userName\n',
                                              style: const TextStyle(fontWeight: FontWeight.w400),
                                            ),
                                            const TextSpan(
                                              text: '성별 \n',
                                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                                            ),
                                            TextSpan(
                                              text: ' $userGender\n',
                                              style: const TextStyle(fontWeight: FontWeight.w400),
                                            ),
                                            const TextSpan(
                                              text: '생년월일 \n',
                                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                                            ),
                                            TextSpan(
                                              text: '$userBirth\n',
                                              style: const TextStyle(fontWeight: FontWeight.w400),
                                            ),
                                            const TextSpan(
                                              text: '이메일 \n',
                                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                                            ),
                                            TextSpan(
                                              text: '$userEmail\n',
                                              style: const TextStyle(fontWeight: FontWeight.w400),
                                            ),
                                          ],
                                        ),
                                      ),
                                const SizedBox(height: 5),
                                const Text(
                                  '본인인증 정보는 상대에게 표시되지 않습니다',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 30),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildButton('재인증', _accentColor),
                                    const SizedBox(width: 25),
                                    _buildButton('탈퇴하기', _accentColor),
                                  ],
                                ),
                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(),
    );
  }

  Widget _buildTagItem(String text) {
    return Container(
      width: 87,
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

  Widget _buildAddTagButton() {
    return Container(
      width: 87,
      height: 42,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: _tagBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        '+',
        style: TextStyle(
          color: _tagTextColor,
          fontSize: 40,
          fontWeight: FontWeight.w400,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _buildButton(String text, Color color) {
    return Container(
      width: 146,
      height: 56,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 36,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
