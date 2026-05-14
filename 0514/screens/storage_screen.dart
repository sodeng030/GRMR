import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';

import '../config/app_config.dart';
import '../models/app_colors.dart';
import '../models/post_item.dart';
import '../components/bottom_bar.dart';

import 'storage_details/my_detail_screen.dart';
import 'storage_details/applying_detail_screen.dart';
import 'storage_details/completed_detail_screen.dart';

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  List<PostItem> myPosts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyPosts();
  }

  Future<void> _fetchMyPosts() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/posts'),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          final allData = data.map((json) => PostItem.fromJson(json)).toList();
          
          myPosts = allData.where((post) =>
              post.c_uid == AppConfig.currentUserUid ||
              post.a1_uid == AppConfig.currentUserUid ||
              post.a2_uid == AppConfig.currentUserUid ||
              post.a3_uid == AppConfig.currentUserUid
          ).toList();
          
          isLoading = false;
        });
      } else {
        log('보관함 목록 불러오기 실패: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      log('서버 연결 에러: $e');
      setState(() => isLoading = false);
    }
  }

  bool _checkIfCompleted(String dateStr, String timeStr) {
    try {
      final dParts = dateStr.split('.');
      final year = int.parse(dParts[0]) + 2000;
      final month = int.parse(dParts[1]);
      final day = int.parse(dParts[2]);

      int hour = 23;
      int minute = 59;
      if (timeStr.contains(':')) {
        final tParts = timeStr.split(':');
        hour = int.parse(tParts[0]);
        minute = int.parse(tParts[1]);
      }

      final postDateTime = DateTime(year, month, day, hour, minute);
      return postDateTime.add(const Duration(hours: 3)).isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusHeader(),

            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 10, bottom: 20),
                      itemCount: myPosts.length,
                      itemBuilder: (context, index) {
                        final post = myPosts[index];
                        return _buildStorageListItem(post);
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 20, right: 30, bottom: 20),
      decoration: const BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Color(0x7FFFC943),
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildStatusIndicator('모집중', AppColors.statusRecruiting),
          const SizedBox(width: 10),
          _buildStatusIndicator('신청중', AppColors.statusApplying),
          const SizedBox(width: 10),
          _buildStatusIndicator('완료됨', AppColors.statusCompleted),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, Color color) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 5),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ],
    );
  }

  Widget _buildStorageListItem(PostItem post) {
    bool isCompleted = _checkIfCompleted(post.date, post.time);
    bool isCreator = post.c_uid == AppConfig.currentUserUid;
    bool isApplying = !isCreator &&
        (post.a1_uid == AppConfig.currentUserUid ||
         post.a2_uid == AppConfig.currentUserUid ||
         post.a3_uid == AppConfig.currentUserUid);

    Color statusColor = isCompleted 
        ? AppColors.statusCompleted 
        : (isApplying ? AppColors.statusApplying : AppColors.statusRecruiting);

    return GestureDetector(
      onTap: () {
        Widget targetScreen;
        if (isCompleted) {
          targetScreen = CompletedPostDetailScreen(post: post);
        } else if (isApplying) {
          targetScreen = ApplyingPostDetailScreen(post: post);
        } else {
          targetScreen = MyPostDetailScreen(post: post);
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => targetScreen),
        ).then((_) => _fetchMyPosts());
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(23),
          boxShadow: const [
            BoxShadow(color: Color(0x3F000000), blurRadius: 4, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  post.title,
                  style: const TextStyle(color: AppColors.textMain, fontSize: 24, fontWeight: FontWeight.w700),
                ),
                Text(
                  ' (${post.now_count}/${post.max_count})',
                  style: const TextStyle(color: AppColors.textMain, fontSize: 22, fontWeight: FontWeight.w400),
                ),
                const Spacer(),
                Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${post.date} ${post.time}\n${post.category == '동행' ? '${post.location} -> ${post.destination}' : post.destination}',
              style: const TextStyle(color: AppColors.textMain, fontSize: 18, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
