import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';
import '../../config/app_config.dart';

import '../../models/app_colors.dart';
import '../../models/post_item.dart';
import '../../components/bottom_bar.dart';
import '../../screens/profile_read_screen.dart';

class ApplyingPostDetailScreen extends StatelessWidget {
  final PostItem post;

  const ApplyingPostDetailScreen({super.key, required this.post});

  // 신청 취소
  Future<void> _cancelApplication(BuildContext context) async {
    final url = '${AppConfig.baseUrl}/api/posts/${post.id}/cancel';
    final uid = AppConfig.currentUserUid;
    
    log('🚀 [신청 취소 요청] 서버로 전송합니다.');
    log('   ➡️ URL: $url');
    log('   ➡️ 전송 UID: $uid');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'uid': uid,
        },
      );

      log('📡 [서버 응답 수신] 상태 코드: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        log('✅ [신청 취소 성공] 응답 데이터: ${utf8.decode(response.bodyBytes)}');
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('신청이 성공적으로 취소되었습니다.')),
          );
          Navigator.pop(context, true); 
        }
      } else {
        log('⚠️ [신청 취소 실패] 원인 파악 ⬇️');
        log('   ❌ 서버 에러 메시지: ${utf8.decode(response.bodyBytes)}');
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('취소 실패 (오류 코드: ${response.statusCode})')),
          );
        }
      }
    } catch (e) {
      log('💥 [신청 취소 앱 에러] 예외 발생: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('서버 연결 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String displayLocation = post.category == '동행'
        ? '${post.location} -> ${post.destination}'
        : post.destination;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 34),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: AppColors.primaryButton,
                borderRadius: BorderRadius.circular(34),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3F000000),
                    blurRadius: 4,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                post.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 34).copyWith(bottom: 30),
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3F000000),
                      blurRadius: 4,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextRow('날짜', post.date),
                      const SizedBox(height: 25),
                      _buildTextRow('시간', post.time),
                      const SizedBox(height: 25),
                      _buildTextRow('장소', displayLocation),
                      const SizedBox(height: 25),
                      _buildTextRow('인원', '${post.now_count}/${post.max_count}'),
                      const SizedBox(height: 35),

                      Wrap(
                        spacing: 15,
                        runSpacing: 15,
                        children: List.generate(post.now_count, (index) {
                          List<String?> participantUids = [
                            post.c_uid, 
                            post.a1_uid, 
                            post.a2_uid, 
                            post.a3_uid
                          ];
                          String? currentUid = participantUids[index];
                          Color currentColor = AppColors.avatarColors[index % AppColors.avatarColors.length];

                          return GestureDetector(
                            onTap: () {
                              if (currentUid != null && currentUid.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ParticipantProfileScreen( 
                                      targetUid: currentUid,
                                      avatarColor: currentColor,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: currentColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(
                                  CupertinoIcons.person_fill,
                                  size: 45,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 30),
                      const Divider(color: AppColors.textMain, thickness: 2, height: 30),
                      
                      Center(
                        child: GestureDetector(
                          onTap: () => _cancelApplication(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                            child: const Text(
                              '신청 취소',
                              style: TextStyle(
                                color: AppColors.textMain,
                                fontSize: 36,
                                fontWeight: FontWeight.w500,
                              ),
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

  Widget _buildTextRow(String label, String value) {
    return Text(
      '$label : $value',
      style: const TextStyle(
        color: AppColors.textMain,
        fontSize: 28,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
