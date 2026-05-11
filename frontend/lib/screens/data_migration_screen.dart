import 'package:flutter/material.dart';
import '/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DataMigrationScreen extends StatefulWidget {
  final String userId;

  const DataMigrationScreen({super.key, required this.userId});

  @override
  State<DataMigrationScreen> createState() => _DataMigrationScreenState();
}

class _DataMigrationScreenState extends State<DataMigrationScreen> {
  final TextEditingController _urlController = TextEditingController();
  String _selectedDataType = '회원'; // 기본값
  bool _isLoading = false;

  // 마이그레이션 대상 리스트
  final List<String> _dataTypes = ['회원', '결제', 'TODO', '일정', '초대명단'];

  // 데이터 가져오기 실행 함수
  Future<void> _runMigration() async {

    String targetUrl;
      switch (_selectedDataType) {
        case '회원':
          targetUrl = Config.uploadMembersList;
          break;
        case '일정':
          targetUrl = Config.uploadSecheduleList; 
          break;
        case 'TODO':
          targetUrl = Config.uploadTodoList;
          break;
        case '결제':
          targetUrl = Config.uploadPaymentsList;
          break;
        case '초대명단':
          targetUrl = Config.uploadInvitedEmail;
          break;
        default:
          targetUrl = Config.uploadMembersList;
      }

    if (_urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("구글 시트 URL을 입력해주세요.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String url = _urlController.text;
      String dataType = _selectedDataType; // 드롭다운에서 선택된 값
      String adminId = widget.userId;

      final response = await http.post(
        Uri.parse(targetUrl), // constants.dart에 선언한 주소
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'url': url,
          'data_type': dataType, // '회원', '결제', '장비' 등
          'admin_id': adminId,   // 현재 관리자 ID
        }),
      ).timeout(const Duration(seconds: 30));     

      if (!mounted) return;
      
      if (response.statusCode == 200) {
        // 서버 응답 본문 파싱 (성공 개수 등을 확인하고 싶을 때)
        final result = jsonDecode(response.body);
        final successCount = result['success'] ?? 0;
        final failedCount = result['failed_count'] ?? 0;

        // 성공 알림 (실패 인원이 있다면 같이 표시)
        String message = "$dataType 마이그레이션 완료!";
        if (failedCount > 0) {
          message += " (성공: $successCount, 실패: $failedCount)";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$message 🎯")),
        );
        
        _urlController.clear(); // 성공 시 입력창 초기화
      } else {
        // 서버에서 에러를 보낸 경우 (400, 500 등)
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? "등록 중 오류가 발생했습니다.");
      }

    } catch (e) {
      if (!mounted) return;
      // 사용자에게 에러 다이얼로그 띄우기
      String cleanMessage = e.toString().replaceAll("Exception:", "").trim();

      // 🎯 친절한 알림창 띄우기
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Text("시트 양식 확인"),
            ],
          ),
          content: Text(
            "구글 시트 양식이 조금 안 맞는 것 같아요.\n\n📍 $cleanMessage\n\n항목 이름을 다시 한번 확인해 주세요!",
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("확인", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('데이터 일괄 등록'),
        backgroundColor: const Color(0xFF166534),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "1. 등록할 데이터 종류 선택",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            // 드롭다운 선택창
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDataType,
                  isExpanded: true,
                  items: _dataTypes.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedDataType = newValue!;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "2. 구글 시트 URL 입력",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: "https://docs.google.com/spreadsheets/d/...",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "※ 시트의 '공유' 설정을 '링크가 있는 모든 사용자'로 변경해야 읽기가 가능합니다.",
              style: TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
            const Spacer(),
            // 실행 버튼
            ElevatedButton(
              onPressed: _isLoading ? null : _runMigration,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF166534),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('$_selectedDataType 데이터 가져오기 실행', style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}