import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:goornot/screens/map_picker_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';

import '../config/app_config.dart';
import '../models/app_colors.dart';
import '../models/post_item.dart';
import '../components/bottom_bar.dart';

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
  int? _maxCount;
  String? _selectedLocation;
  String? _startLocation;
  String? _endLocation;

  double? _lat;
  double? _lng;

  bool _genderFilter = false;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final TextEditingController _maxCountController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _startLocationController = TextEditingController();
  final TextEditingController _endLocationController = TextEditingController();

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
        Uri.parse('${AppConfig.baseUrl}/api/titles?category=${widget.currentCategory}'),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _options = data.map((e) => e['title'].toString()).toList();
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
    log('현재 사용자 성별: ${AppConfig.currentUserGender}');
    if (_maxCount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('총 인원을 선택해주세요.')),
      );
      return;
    }

    if (widget.currentCategory == '동행') {
      if (_startLocation == null || _endLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출발지와 도착지를 모두 선택해주세요.')),
        );
        return;
      }
    } else {
      if (_selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('장소를 선택해주세요.')),
        );
        return;
      }
    }
    
    String formattedDate =
        '${_selectedDate!.year.toString().substring(2)}.${_selectedDate!.month.toString().padLeft(2, '0')}.${_selectedDate!.day.toString().padLeft(2, '0')}.';
    String formattedTime = _selectedTime != null
        ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
        : '시간 미정';

    String genderToSend = _genderFilter ? AppConfig.currentUserGender : 'all';

    final newPost = PostItem(
      category: widget.currentCategory,
      title: _selectedOption,
      now_count: 1,
      max_count: _maxCount!,
      date: formattedDate,
      time: formattedTime,
      location: widget.currentCategory == '동행' ? _startLocation! : '',
      destination: widget.currentCategory == '동행' ? _endLocation! : _selectedLocation!,

      lat: _lat,
      lng: _lng,

      gender_filter: genderToSend,      
      
      c_uid: AppConfig.currentUserUid,
    );
    log('서버로 보내는 데이터: ${json.encode(newPost.toJson())}');

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/posts'),
        headers: {
          'Content-Type': 'application/json',
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
                  _selectedTime = TimeOfDay(hour: newTime.hour, minute: newTime.minute);
                });
              },
            ),
          ),
        );
      },
    );
  }

  void _showMaxCountPicker() {
    int tempCount = _maxCount ?? 2;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext builderContext) {
        return SizedBox(
          height: 250,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 10, top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '총 인원 선택',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Paperlogy',
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _maxCount = tempCount; 
                        });
                        Navigator.pop(builderContext);
                      },
                      child: const Text(
                        '완료',
                        style: TextStyle(
                          color: Color(0xFFEF9666),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: Colors.white,
                  itemExtent: 50,
                  scrollController: FixedExtentScrollController(
                    initialItem: tempCount - 2,
                  ),
                  onSelectedItemChanged: (int index) {
                    tempCount = index + 2;
                  },
                  children: List<Widget>.generate(3, (int index) {
                    return Center(
                      child: Text(
                        '${index + 2}명',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isCompanion = widget.currentCategory == '동행';

    return Scaffold(
      backgroundColor: AppColors.background,
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
                  _isLoadingTitles ? '불러오는 중...' : _selectedOption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 30).copyWith(bottom: 30),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 25),
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
              style: const TextStyle(
                color: AppColors.textMain,
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
                    color: _selectedDate == null ? AppColors.textMain.withAlpha(102) : AppColors.textMain,
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
                  _selectedTime == null ? '선택하기' : _selectedTime!.format(context),
                  style: TextStyle(
                    color: _selectedTime == null ? AppColors.textMain.withAlpha(102) : AppColors.textMain,
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
              GestureDetector(
                onTap: () async {
                  try {
                    log('지도 화면으로 이동 시도');
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MapPickerScreen()),
                    );

                    if (result is Map<String, dynamic>) {
                      setState(() {
                        _startLocation = result['address'].toString();
                        _lat = result['lat'];
                        _lng = result['lng'];
                      });
                    } else if (result != null) {
                      setState(() {
                        _startLocation = result.toString();
                      });
                    }
                  } catch (e) {
                    log('지도 화면 이동 중 에러 발생: $e');
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 15, bottom: 10),
                  child: Text(
                    _startLocation == null ? '선택하기' : _startLocation!,
                    style: TextStyle(
                      fontSize: 24,
                      color: _startLocation == null ? Colors.black.withAlpha(100) : Colors.black,
                      fontWeight: _startLocation == null ? FontWeight.w400 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
            _buildFormRow(
              '도착장소',
              GestureDetector(
                onTap: () async {
                  try {
                    log('지도 화면으로 이동 시도');
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MapPickerScreen()),
                    );

                    if (result is Map<String, dynamic>) {
                      setState(() {
                        _endLocation = result['address'].toString();
                        _lat = result['lat'];
                        _lng = result['lng'];
                      });
                    } else if (result != null) {
                      setState(() {
                        _endLocation = result.toString();
                      });
                    }
                  } catch (e) {
                    log('지도 화면 이동 중 에러 발생: $e');
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 15, bottom: 10),
                  child: Text(
                    _endLocation == null ? '선택하기' : _endLocation!,
                    style: TextStyle(
                      fontSize: 24,
                      color: _endLocation == null ? Colors.black.withAlpha(100) : Colors.black,
                      fontWeight: _endLocation == null ? FontWeight.w400 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            _buildFormRow(
              '장소',
              GestureDetector(
                onTap: () async {
                  try {
                    log('지도 화면으로 이동 시도');
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MapPickerScreen()),
                    );
                    if (result is Map<String, dynamic>) {
                      setState(() {
                        _selectedLocation = result['address'].toString();
                        _lat = result['lat'];
                        _lng = result['lng'];
                      });
                    } else if (result != null) {
                      setState(() {
                        _selectedLocation = result.toString();
                      });
                    }
                  } catch (e) {
                    log('지도 화면 이동 중 에러 발생: $e');
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 15, bottom: 10),
                  child: Text(
                    _selectedLocation == null ? '선택하기' : _selectedLocation!,
                    style: TextStyle(
                      fontSize: 24,
                      color: _selectedLocation == null ? Colors.black.withAlpha(100) : Colors.black,
                      fontWeight: _selectedLocation == null ? FontWeight.w400 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ],
          _buildFormRow(
            '총 인원',
            GestureDetector(
              onTap: _showMaxCountPicker,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 15, bottom: 10),
                child: Text(
                  _maxCount == null ? '선택하기' : '$_maxCount명',
                  style: TextStyle(
                    fontSize: 24,
                    color: _maxCount == null ? Colors.black.withAlpha(100) : Colors.black,
                    fontWeight: _maxCount == null ? FontWeight.w400 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),

          _buildFormRow(
            '동성 전용',
            Align(
              alignment: Alignment.centerLeft,
              child: CupertinoSwitch(
                value: _genderFilter,
                activeTrackColor: const Color(0xFFEF9666),
                onChanged: (bool value) {
                  setState(() {
                    _genderFilter = value;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 30),
          const Divider(color: AppColors.textMain, thickness: 1.5, height: 30),
          GestureDetector(
            onTap: _submitPost,
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: const Text(
                '추가하기',
                style: TextStyle(
                  color: AppColors.textMain,
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
        const Divider(color: AppColors.textMain, thickness: 1.5, height: 30),
        GestureDetector(
          onTap: () => setState(() => _isSelectingCategory = false),
          child: Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: const Text(
              '확인',
              style: TextStyle(
                color: AppColors.textMain,
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
                  color: AppColors.textMain,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Text(
                  option,
                  style: const TextStyle(
                    color: AppColors.textMain,
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
