import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';

import '../config/app_config.dart';
import '../models/app_colors.dart';
import '../models/post_item.dart';
import '../components/bottom_bar.dart';
import '../screens/profile_read_screen.dart';

class DetailScreen extends StatefulWidget {
  final PostItem post;

  const DetailScreen({super.key, required this.post});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _isJoining = false;

  Future<void> _joinPost() async {
    if (widget.post.now_count >= widget.post.max_count) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 모집이 마감된 글입니다.')),
      );
      return;
    }

    setState(() => _isJoining = true);

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/posts/${widget.post.id}/join'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({'uid': AppConfig.currentUserUid}), 
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('신청이 완료되었습니다! 보관함을 확인해주세요.')),
          );
          Navigator.pop(context, true);
        }
      } else {
        log('참가 신청 실패: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('신청에 실패했습니다. 다시 시도해주세요.')),
          );
        }
      }
    } catch (e) {
      log('서버 연결 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('서버와 연결할 수 없습니다.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
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
                widget.post.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 32,
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
                    _buildDetailRow('날짜 : ', widget.post.date),
                    const SizedBox(height: 25),
                    _buildDetailRow('시간 : ', widget.post.time),
                    const SizedBox(height: 25),

                    if (widget.post.category == '동행') ...[
                      _buildDetailRow('출발장소 : ', widget.post.location),
                      const SizedBox(height: 25),
                      _buildDetailRow('도착장소 : ', widget.post.destination),
                    ] else ...[
                      _buildDetailRow('장소 : ', widget.post.destination),
                    ],

                    const SizedBox(height: 25),
                    _buildDetailRow(
                      '인원 : ',
                      '${widget.post.now_count}/${widget.post.max_count}',
                    ),
                    const SizedBox(height: 15),

                    Wrap(
                      spacing: 15,
                      runSpacing: 15,
                      children: List.generate(widget.post.now_count, (index) {
                        List<String?> participantUids = [
                          widget.post.c_uid, 
                          widget.post.a1_uid, 
                          widget.post.a2_uid, 
                          widget.post.a3_uid
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
                    const Divider(color: AppColors.textMain, thickness: 1.5, height: 30),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GestureDetector(
                          onTap: _isJoining ? null : _joinPost,
                          child: _isJoining
                              ? const SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(strokeWidth: 3),
                                )
                              : const Text(
                                  '갈래',
                                  style: TextStyle(
                                    color: AppColors.textMain,
                                    fontSize: 32,
                                    fontFamily: 'RiaSans',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            '말래',
                            style: TextStyle(
                              color: AppColors.textMain,
                              fontSize: 32,
                              fontFamily: 'RiaSans',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
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
              fontSize: 26,
              fontWeight: FontWeight.w400,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 26,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
