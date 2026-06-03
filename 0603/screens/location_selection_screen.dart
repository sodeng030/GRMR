import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';

import '../config/app_config.dart';
import '../models/app_colors.dart';

class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({super.key});

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  NaverMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  
  bool _isSearching = false;
  List<dynamic> _searchResults = [];

  Future<void> _searchPlace(String query) async {
    if (query.isEmpty) return;
    
    setState(() => _isSearching = true);

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/map/search/place?query=$query'),
      );

      if (!mounted) return;  // 👈 추가
      FocusScope.of(context).unfocus();  // 👈 await 이후로 이동

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

        if (_searchResults.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('검색 결과가 없습니다.')),
          );
        }
      } else {
        log('❌ 검색 서버 에러: ${response.statusCode}');
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기준 위치 설정', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
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
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
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
                              NCameraUpdate.withParams(target: NLatLng(lat, lng), zoom: 15),
                            );
                            
                            setState(() => _searchResults = []);
                            _searchController.text = item['name'];
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
                              Navigator.pop(context, {'lat': lat, 'lng': lng}); 
                            },
                            child: const Text('선택', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40), 
              child: Icon(Icons.location_on, size: 50, color: Color(0xFFEF9666)),
            ),
          ),
          
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF9666),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () async {
                if (_mapController != null) {
                  final cameraPos = await _mapController!.getCameraPosition();
                  final lat = cameraPos.target.latitude;
                  final lng = cameraPos.target.longitude;
                  
                  if (!mounted) return;
                  Navigator.pop(context, {'lat': lat, 'lng': lng});
                }
              },
              child: const Text(
                '이 위치로 설정하기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
