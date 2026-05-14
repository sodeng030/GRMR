import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:developer';

import '../../models/app_colors.dart';
import '../../models/post_item.dart';
import '../../components/bottom_bar.dart';
import '../../screens/profile_read_screen.dart';
import '../../config/app_config.dart';

class MyPostDetailScreen extends StatelessWidget {
  final PostItem post;

  const MyPostDetailScreen({super.key, required this.post});

  // 게시글 삭제 로직
  Future<void> _deletePost(BuildContext context) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('게시글 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('정말로 이 약속을 삭제하시겠습니까?\n삭제된 게시글은 복구할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final String url = '${AppConfig.baseUrl}/api/posts/${post.id}'; 

    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (!context.mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        log('✅ 게시글 삭제 성공');
        
        Navigator.pop(context, true); 
        
      } else {
        log('❌ 게시글 삭제 실패: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('게시글 삭제에 실패했습니다. 다시 시도해 주세요.')),
        );
      }
    } catch (e) {
      log('❌ 네트워크 에러: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('네트워크 오류가 발생했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
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
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 30).copyWith(bottom: 30),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('날짜 : ', post.date),
                    const SizedBox(height: 25),
                    _buildDetailRow('시간 : ', post.time),
                    const SizedBox(height: 25),

                    if (post.category == '동행') ...[
                      _buildDetailRow('출발장소 : ', post.location),
                      const SizedBox(height: 25),
                      _buildDetailRow('도착장소 : ', post.destination),
                    ] else ...[
                      _buildDetailRow('장소 : ', post.destination),
                    ],

                    const SizedBox(height: 25),
                    _buildDetailRow('인원 : ', '${post.now_count}/${post.max_count}'),
                    const SizedBox(height: 15),

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

                    const Spacer(),
                    const Divider(color: AppColors.textMain, thickness: 2, height: 30),
                    const SizedBox(height: 10),

                    Center(
                      child: GestureDetector(
                        onTap: () {
                          log('삭제 버튼 클릭');
                          _deletePost(context);
                        },
                        child: const SizedBox(
                          width: 120,
                          child: Text(
                            '삭제',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMain,
                              fontSize: 36,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 32,
              fontWeight: FontWeight.w400,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 32,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
