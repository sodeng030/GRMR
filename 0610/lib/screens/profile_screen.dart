import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';

import '../config/app_config.dart';
import '../models/app_colors.dart';
import '../components/bottom_bar.dart';
import '../login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<String> _userTags = [];
  bool _isExpanded = false;

  bool _isLoading = true;
  String userName = '';
  String userGender = '';
  String userBirth = '';
  String userEmail = '';

  String userState = '준비';
  String? appointmentId;

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
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/user/profile/${AppConfig.currentUserUid}'), 
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        
        if (mounted) {
          setState(() {
            userName = data['name'] ?? '정보 없음';
            userEmail = data['email'] ?? '정보 없음';
            userGender = data['gender'] ?? '정보 없음';
            AppConfig.currentUserGender = data['gender'] ?? 'female';
            userBirth = data['birth'] ?? '정보 없음';

            userState = data['state'] ?? '준비';
            appointmentId = data['appointmentId'];

            if (data['tags'] != null) {
              _userTags = List<String>.from(data['tags']);
            }

            // 백엔드에서 계산해서 내려준 색상이 있으면 적용, 없거나 null이면 기본 노란색
            if (AppConfig.myAvatarColor != const Color(0xFFF6796D) || 
                AppConfig.currentUserUid.isNotEmpty) {
              _profileBgColor = AppConfig.myAvatarColor;
            } else if (data['colorCode'] != null && data['colorCode'].toString().isNotEmpty) {
              String hexColor = data['colorCode'].toString().replaceAll('#', '').replaceAll('0x', '').replaceAll('0X', '');
              if (hexColor.length == 6) hexColor = 'FF$hexColor';
              _profileBgColor = Color(int.parse(hexColor, radix: 16));
            } else {
              _profileBgColor = AppColors.primaryButton;
            }

            _isLoading = false;
          });
        }
      } else {
        log('프로필 불러오기 실패: ${response.statusCode}');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      log('서버 통신 에러: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 재인증 버튼 클릭 시 데이터 새로고침
  Future<void> _handleReauth() async {
    await _fetchUserProfile();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('본인인증 정보가 최신 상태로 업데이트되었습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // 백엔드에 태그 목록 업데이트 요청하기
  Future<bool> _updateTagsOnServer(List<String> newTags) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/api/user/profile/tags'),
        headers: {
          'Content-Type': 'application/json',
          'uid': AppConfig.currentUserUid
        },
        body: json.encode({'tags': newTags}), 
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        log('태그 업데이트 실패: ${response.statusCode}');
        log('에러 상세 내용: ${response.body}');
        return false;
      }
    } catch (e) {
      log('태그 서버 통신 에러: $e');
      return false;
    }
  }

  // 태그 추가 다이얼로그
  void _showAddTagDialog() {
    TextEditingController controller = TextEditingController();
    bool isUpdating = false; 

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) {
        return StatefulBuilder( 
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text(
                '특징 추가',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: isUpdating
                  ? const SizedBox(
                      height: 50,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : TextField(
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
                  onPressed: isUpdating ? null : () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.black)),
                ),
                TextButton(
                  onPressed: isUpdating
                      ? null
                      : () async {
                          String newTag = controller.text.trim();
                          if (newTag.isNotEmpty) {
                            setDialogState(() => isUpdating = true);

                            List<String> updatedTags = List.from(_userTags)..add(newTag);
                            bool success = await _updateTagsOnServer(updatedTags);

                            if (success) {
                              if (mounted) {
                                setState(() {
                                  _userTags = updatedTags;
                                });
                              }
                              if (context.mounted) Navigator.pop(context);
                            } else {
                              setDialogState(() => isUpdating = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('태그 추가에 실패했습니다.')),
                                );
                              }
                            }
                          }
                        },
                  child: Text(
                    '추가',
                    style: TextStyle(
                      color: isUpdating ? Colors.grey : _accentColor, 
                      fontWeight: FontWeight.w700
                    ),
                  ),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // 태그 삭제 다이얼로그
  void _showDeleteTagDialog(String tag) {
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text(
                '특징 삭제',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: isUpdating
                  ? const SizedBox(
                      height: 50,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Text("'$tag' 특징을 삭제하시겠습니까?"),
              actions: [
                TextButton(
                  onPressed: isUpdating ? null : () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.black)),
                ),
                TextButton(
                  onPressed: isUpdating
                      ? null
                      : () async {
                          setDialogState(() => isUpdating = true);

                          List<String> updatedTags = List.from(_userTags)..remove(tag);
                          bool success = await _updateTagsOnServer(updatedTags);

                          if (success) {
                            if (mounted) {
                              setState(() {
                                _userTags = updatedTags;
                              });
                            }
                            if (context.mounted) Navigator.pop(context);
                          } else {
                            setDialogState(() => isUpdating = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('태그 삭제에 실패했습니다.')),
                              );
                            }
                          }
                        },
                  child: Text(
                    '삭제',
                    style: TextStyle(
                      color: isUpdating ? Colors.grey : _accentColor, 
                      fontWeight: FontWeight.w700
                    ),
                  ),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // 회원 탈퇴 처리 다이얼로그 및 API 통신
  void _showDeleteAccountDialog() {
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text(
                '회원 탈퇴',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: isDeleting
                  ? const SizedBox(
                      height: 50,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const Text('정말 탈퇴하시겠습니까?\n모든 사용자 데이터가 영구적으로 삭제됩니다.'),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.black)),
                ),
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);

                          try {
                            final response = await http.delete(
                              Uri.parse('${AppConfig.baseUrl}/api/user/profile'),
                              headers: {'uid': AppConfig.currentUserUid},
                            );

                            if (response.statusCode == 200 || response.statusCode == 204) {
                              AppConfig.currentUserUid = '';
                              
                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                  (route) => false, 
                                );
                              }
                            } else {
                              log('회원 탈퇴 실패: ${response.statusCode}');
                              setDialogState(() => isDeleting = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('탈퇴 처리에 실패했습니다.')),
                                );
                              }
                            }
                          } catch (e) {
                            log('회원 탈퇴 서버 통신 에러: $e');
                            setDialogState(() => isDeleting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('서버 통신 중 에러가 발생했습니다.')),
                              );
                            }
                          }
                        },
                  child: Text(
                    '탈퇴',
                    style: TextStyle(
                      color: isDeleting ? Colors.grey : Colors.red,
                      fontWeight: FontWeight.w700
                    ),
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
                                              text: ' $userBirth\n',
                                              style: const TextStyle(fontWeight: FontWeight.w400),
                                            ),
                                            const TextSpan(
                                              text: '이메일 \n',
                                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                                            ),
                                            TextSpan(
                                              text: ' $userEmail\n',
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
                                    GestureDetector(
                                      onTap: _isLoading ? null : _handleReauth,
                                      child: _buildButton('재인증', _accentColor),
                                    ),
                                    const SizedBox(width: 25),
                                    GestureDetector(
                                      onTap: _showDeleteAccountDialog,
                                      child: _buildButton('탈퇴하기', _accentColor),
                                    ),
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
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildTagItem(String text) {
    return GestureDetector(
      onLongPress: () {
        _showDeleteTagDialog(text);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 42,
        decoration: ShapeDecoration(
          color: _tagBgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              text,
              style: TextStyle(
                color: _tagTextColor,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
