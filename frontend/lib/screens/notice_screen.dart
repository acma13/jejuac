import 'package:flutter/material.dart';
import '/constants.dart';
import 'dart:convert'; // jsonEncode 쓰기 위해 필요.
import 'package:http/http.dart' as http; // http.post 를 쓰기 위해 필요.

class NoticeScreen extends StatefulWidget {
  final String userRole;
  final String userName;

  const NoticeScreen({super.key, required this.userRole, required this.userName});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  List<dynamic> _notices = [];
  bool _isLoading = true; // 로딩 상태 추가
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  bool _isImportant = false;

  @override
  void initState() {
    super.initState();
    _fetchNotices(); // 화면 켜지자마자 데이터 호출
  }

  // 데이터를 새로고침하는 함수
  Future<void> _fetchNotices() async {
    setState(() => _isLoading = true);
    try {
      
      final response = await http.get(Uri.parse(Config.getNotices));

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = json.decode(response.body);
        setState(() {
          _notices = (decodedData['data'] as List?) ?? [];          
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print("공지사항 로드 실패: $e");
    }
  }     

  // 공지사항 등록
  static Future<bool> addNotice(String title, String content, bool isImportant, String authorName) async {
    final response = await http.post(
      Uri.parse(Config.addNotice),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "title": title,
        "content": content,
        "is_important": isImportant,
        "author_name": authorName,
      }),
    );
    return response.statusCode == 201 || response.statusCode == 200;
  }

