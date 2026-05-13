import 'package:flutter/material.dart';
//import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../constants.dart';

class QnaScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userRole; // 'Admin' 또는 'User'

  const QnaScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userRole,
  });

  @override
  State<QnaScreen> createState() => _QnaScreenState();
}

class _QnaScreenState extends State<QnaScreen> {
  List<dynamic> _qnaList = [];
  bool _isLoading = true;
  final _formatter = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _fetchQnaList();
  }

  // 1. Q&A 목록 가져오기
  Future<void> _fetchQnaList() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(Config.getQnaList));
      if (response.statusCode == 200) {
        setState(() {
          _qnaList = json.decode(utf8.decode(response.bodyBytes));
        });
      }
    } catch (e) {
      debugPrint("Q&A 로드 실패: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 2. 질문 등록/수정/답변/삭제 서버 통신 함수들
  Future<void> _sendRequest(String url, Map<String, dynamic> body, String message) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
          Navigator.pop(context); // 바텀시트 닫기
          _fetchQnaList(); // 목록 새로고침
        }
      }
    } catch (e) {
      debugPrint("통신 에러: $e");
    }
  }

  // --- UI 빌드 영역 ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Q&A 및 피드백'),
        backgroundColor: const Color(0xFF166534),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _qnaList.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _qnaList.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _qnaList[index];
                    return _buildQnaCard(item);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQnaFormBS(), // 새 질문 등록
        backgroundColor: const Color(0xFF166534),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.question_answer_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("등록된 질문이 없습니다.", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildQnaCard(Map<String, dynamic> item) {
    bool isAnswered = item['is_answered'] == 1;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(
          item['title'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            "${item['author_name']} • ${_formatter.format(DateTime.parse(item['created_at']))}",
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isAnswered ? Colors.green[50] : Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isAnswered ? "답변완료" : "답변대기",
            style: TextStyle(
              color: isAnswered ? Colors.green[800] : Colors.orange[800],
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _showQnaFormBS(item: item), // 상세 보기
      ),
    );
  }

  // --- 상세/등록/수정 바텀시트 ---

  void _showQnaFormBS({Map<String, dynamic>? item}) async {
    final bool isEdit = item != null;
    final bool isAdmin = widget.userRole.toLowerCase() == 'admin';
    final bool isOwner = isEdit && (item['author_id'] == widget.userId);
    final bool isAnswered = isEdit && (item['is_answered'] == 1);

    final titleController = TextEditingController(text: isEdit ? item['title'] : "");
    final contentController = TextEditingController(text: isEdit ? item['content'] : "");
    final answerController = TextEditingController(text: isEdit ? item['answer'] : "");
    
    
    // 새 글(!isEdit)일 때는 무조건 false (누구나 입력 가능).
    // 기존 글(isEdit)일 때는 관리자(isAdmin)이거나, 내 글이 아니거나(!isOwner), 답변이 달렸으면(isAnswered) 잠금(true).
    final bool cannotEditQuestion = !isEdit ? false : (isAdmin || !isOwner || isAnswered);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 25, right: 25, top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, color: Colors.grey[300])),
                    const SizedBox(height: 20),
                    Text(
                      isEdit ? "질문 상세보기" : "새 질문 등록",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    
                    // 질문 제목
                    TextField(
                      controller: titleController,
                      readOnly: cannotEditQuestion,
                      decoration: const InputDecoration(labelText: "제목", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 15),
                    
                    // 질문 내용
                    TextField(
                      controller: contentController,
                      readOnly: cannotEditQuestion,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: "질문 내용", border: OutlineInputBorder()),
                    ),

                    // 답변 영역 (관리자이거나 답변이 이미 있는 경우)
                    if (isEdit && (isAdmin || isAnswered)) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(),
                      ),
                      const Text("관리자 답변", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                      const SizedBox(height: 10),
                      TextField(
                        controller: answerController,
                        readOnly: !isAdmin, // 관리자만 답변 수정 가능
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: isAdmin ? "답변을 입력하세요..." : "아직 답변이 등록되지 않았습니다.",
                          border: const OutlineInputBorder(),
                          fillColor: isAdmin ? Colors.white : Colors.grey[100],
                          filled: true,
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),

                    // 버튼 섹션
                    _buildActionButton(
                      isAdmin: isAdmin,
                      isOwner: isOwner,
                      isEdit: isEdit,
                      isAnswered: isAnswered,
                      onSave: () async {
                        if (isEdit) {
                          if (isAdmin) {
                            // 관리자 답변 등록
                            await _sendRequest(Config.answerQna, {
                              "id": item['id'],
                              "answer": answerController.text,
                              "is_update": isAnswered,
                            }, "답변이 등록되었습니다.");
                          } else {
                            // 본인 질문 수정 (답변 없을 때만)
                            await _sendRequest(Config.updateQna, {
                              "id": item['id'],
                              "title": titleController.text,
                              "content": contentController.text,
                            }, "질문이 수정되었습니다.");
                          }
                        } else {
                          // 새 질문 등록 (FCM 토큰 포함)
                          String? fcmToken = await FirebaseMessaging.instance.getToken();
                          await _sendRequest(Config.addQna, {
                            "title": titleController.text,
                            "content": contentController.text,
                            "author_id": widget.userId,
                            "author_name": widget.userName,
                            "fcm_token": fcmToken,
                          }, "질문이 등록되었습니다.");
                        }
                      },
                      onDelete: () async {
                        // 삭제 API 호출 (Config.deleteQna + id)
                        await _sendRequest("${Config.deleteQna}/${item!['id']}?user_id=${widget.userId}&role=${widget.userRole}", {}, "삭제되었습니다.");
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 상황에 맞는 버튼을 생성하는 헬퍼 함수
  Widget _buildActionButton({
    required bool isAdmin,
    required bool isOwner,
    required bool isEdit,
    required bool isAnswered,
    required VoidCallback onSave,
    required VoidCallback onDelete,
  }) {
    // 1. 관리자일 때: 답변 등록/수정 버튼 + 삭제 버튼
    if (isAdmin && isEdit) {
      return Row(
        children: [
          Expanded(child: OutlinedButton(onPressed: onDelete, child: const Text("삭제", style: TextStyle(color: Colors.red)))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(onPressed: onSave, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF166534)), child: const Text("답변 저장", style: TextStyle(color: Colors.white)))),
        ],
      );
    }

    // 2. 본인이고 답변이 없을 때: 수정 버튼 + 삭제 버튼
    if (isOwner && !isAnswered) {
      return Row(
        children: [
          Expanded(child: OutlinedButton(onPressed: onDelete, child: const Text("삭제", style: TextStyle(color: Colors.red)))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(onPressed: onSave, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF166534)), child: const Text("수정 완료", style: TextStyle(color: Colors.white)))),
        ],
      );
    }

    // 3. 본인인데 답변이 달렸을 때: 버튼 없음 (읽기 전용)
    if (isOwner && isAnswered) {
      return const SizedBox(
        width: double.infinity,
        child: Center(child: Text("답변이 완료된 질문은 수정/삭제가 불가능합니다.", style: TextStyle(color: Colors.grey, fontSize: 13))),
      );
    }

    // 4. 새 질문 등록할 때
    if (!isEdit) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: onSave,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF166534)),
          child: const Text("질문 등록하기", style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}