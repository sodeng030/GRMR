import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../models/app_colors.dart';
import '../../models/post_item.dart';
import '../../components/bottom_bar.dart';
import '../../screens/profile_rating_screen.dart';
import '../../config/app_config.dart';

class CompletedPostDetailScreen extends StatelessWidget {
  final PostItem post;

  const CompletedPostDetailScreen({super.key, required this.post});

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
                              if (currentUid != null && currentUid.isNotEmpty &&
                                  currentUid != AppConfig.currentUserUid) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RatingProfileScreen(
                                      targetUid: currentUid,
                                      avatarColor: currentColor,
                                      postId: post.id!,
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

                      const SizedBox(height: 40),

                      Row(
                        children: const [
                          Icon(
                            Icons.arrow_drop_up,
                            color: Color(0xFF665641),
                            size: 30,
                          ),
                          Text(
                            '함께한 사람의 평점을 남겨주세요!',
                            style: TextStyle(
                              color: Color(0xFF665641),
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
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
