import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';

import '../config/app_config.dart';
import '../models/app_colors.dart';
import '../models/post_item.dart';
import '../components/bottom_bar.dart';

import 'add_screen.dart';
import 'detail_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<String> _category = ['취미', '식사', '동행'];

  final Color tabHobbyColor = const Color(0xFFFFC943);
  final Color tabMealColor = const Color(0xFFFFAC4B);
  final Color tabCompanionColor = const Color(0xFFFF8E52);

  List<PostItem> allPosts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/posts'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          allPosts = data.map((json) => PostItem.fromJson(json)).toList();
          isLoading = false;
        });
      } else {
        log('게시글 불러오기 실패: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      log('서버 연결 에러: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildTopBanner(),
            const SizedBox(height: 30),
            Expanded(
              child: Stack(
                children: [
                  Positioned(top: 0, left: 0, right: 0, child: _buildTabs()),
                  Positioned(
                    top: 65,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                      ),
                      child: Column(
                        children: [
                          _buildSubHeader(context),
                          Expanded(
                            child: isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : _buildListView(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(),
    );
  }

  Widget _buildTopBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 27),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 35),
      decoration: BoxDecoration(
        color: AppColors.topBannerBackground,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3F000000),
            blurRadius: 4,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: const Text(
        '아직 상대를\n만나지 못했어요...',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textMain,
          fontSize: 20,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        _buildTabItem(index: 0, title: '취미', bgColor: tabHobbyColor),
        _buildTabItem(index: 1, title: '식사', bgColor: tabMealColor),
        _buildTabItem(index: 2, title: '동행', bgColor: tabCompanionColor),
      ],
    );
  }

  Widget _buildTabItem({
    required int index,
    required String title,
    required Color bgColor,
  }) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(44),
          ),
          child: Stack(
            children: [
              if (!isSelected)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(44),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withAlpha(217),
                        Colors.white.withAlpha(0),
                      ],
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected 
                          ? AppColors.textMain 
                          : AppColors.textMain.withAlpha(102),
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddScreen(currentCategory: _category[_selectedIndex]),
                ),
              );
              if (result == true) {
                _fetchPosts();
              }
            },
            child: const Icon(Icons.add, size: 36, color: AppColors.textMain),
          ),
          const Spacer(),
          const SizedBox(width: 15),
          const Icon(Icons.tune, size: 32, color: AppColors.textMain),
        ],
      ),
    );
  }

  Widget _buildListView() {
    String currentCategory = _category[_selectedIndex];
    List<PostItem> filteredPosts = allPosts
        .where((post) => post.category == currentCategory)
        .toList();

    if (filteredPosts.isEmpty) {
      return Center(
        child: Text(
          '등록된 글이 없어요.',
          style: TextStyle(
            color: AppColors.textMain.withAlpha(128),
            fontSize: 20,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      itemCount: filteredPosts.length,
      itemBuilder: (context, index) {
        final post = filteredPosts[index];
        return _buildListItem(post);
      },
    );
  }

  Widget _buildListItem(PostItem post) {
    String displayLocation = post.category == '동행'
        ? '${post.location} -> ${post.destination}'
        : post.destination;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DetailScreen(post: post)),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
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
            Row(
              children: [
                Text(
                  post.title,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  ' (${post.now_count}/${post.max_count})',
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${post.date} ${post.time}\n$displayLocation',
              style: const TextStyle(
                color: AppColors.textMain,
                fontSize: 18,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
