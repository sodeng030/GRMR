import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:developer';
import 'login_screen.dart';

const String baseUrl = 'https://semidomestic-lurlene-nonarchitectonic.ngrok-free.dev';

void main() {
  runApp(const MyApp());
}

// 데이터 모델
class PostItem {
  final int? id;
  final String category;
  final String title;
  final int now_count;
  final int max_count;
  final String date;
  final String time;
  final String location;
  final String destination;

  final String c_name;
  final String? a1_name;
  final String? a2_name;
  final String? a3_name;

  PostItem({
    this.id,
    required this.category,
    required this.title,
    required this.now_count,
    required this.max_count,
    required this.date,
    required this.time,
    required this.location,
    required this.destination,

    required this.c_name,
    this.a1_name,
    this.a2_name,
    this.a3_name,
  });

  factory PostItem.fromJson(Map<String, dynamic> json) {
    return PostItem(
      id: json['id'],
      category: json['category'] ?? '',
      title: json['title'] ?? '',
      now_count: json['now_count'] is int
          ? json['now_count']
          : int.tryParse(json['now_count'].toString()) ?? 1,
      max_count: json['max_count'] is int
          ? json['max_count']
          : int.tryParse(json['max_count'].toString()) ?? 1,
      date: json['date'] ?? '',
      time: json['time'] ?? '시간 미정',
      location: json['location'] ?? '',
      destination: json['destination'] ?? '',

      c_name: json['c_name'] ?? '',
      a1_name: json['a1_name'] ?? '',
      a2_name: json['a2_name'] ?? '',
      a3_name: json['a3_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'title': title,
      'now_count': now_count,
      'max_count': max_count,
      'date': date,
      'time': time,
      'location': location,
      'destination': destination,

      'c_name': c_name,
      'a1_name': a1_name ?? '',
      'a2_name': a2_name ?? '',
      'a3_name': a3_name ?? '',
    };
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Paperlogy',
        scaffoldBackgroundColor: Colors.white,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
      ],
      home: const LoginScreen(),
    );
  }
}

