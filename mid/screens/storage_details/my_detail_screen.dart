import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:developer';

import '../../config/app_config.dart';
import '../../models/app_colors.dart';
import '../../models/post_item.dart';
import '../../components/bottom_bar.dart';

class MyPostDetailScreen extends StatelessWidget {
  final PostItem post;

  const MyPostDetailScreen({super.key, required this.post});

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

                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.withAlpha(30)),
                      ),
                      child: const Icon(
                        CupertinoIcons.person_fill,
                        size: 45,
                        color: Color(0xFFEF9666),
                      ),
                    ),

                    const Spacer(),
                    const Divider(color: AppColors.textMain, thickness: 2, height: 30),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GestureDetector(
                          onTap: () {
                            log('편집 버튼 클릭');
                            // 편집 페이지로 이동 로직 구현
                          },
                          child: const SizedBox(
                            width: 120,
                            child: Text(
                              '편집',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textMain,
                                fontSize: 36,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        // 가운데 구분선 (필요시)
                        Container(width: 2, height: 30, color: Colors.transparent),
                        GestureDetector(
                          onTap: () {
                            log('삭제 버튼 클릭');
                            // 실제 서버 삭제 API 호출 후 pop
                            Navigator.pop(context);
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
                      ],
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
