import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';

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
  double _rating = 0.0;
  List<String> _userTags = [];
  late Color _profileBgColor;
  bool _alreadyRated = false;

  final Color _tagBgColor = const Color(0xFFFFDF91);
  final Color _tagTextColor = const Color(0xFFFFC943);

  @override
  void initState() {
    super.initState();
    _profileBgColor = widget.avatarColor;
    _fetchParticipantProfile();
    _checkAlreadyRated();
  }

  Future<void> _checkAlreadyRated() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'rated_${AppConfig.currentUserUid}_${widget.targetUid}';
    setState(() {
      _alreadyRated = prefs.getBool(key) ?? false;
    });
  }

  Future<void> _saveRatedFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'rated_${AppConfig.currentUserUid}_${widget.targetUid}';
    await prefs.setBool(key, true);
  }

  Future<void> _fetchParticipantProfile() async {
    final url = '${AppConfig.baseUrl}/api/user/profile/${widget.targetUid}';
    log('📡 [프로필 조회 요청] URL: $url');

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        log('✅ [프로필 조회 성공] 데이터: $data');
        
        if (mounted) {
          setState(() {
            if (data['tags'] != null) {
              _userTags = List<String>.from(data['tags']);
            }
            
            if (data['rating'] != null) {
              _rating = double.tryParse(data['rating'].toString()) ?? 0.0;
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
        log('⚠️ [프로필 조회 실패] 상태 코드: ${response.statusCode} | 원인: ${response.body}');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      log('💥 [프로필 조회 에러] 통신 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRatingDialog() {
    double tempRating = _rating;
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
                '평점 남기기',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: isUpdating
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator(color: Color(0xFFEF9666))),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tempRating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.textMain),
                        ),
                        Slider(
                          value: tempRating,
                          min: 0.0,
                          max: 5.0,
                          divisions: 50,
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
                  onPressed: isUpdating
                      ? null
                      : () async {
                          setDialogState(() => isUpdating = true);
                          
                          final updateUrl = '${AppConfig.baseUrl}/api/user/profile/${widget.targetUid}/rating';
                          log('🚀 [평점 업데이트 요청] URL: $updateUrl | 보낼 평점: $tempRating');

                          try {
                            final response = await http.put(
                              Uri.parse(updateUrl),
                              headers: {'Content-Type': 'application/json'},
                              body: json.encode({
                                'rating': tempRating,
                                'uid': AppConfig.currentUserUid,
                              }),
                            );

                            if (response.statusCode == 200 || response.statusCode == 201) {
                              final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
                              log('✅ [평점 업데이트 성공] 응답 데이터: $data');
                              await _saveRatedFlag();
                              if (mounted) {
                                setState(() {
                                  _rating = data['averageRating'] != null 
                                      ? double.tryParse(data['averageRating'].toString()) ?? 0.0 
                                      : 0.0;
                                });
                              }
                              
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('평점이 성공적으로 반영되었습니다!')),
                                );
                              }
                            } else {
                              log('⚠️ [평점 업데이트 실패] 상태 코드: ${response.statusCode}');
                              log('❌ [서버 에러 메시지]: ${utf8.decode(response.bodyBytes)}');
                              
                              setDialogState(() => isUpdating = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('평점 반영에 실패했습니다. (코드: ${response.statusCode})')),
                                );
                              }
                            }
                          } catch (e) {
                            log('💥 [평점 업데이트 네트워크 에러] 상세 원인: $e');
                            
                            setDialogState(() => isUpdating = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('서버 통신 중 에러가 발생했습니다.')),
                              );
                            }
                          }
                        },
                  child: Text(
                    '확인',
                    style: TextStyle(
                      color: isUpdating ? Colors.grey : const Color(0xFFEF9666),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
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

                    Center(
                      child: Container(
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

                    if (widget.targetUid != AppConfig.currentUserUid)
                      _alreadyRated
                        ? const Text(
                            '평점 완료 ✓',
                            style: TextStyle(fontSize: 20, color: Colors.grey),
                          )
                        : GestureDetector(
                            onTap: _showRatingDialog,
                            child: const Icon(Icons.edit_square, size: 50, color: Color(0xFF4A3E2D)),
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
    );
  }
}
