import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';

import '../config/app_config.dart';
import '../models/app_colors.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  NaverMapController? _mapController;
  NCameraPosition? _currentCameraPosition;
  bool _isFetchingAddress = false;

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  // 좌표 -> 주소
  Future<String> _getAddressFromCoords(double lat, double lng) async {
    final String url = '${AppConfig.baseUrl}/api/map/reverse-geocode?lat=$lat&lng=$lng';

    try {
      final response = await http.get(
        Uri.parse(url),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['address'] ?? '주소를 찾을 수 없습니다.';
      } else {
        log('❌ 검색 서버 에러: ${response.statusCode}');
        log('❌ 에러 상세 내용: ${response.body}');
        log('❌ 내가 보낸 주소: ${response.request?.url}');
        return '주소 변환 실패';
      }
    } catch (e) {
      log('네트워크 에러: $e');
      return '서버 연결 오류';
    }
  }

  // 장소 검색 API 호출
  Future<void> _searchPlace(String query) async {
    if (query.isEmpty) return;
    
    FocusScope.of(context).unfocus();

    setState(() => _isSearching = true);

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/map/search/place?query=$query'),
      );

      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        
        setState(() {
          if (decodedData is Map<String, dynamic> && decodedData.containsKey('address')) {
            _searchResults = [
              {
                'name': decodedData['placeName'] ?? query, 
                'address': decodedData['address'],
                'lat': decodedData['lat'],
                'lng': decodedData['lng'],
              }
            ];
          } else {
            _searchResults = [];
          }
        });

        if (_searchResults.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('검색 결과가 없습니다.')),
            );
          }
        }
      } else {
        log('❌ 검색 서버 에러: ${response.statusCode}');
        log('❌ 에러 상세 내용: ${response.body}');
        log('❌ 내가 보낸 주소: ${response.request?.url}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('서버 에러가 발생했습니다. (상태 코드: ${response.statusCode})')),
          );
        }
      }
    } catch (e) {
      log('검색 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터를 불러오지 못했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('장소 선택', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Stack(
        children: [
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(37.2636, 127.0286),
                zoom: 15,
              ),
            ),
            onMapReady: (controller) {
              _mapController = controller;
            },
            onCameraChange: (reason, animated) async {
              if (_mapController != null) {
                final cameraPosition = await _mapController!.getCameraPosition();
                _currentCameraPosition = cameraPosition;
              }
            },
          ),
          
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(
                Icons.location_on,
                size: 50,
                color: Color(0xFFEF9666),
              ),
            ),
          ),

          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '장소나 주소 검색',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onSubmitted: (value) => _searchPlace(value),
                  ),
                ),
                
                if (_isSearching)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.primaryButton),
                    ),
                  )
                else if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        return ListTile(
                          title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(item['address'] ?? ''),
                          
                          onTap: () {
                            double lat = double.parse(item['lat'].toString());
                            double lng = double.parse(item['lng'].toString());
                            
                            _mapController?.updateCamera(
                              NCameraUpdate.withParams(
                                target: NLatLng(lat, lng),
                                zoom: 15,
                              ),
                            );
                            
                            _searchController.text = item['name'];
                            
                            FocusScope.of(context).unfocus(); 
                          },

                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF9666),
                              minimumSize: const Size(60, 35),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              double lat = double.parse(item['lat'].toString());
                              double lng = double.parse(item['lng'].toString());
                              Navigator.pop(context, {
                                'address': item['name'],
                                'lat': lat,
                                'lng': lng,
                              });                            },
                            child: const Text('선택', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                        );
                      },
                    ),
                  ),

              ],
            ),
          ),

          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: SafeArea(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF9666),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _isFetchingAddress ? null : () async {
                  if (_currentCameraPosition == null && _mapController != null) {
                    _currentCameraPosition = await _mapController!.getCameraPosition();
                  }

                  if (_currentCameraPosition != null) {
                    setState(() => _isFetchingAddress = true);

                    double lat = _currentCameraPosition!.target.latitude;
                    double lng = _currentCameraPosition!.target.longitude;

                    String address = await _getAddressFromCoords(lat, lng);

                    setState(() => _isFetchingAddress = false);

                    if (context.mounted) {
                      Navigator.pop(context, {
                        'address': address,
                        'lat': lat,
                        'lng': lng,
                      });
                    }
                  }
                },
                child: _isFetchingAddress
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : const Text(
                        '이 위치로 설정',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