  // 공지사항 수정
  static Future<bool> updateNotice(int id, String title, String content, bool isImportant) async {
    final response = await http.post(
      Uri.parse(Config.updateNotice),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "id": id,
        "title": title,
        "content": content,
        "is_important": isImportant,
      }),
    );
    return response.statusCode == 200;
  }

  // 공지사항 삭제
  static Future<bool> deleteNotice(int id) async {
    final response = await http.post(
      Uri.parse(Config.deleteNotice),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"id": id}),
    );
    return response.statusCode == 200;
  }

  // 삭제 확인 다이얼로그
  Future<bool> _showDeleteConfirmDialog() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공지 삭제'),
        content: const Text('이 공지사항을 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // 배경은 눈이 편한 밝은 회색
      appBar: AppBar(
        title: const Text('공지사항', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF166534), // 요청하신 초록색 테마
        foregroundColor: Colors.white,      
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF166534))) // 로딩 중일 때
        : _notices.isEmpty
          ? Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 60, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text("등록된 공지사항이 없습니다.", style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
          ),)
          : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: _notices.length,
            itemBuilder: (context, index) {
              final notice = _notices[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (notice['is_important'] == 1|| notice['is_important'] == true) ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      (notice['is_important'] == 1|| notice['is_important'] == true) ? Icons.campaign : Icons.notifications_none,
                      color: (notice['is_important'] == 1|| notice['is_important'] == true) ? Colors.redAccent : const Color(0xFF166534),
                    ),
                  ),
                  title: Text(
                    notice['title'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: (notice['is_important'] == 1|| notice['is_important'] == true) ? FontWeight.bold : FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      (notice['created_at'] ?? notice['date'] ?? "").toString(),
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {

                    // 기존 데이터를 컨트롤러에 세팅
                    _titleController.text = notice['title'];
                    _contentController.text = notice['content'];
                    _isImportant = (notice['is_important'] == 1 || notice['is_important'] == true);

                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true, // 화면 높이 조절을 위해 필수
                      backgroundColor: Colors.transparent, // 모서리 라운딩 처리를 위해 투명하게
                      builder: (context) {
                        return StatefulBuilder(
                          builder: (BuildContext context, StateSetter setModalState) {
                            return Padding(
                              // 키보드가 올라올 때 바텀시트가 가려지지 않게 밀어올려줌
                              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                              child: _buildNoticeDetail(notice, setModalState),
                            );
                          }
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
      // 관리자(Admin)일 때만 활성화되는 세련된 버튼
      floatingActionButton: widget.userRole == 'Admin'
          ? FloatingActionButton.extended(
              onPressed: () {
                _titleController.clear();
                _contentController.clear();
                _isImportant = false;

                // 2. 바텀 시트 호출 (상세 페이지와 동일한 로직)
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) {
                    return StatefulBuilder(
                      builder: (context, setModalState) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                          child: _buildNoticeDetail({}, setModalState), // 빈 Map 전달
                        );
                      },
                    );
                  },
                );
              },
              icon: const Icon(Icons.edit_note),
              label: const Text('공지 등록'),
              backgroundColor: const Color(0xFF166534),
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildNoticeDetail(Map<String, dynamic> notice, StateSetter setModalState) {
    bool isAdmin = (widget.userRole == 'Admin');

    return Container(
      // 1. 확실하게 배경색을 지정하여 뒤쪽 리스트가 안 보이게 합니다.
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상단 핸들러
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // 2. 스크롤 가능한 본문 영역
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 중요 공지 스위치 (관리자용)
                if (isAdmin)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _isImportant ? Colors.red[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.campaign, color: _isImportant ? Colors.red : Colors.grey),
                            const SizedBox(width: 8),
                            const Text("중요 공지 설정", style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Switch(
                          value: _isImportant,
                          activeThumbColor: Colors.redAccent,
                          onChanged: (bool value) {
                            setModalState(() {
                              _isImportant = value;
                            });
                          },
                        ),
                      ],
                    ),
                  )
                else if (notice['is_important'] == true)
                  _buildImportantBadge(),

                const SizedBox(height: 10),
                
                // 제목 입력창 (테두리를 주어 겹침 방지)
                isAdmin
                    ? TextField(
                        controller: _titleController,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: '제목',
                          border: OutlineInputBorder(), // 테두리를 명확히 함
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50], // 아주 연한 회색 배경
                          border: Border(left: BorderSide(color: const Color(0xFF166534), width: 4)), // 클럽 메인 컬러로 포인트
                        ),
                        child: Text(
                          notice['title'],
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),

                const SizedBox(height: 20),

                // 내용 입력창
                isAdmin
                    ? TextField(
                        controller: _contentController,
                        maxLines: 7,
                        decoration: const InputDecoration(
                          labelText: '내용',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        constraints: const BoxConstraints(minHeight: 200), // 최소 높이 지정
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300), // 입력창 테두리와 통일감
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          notice['content'],
                          style: const TextStyle(
                            fontSize: 16, 
                            height: 1.8, // 줄간격을 조금 더 넓혀서 가독성 향상
                            color: Colors.black87,
                          ),
                        ),
                      ),
                
                const SizedBox(height: 24),

                // 하단 버튼들
                if (isAdmin)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 새 글일 때는 삭제 버튼이 필요 없으므로 조건부 노출
                      if (notice.isNotEmpty) 
                        TextButton.icon(
                          onPressed: () async {
                            /* 삭제 로직 */ 
                            bool confirm = await _showDeleteConfirmDialog();
                            if (confirm) {
                              bool success = await deleteNotice(notice['id']);
                              if (success) {
                                if (mounted) Navigator.pop(context); // 바텀시트 닫기
                                await _fetchNotices(); // 목록 새로고침
                              }
                            }
                          },
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          label: const Text('삭제', style: TextStyle(color: Colors.red)),
                        ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () async { 
                          // 제목이나 내용이 비어있는지 간단 체크
                          if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('제목과 내용을 입력해주세요.')),
                            );
                            return;
                          }                          
                          /* 저장 로직 */ 
                          bool success;
                          String currentAuthor = widget.userName;

                          if (notice.isEmpty) {
                            // 새글 등록
                            success = await addNotice(_titleController.text,_contentController.text,_isImportant, currentAuthor,);
                          } else {
                            // 기존 글 수정
                            success = await updateNotice(notice['id'],_titleController.text,_contentController.text,_isImportant,);
                          }

                          if (success) {
                            if (mounted) Navigator.pop(context); // 바텀시트 닫기
                            await _fetchNotices(); // 목록 새로고침
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF166534),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.save),
                        label: Text(notice.isEmpty ? '등록하기' : '저장하기'),
                      ),
                    ],
                  ),
                // 키보드가 올라올 때 여백 확보
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
              ],
            ),            
          ),
        ],
      ),
    );
  }

  // 뱃지 위젯 분리
  Widget _buildImportantBadge() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.redAccent)),
      child: const Text('중요 공지', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

}