// 메인 화면
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<String> _category = ['취미', '식사', '동행'];

  final Color textColor = const Color(0xFF331F07);
  final Color topBannerBgColor = const Color(0xFFFFF8E6);
  final Color mainContentBgColor = const Color(0xFFFFEEC6);

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
        Uri.parse('$baseUrl/api/posts'),
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
                      decoration: BoxDecoration(color: mainContentBgColor),
                      child: Column(
                        children: [
                          _buildSubHeader(context),
                          Expanded(
                            child: isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
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
        color: topBannerBgColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3F000000),
            blurRadius: 4,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        '아직 상대를\n만나지 못했어요...',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
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
                      color: isSelected ? textColor : textColor.withAlpha(102),
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
                  builder: (context) =>
                      AddScreen(currentCategory: _category[_selectedIndex]),
                ),
              );
              if (result == true) {
                _fetchPosts();
              }
            },
            child: Icon(Icons.add, size: 36, color: textColor),
          ),
          const Spacer(),
          const SizedBox(width: 15),
          Icon(Icons.tune, size: 32, color: textColor),
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
          style: TextStyle(color: textColor.withAlpha(128), fontSize: 20),
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
                  style: TextStyle(
                    color: textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  ' (${post.now_count}/${post.max_count})',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${post.date} ${post.time}\n$displayLocation',
              style: TextStyle(
                color: textColor,
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

// 상세 화면
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
      // join api 주소 넣을곳
      final response = await http.post(
        Uri.parse('$baseUrl/api/posts/${widget.post.id}/join'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({'uid': uid}),
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
    final Color textColor = const Color(0xFF331F07);
    final Color bgColor = const Color(0xFFFFEEC6);
    final Color cardColor = const Color(0xFFFFFBF1);
    final Color buttonColor = const Color(0xFFFFC943);

    final List<Color> profileColors = [
      const Color(0xFFF6796E),
      const Color(0xFFFFD66D),
      const Color(0xFFFFAA46),
      const Color(0xFFC7DA80),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: buttonColor,
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
                style: TextStyle(
                  color: textColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 30,
                ).copyWith(bottom: 30),
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: cardColor,
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
                    _buildDetailRow('날짜 : ', widget.post.date, textColor),
                    const SizedBox(height: 25),
                    _buildDetailRow('시간 : ', widget.post.time, textColor),
                    const SizedBox(height: 25),

                    if (widget.post.category == '동행') ...[
                      _buildDetailRow('출발장소 : ', widget.post.location, textColor),
                      const SizedBox(height: 25),
                      _buildDetailRow('도착장소 : ', widget.post.destination, textColor),
                    ] else ...[
                      _buildDetailRow('장소 : ', widget.post.destination, textColor),
                    ],

                    const SizedBox(height: 25),
                    _buildDetailRow(
                      '인원 : ',
                      '${widget.post.now_count}/${widget.post.max_count}',
                      textColor,
                    ),
                    const SizedBox(height: 15),

                    Wrap(
                      spacing: 15,
                      runSpacing: 15,
                      children: List.generate(widget.post.now_count, (index) {
                        return Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: profileColors[index % profileColors.length],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.withAlpha(30),
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.person_fill,
                            size: 55,
                            color: Colors.white,
                          ),
                        );
                      }),
                    ),

                    const Spacer(),
                    Divider(color: textColor, thickness: 1.5, height: 30),

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
                              : Text(
                                  '갈래',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 32,
                                    fontFamily: 'RiaSans',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            '말래',
                            style: TextStyle(
                              color: textColor,
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

  Widget _buildDetailRow(String label, String value, Color textColor) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: label,
            style: TextStyle(
              color: textColor,
              fontSize: 26,
              fontWeight: FontWeight.w400,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: textColor,
              fontSize: 26,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// 추가하기 화면
class AddScreen extends StatefulWidget {
  final String currentCategory;

  const AddScreen({super.key, required this.currentCategory});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  bool _isSelectingCategory = false;
  late String _selectedOption;
  List<String> _options = [];
  bool _isLoadingTitles = false;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final TextEditingController _maxCountController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _startLocationController =
      TextEditingController();
  final TextEditingController _endLocationController = TextEditingController();

  final Color textColor = const Color(0xFF331F07);
  final Color bgColor = const Color(0xFFFFEEC6);
  final Color cardColor = const Color(0xFFFFFBF1);
  final Color buttonColor = const Color(0xFFFFC943);

  @override
  void initState() {
    super.initState();
    if (widget.currentCategory == '동행') {
      _selectedOption = '동행';
    } else {
      _selectedOption = '${widget.currentCategory} 선택';
      _fetchTitles();
    }
  }

  @override
  void dispose() {
    _maxCountController.dispose();
    _locationController.dispose();
    _startLocationController.dispose();
    _endLocationController.dispose();
    super.dispose();
  }

  Future<void> _fetchTitles() async {
    setState(() => _isLoadingTitles = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/titles?category=${widget.currentCategory}'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _options = data.map((e) => e.toString()).toList();
          _isLoadingTitles = false;
        });
      } else {
        log('타이틀 불러오기 실패');
        setState(() => _isLoadingTitles = false);
      }
    } catch (e) {
      log('서버 에러: $e');
      setState(() => _isLoadingTitles = false);
    }
  }

  Future<void> _submitPost() async {
    if (_selectedOption.contains('선택') || _selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('종류와 날짜를 모두 선택해주세요.')));
      return;
    }

    String formattedDate =
        '${_selectedDate!.year.toString().substring(2)}.${_selectedDate!.month.toString().padLeft(2, '0')}.${_selectedDate!.day.toString().padLeft(2, '0')}.';
    String formattedTime = _selectedTime != null
        ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
        : '시간 미정';

    String finalLocation = '';
    String finalDestination = '';

    if (widget.currentCategory == '동행') {
      finalLocation = _startLocationController.text.isEmpty
          ? '미정'
          : _startLocationController.text;
      finalDestination = _endLocationController.text.isEmpty
          ? '미정'
          : _endLocationController.text;
    } else {
      finalLocation = '';
      finalDestination = _locationController.text.isEmpty
          ? '미정'
          : _locationController.text;
    }

    final newPost = PostItem(
      category: widget.currentCategory,
      title: _selectedOption,
      now_count: 1,
      max_count: int.tryParse(_maxCountController.text) ?? 2,
      date: formattedDate,
      time: formattedTime,
      location: finalLocation,
      destination: finalDestination,
      
      c_name: uid, 
    );

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/posts'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(newPost.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) Navigator.pop(context, true);
      } else {
        log('게시글 등록 실패: ${response.statusCode}');
      }
    } catch (e) {
      log('서버 에러: $e');
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _selectedDate ?? now,
              minimumDate: now,
              maximumDate: DateTime(2030, 12, 31),
              onDateTimeChanged: (DateTime newDate) {
                setState(() => _selectedDate = newDate);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickTime() async {
    DateTime initialDateTime = DateTime.now();
    if (_selectedTime != null) {
      initialDateTime = DateTime(
        initialDateTime.year,
        initialDateTime.month,
        initialDateTime.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
    }

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: initialDateTime,
              onDateTimeChanged: (DateTime newTime) {
                setState(() {
                  _selectedTime = TimeOfDay(
                    hour: newTime.hour,
                    minute: newTime.minute,
                  );
                });
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isCompanion = widget.currentCategory == '동행';

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                if (!isCompanion && !_isLoadingTitles) {
                  setState(() => _isSelectingCategory = !_isSelectingCategory);
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 30),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: buttonColor,
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
                  _isLoadingTitles ? '불러오는 중...' : _selectedOption,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 30,
                ).copyWith(bottom: 30),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 25,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3F000000),
                      blurRadius: 4,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: _isSelectingCategory
                    ? _buildSelectionView()
                    : _buildFormView(isCompanion),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(),
    );
  }

  Widget _buildFormRow(String title, Widget inputWidget) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 26,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(child: inputWidget),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: textColor.withAlpha(102),
        fontSize: 22,
        fontWeight: FontWeight.w400,
      ),
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: textColor.withAlpha(50)),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: textColor, width: 2),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
    );
  }

  Widget _buildFormView(bool isCompanion) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormRow(
            '날짜',
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                color: Colors.transparent,
                child: Text(
                  _selectedDate == null
                      ? '선택하기'
                      : '${_selectedDate!.year.toString().substring(2)}.${_selectedDate!.month.toString().padLeft(2, '0')}.${_selectedDate!.day.toString().padLeft(2, '0')}.',
                  style: TextStyle(
                    color: _selectedDate == null
                        ? textColor.withAlpha(102)
                        : textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),

          _buildFormRow(
            '시간',
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                color: Colors.transparent,
                child: Text(
                  _selectedTime == null
                      ? '선택하기'
                      : _selectedTime!.format(context),
                  style: TextStyle(
                    color: _selectedTime == null
                        ? textColor.withAlpha(102)
                        : textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),

          if (isCompanion) ...[
            _buildFormRow(
              '출발장소',
              TextField(
                controller: _startLocationController,
                style: TextStyle(color: textColor, fontSize: 24),
                decoration: _inputDecoration('입력하기'),
              ),
            ),
            _buildFormRow(
              '도착장소',
              TextField(
                controller: _endLocationController,
                style: TextStyle(color: textColor, fontSize: 24),
                decoration: _inputDecoration('입력하기'),
              ),
            ),
          ] else ...[
            _buildFormRow(
              '장소',
              TextField(
                controller: _locationController,
                style: TextStyle(color: textColor, fontSize: 24),
                decoration: _inputDecoration('입력하기'),
              ),
            ),
          ],

          _buildFormRow(
            '총 인원',
            TextField(
              controller: _maxCountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textColor, fontSize: 24),
              decoration: _inputDecoration('명 (숫자만)'),
            ),
          ),

          const SizedBox(height: 30),
          Divider(color: textColor, thickness: 1.5, height: 30),

          GestureDetector(
            onTap: _submitPost,
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '추가하기',
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _options.isEmpty
              ? const Center(child: Text('카테고리가 없습니다.'))
              : _buildStandardList(),
        ),
        Divider(color: textColor, thickness: 1.5, height: 30),
        GestureDetector(
          onTap: () => setState(() => _isSelectingCategory = false),
          child: Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              '확인',
              style: TextStyle(
                color: textColor,
                fontSize: 28,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStandardList() {
    return ListView.builder(
      itemCount: _options.length,
      itemBuilder: (context, index) {
        final option = _options[index];
        final isChecked = _selectedOption == option;

        return GestureDetector(
          onTap: () => setState(() => _selectedOption = option),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(
                  isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                  color: textColor,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Text(
                  option,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 30,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 프로필 화면
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

  Color _profileBgColor = const Color(0xFFFFC943);

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    if (uid.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // uid 받아오는 api
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/profile/$uid'), 
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        setState(() {
          userName = data['name'] ?? '정보 없음';
          userEmail = data['email'] ?? '정보 없음';
          userGender = data['gender'] ?? '정보 없음';
          userBirth = data['birth'] ?? '정보 없음';

          if (data['colorCode'] != null) {
            String hexColor = data['colorCode'].toString().replaceAll(
              '#',
              '',
            );
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
          backgroundColor: const Color(0xFFFFFBF1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            '특징 추가',
            style: TextStyle(
              fontFamily: 'Paperlogy',
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: '특징 입력 (예: ENTP)',
              hintStyle: TextStyle(color: Colors.black.withAlpha(100)),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFEF9666)),
              ),
            ),
            cursorColor: const Color(0xFFEF9666),
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
              child: const Text(
                '추가',
                style: TextStyle(
                  color: Color(0xFFEF9666),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = const Color(0xFFFFEEC6);
    final Color tagBgColor = const Color(0xFFFFDF91);
    final Color tagTextColor = const Color(0xFFFFC943);

    return Scaffold(
      backgroundColor: bgColor,
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
                          ..._userTags.map(
                            (tag) =>
                                _buildTagItem(tag, tagBgColor, tagTextColor),
                          ),
                          GestureDetector(
                            onTap: _showAddTagDialog,
                            child: _buildAddTagButton(tagBgColor, tagTextColor),
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
                    color: Color(0xFFFFEEC6),
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
                      const Text(
                        '본인 인증 정보',
                        style: TextStyle(
                          color: Color(0xFFEF9666),
                          fontSize: 36,
                          fontFamily: 'Paperlogy',
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
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : Text.rich(
                                        TextSpan(
                                            style: const TextStyle(
                                            color: Color(0xFF331F07),
                                            fontSize: 28,
                                            fontFamily: 'Paperlogy',
                                          ),
                                          children: [
                                            const TextSpan(
                                              text: '이름 \n',
                                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20), // 볼드체
                                            ),
                                            TextSpan(
                                              text: ' $userName\n',
                                              style: const TextStyle(fontWeight: FontWeight.w400), // 기본 굵기
                                            ),
                                            const TextSpan(
                                              text: '성별 \n',
                                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20), // 볼드체
                                            ),
                                            TextSpan(
                                              text: ' $userGender\n',
                                              style: const TextStyle(fontWeight: FontWeight.w400), // 기본 굵기
                                            ),
                                            const TextSpan(
                                              text: '생년월일 \n',
                                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20), // 볼드체
                                            ),
                                            TextSpan(
                                              text: '$userBirth\n',
                                              style: const TextStyle(fontWeight: FontWeight.w400), // 기본 굵기
                                            ),
                                            const TextSpan(
                                              text: '이메일 \n',
                                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20), // 볼드체
                                            ),
                                            TextSpan(
                                              text: '$userEmail\n',
                                              style: const TextStyle(fontWeight: FontWeight.w400), // 기본 굵기
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
                                    fontFamily: 'Paperlogy',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 30),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildButton(
                                      '재인증',
                                      const Color(0xFFEF9666),
                                    ),
                                    const SizedBox(width: 25),
                                    _buildButton(
                                      '탈퇴하기',
                                      const Color(0xFFEF9666),
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
      bottomNavigationBar: const CustomBottomNavBar(),
    );
  }

  Widget _buildTagItem(String text, Color bgColor, Color textColor) {
    return Container(
      width: 87,
      height: 42,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 20,
          fontFamily: 'Paperlogy',
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildAddTagButton(Color bgColor, Color iconColor) {
    return Container(
      width: 87,
      height: 42,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        '+',
        style: TextStyle(
          color: iconColor,
          fontSize: 40,
          fontFamily: 'Paperlogy',
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
          fontFamily: 'Paperlogy',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// 공통 하단 네비게이션 바
class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x4CFFEAB5),
            blurRadius: 30,
            offset: Offset(0, -20),
            spreadRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StorageScreen()),
              );
            },
            child: _buildBottomNavImage('assets/images/box.png', 70),
          ),

          GestureDetector(
            onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: _buildBottomNavImage('assets/images/main.png', 70),
          ),

          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            child: _buildBottomNavImage('assets/images/profile.png', 70),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavImage(String imagePath, double imageSize) {
    return SizedBox(
      height: 70,
      child: Center(
        child: Image.asset(imagePath, height: imageSize, fit: BoxFit.contain),
      ),
    );
  }
}

// 보관함 화면
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
        Uri.parse('$baseUrl/api/posts'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          final allData = data.map((json) => PostItem.fromJson(json)).toList();
          
          myPosts = allData.where((post) =>
              post.c_name == uid ||
              post.a1_name == uid ||
              post.a2_name == uid ||
              post.a3_name == uid
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

      return postDateTime
          .add(const Duration(hours: 3))
          .isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = const Color(0xFF331F07);
    final Color bgColor = const Color(0xFFFFEEC6);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 20, right: 30, bottom: 20),
              decoration: const BoxDecoration(
                color: Color(0xFFFFEEC6),
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
                  const Text(
                    '모집중',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 19,
                    height: 19,
                    decoration: const BoxDecoration(
                      color: Color(0xFF9DDD9A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '신청중',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 19,
                    height: 19,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFCA44),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '완료됨',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 19,
                    height: 19,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC0C0C0),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 10, bottom: 20),
                      itemCount: myPosts.length,
                      itemBuilder: (context, index) {
                        final post = myPosts[index];
                        bool isCompleted = _checkIfCompleted(
                          post.date,
                          post.time,
                        );
                        
                        bool isCreator = post.c_name == uid;
                        bool isApplying = !isCreator &&
                            (post.a1_name == uid ||
                             post.a2_name == uid ||
                             post.a3_name == uid);

                        String displayLocation = post.category == '동행'
                            ? '${post.location} -> ${post.destination}'
                            : post.destination;

                        Color statusColor;
                        if (isCompleted) {
                          statusColor = const Color(0xFFC0C0C0);
                        } else if (isApplying) {
                          statusColor = const Color(0xFFFFCA44);
                        } else {
                          statusColor = const Color(0xFF9DDD9A);
                        }

                        return GestureDetector(
                          onTap: () {
                            if (isCompleted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CompletedPostDetailScreen(post: post),
                                ),
                              ).then((_) => _fetchMyPosts());
                            } else if (isApplying) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ApplyingPostDetailScreen(post: post),
                                ),
                              ).then((_) => _fetchMyPosts());
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      MyPostDetailScreen(post: post),
                                ),
                              ).then((_) => _fetchMyPosts());
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
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
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      ' (${post.now_count}/${post.max_count})',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      width: 19,
                                      height: 19,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${post.date} ${post.time}\n$displayLocation',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w400,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(),
    );
  }
}

// 보관함 내 글 상세 화면_모집중
class MyPostDetailScreen extends StatelessWidget {
  final PostItem post;

  const MyPostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final Color textColor = const Color(0xFF331F07);
    final Color bgColor = const Color(0xFFFFEEC6);
    final Color cardColor = const Color(0xFFFFFBF1);
    final Color buttonColor = const Color(0xFFFFC943);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: buttonColor,
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
                style: TextStyle(
                  color: textColor,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 30,
                ).copyWith(bottom: 30),
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: cardColor,
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
                    _buildDetailRow('날짜 : ', post.date, textColor),
                    const SizedBox(height: 25),
                    _buildDetailRow('시간 : ', post.time, textColor),
                    const SizedBox(height: 25),

                    if (post.category == '동행') ...[
                      _buildDetailRow('출발장소 : ', post.location, textColor),
                      const SizedBox(height: 25),
                      _buildDetailRow('도착장소 : ', post.destination, textColor),
                    ] else ...[
                      _buildDetailRow('장소 : ', post.destination, textColor),
                    ],

                    const SizedBox(height: 25),
                    _buildDetailRow(
                      '인원 : ',
                      '${post.now_count}/${post.max_count}',
                      textColor,
                    ),
                    const SizedBox(height: 15),

                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.withAlpha(30)),
                      ),
                      child: Icon(
                        CupertinoIcons.person_fill,
                        size: 45,
                        color: const Color(0xFFEF9666),
                      ),
                    ),

                    const Spacer(),
                    Divider(color: textColor, thickness: 2, height: 30),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GestureDetector(
                          onTap: () {
                            log('편집 버튼 클릭');
                          },
                          child: Container(
                            width: 120,
                            alignment: Alignment.center,
                            child: Text(
                              '편집',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 36,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        Container(
                          width: 2,
                          height: 30,
                          color: Colors.transparent,
                        ),

                        GestureDetector(
                          onTap: () {
                            log('삭제 버튼 클릭');
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 120,
                            alignment: Alignment.center,
                            child: Text(
                              '삭제',
                              style: TextStyle(
                                color: textColor,
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

  Widget _buildDetailRow(String label, String value, Color textColor) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: label,
            style: TextStyle(
              color: textColor,
              fontSize: 32,
              fontWeight: FontWeight.w400,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: textColor,
              fontSize: 32,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// 보관함 내 글 상세 화면_신청중
class ApplyingPostDetailScreen extends StatelessWidget {
  final PostItem post;

  const ApplyingPostDetailScreen({super.key, required this.post});

  // 신청 취소 api
  Future<void> _cancelApplication(BuildContext context) async {
    // TODO: 실제 백엔드 API 구조에 맞춰 아래 코드를 수정하세요.
    /*
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/posts/${post.id}/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'uid': uid}), // 내 uid 전송
      );

      if (response.statusCode == 200) {
        Navigator.pop(context, true); 
      } else {
        log('취소 실패: ${response.statusCode}');
      }
    } catch (e) {
      log('에러: $e');
    }
    */
    
    // 백엔드 연결 전 임시 테스트용 코드
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('신청이 취소되었습니다.')),
    );
    Navigator.pop(context, true); 
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = const Color(0xFF331F07);
    final Color bgColor = const Color(0xFFFFEEC6);
    final Color cardColor = const Color(0xFFFFFBF1);
    final Color buttonColor = const Color(0xFFFFC943);

    final List<Color> avatarColors = [
      const Color(0xFFF6796D),
      const Color(0xFFFFD56D),
      const Color(0xFFFFA945),
      const Color(0xFFC7DA80),
    ];

    String displayLocation = post.category == '동행'
        ? '${post.location} -> ${post.destination}'
        : post.destination;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 34),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: buttonColor,
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
                style: TextStyle(
                  color: textColor,
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
                  color: cardColor,
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
                    _buildTextRow('날짜', post.date, textColor),
                    const SizedBox(height: 25),
                    _buildTextRow('시간', post.time, textColor),
                    const SizedBox(height: 25),
                    _buildTextRow('장소', displayLocation, textColor),
                    const SizedBox(height: 25),
                    _buildTextRow('인원', '${post.now_count}/${post.max_count}', textColor),
                    const SizedBox(height: 35),

                    Wrap(
                      spacing: 15,
                      runSpacing: 15,
                      children: List.generate(post.now_count, (index) {
                        return Container(
                          width: 75,
                          height: 75,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: avatarColors[index % avatarColors.length],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.person_fill,
                                size: 35,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    const Spacer(),

                    Divider(color: textColor, thickness: 2, height: 30),
                    const SizedBox(height: 10),
                    
                    Center(
                      child: GestureDetector(
                        onTap: () => _cancelApplication(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                          child: Text(
                            '신청 취소',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 40,
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
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(),
    );
  }

  Widget _buildTextRow(String label, String value, Color textColor) {
    return Text(
      '$label : $value',
      style: TextStyle(
        color: textColor,
        fontSize: 36,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

// 보관함 내 글 상세 화면_완료됨
class CompletedPostDetailScreen extends StatelessWidget {
  final PostItem post;

  const CompletedPostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final Color textColor = const Color(0xFF331F07);
    final Color bgColor = const Color(0xFFFFEEC6);
    final Color cardColor = const Color(0xFFFFFBF1);
    final Color buttonColor = const Color(0xFFFFC943);

    final List<Color> avatarColors = [
      const Color(0xFFF6796D),
      const Color(0xFFFFD56D),
      const Color(0xFFFFA945),
      const Color(0xFFC7DA80),
    ];

    String displayLocation = post.category == '동행'
        ? '${post.location} -> ${post.destination}'
        : post.destination;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 34),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: buttonColor,
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
                style: TextStyle(
                  color: textColor,
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
                  color: cardColor,
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
                    _buildTextRow('날짜', post.date, textColor),
                    const SizedBox(height: 25),
                    _buildTextRow('시간', post.time, textColor),
                    const SizedBox(height: 25),
                    _buildTextRow('장소', displayLocation, textColor),
                    const SizedBox(height: 25),
                    _buildTextRow('인원', '${post.now_count}/${post.max_count}', textColor),
                    const SizedBox(height: 35),

                    Wrap(
                      spacing: 15,
                      runSpacing: 15,
                      children: List.generate(post.now_count, (index) {
                        return Container(
                          width: 75,
                          height: 75,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: avatarColors[index % avatarColors.length],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.person_fill,
                                size: 35,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        const Icon(
                          Icons.arrow_drop_up,
                          color: Color(0xFF665641),
                          size: 30,
                        ),
                        Text(
                          '함께한 사람의 평점을 남겨주세요!',
                          style: TextStyle(
                            color: const Color(0xFF665641),
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
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(),
    );
  }

  Widget _buildTextRow(String label, String value, Color textColor) {
    return Text(
      '$label : $value',
      style: TextStyle(
        color: textColor,
        fontSize: 36,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

