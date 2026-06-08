import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/constants.dart';

class ClubLogDetailScreen extends StatefulWidget {
  final int logId; // ◀ Map 대신 int ID만 받음
  final String userId;
  final String userName;
  final String userRole;
  final Function(BuildContext context, Map<String, dynamic> log) onEditRequested;

  const ClubLogDetailScreen({
    super.key,
    required this.logId, // ◀ 필수 인자 변경
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.onEditRequested,
  });

  @override
  State<ClubLogDetailScreen> createState() => _ClubLogDetailScreenState();
}

class _ClubLogDetailScreenState extends State<ClubLogDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  
  // 💡 상태를 관리할 핵심 변수 3개
  Map<String, dynamic>? _logData; // 서버에서 가져올 일지 본문 데이터
  List<dynamic> _comments = [];    // 서버에서 가져올 댓글 리스트
  bool _isLoading = true;          // ◀ 처음 진입할 때 무조건 true로 시작!  
  int? _editingCommentId;       // 현재 수정 중인 댓글의 id를 저장 (null 이면 일반 작성 모드)

  @override
  void initState() {
    super.initState();
    _fetchLogDetail(); // ◀ 진입하자마자 한방에 조회
  }

  // 🔄 [API 대통합] 본문과 댓글을 서버에서 한방에 긁어오는 함수
  Future<void> _fetchLogDetail() async {
    setState(() { _isLoading = true; }); // 로딩 시작
    try {
      final response = await http.get(
        Uri.parse("${Config.getLogAndComments}?log_id=${widget.logId}"),        
      );      

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _logData = data;                   // 최신 본문 저장
          _comments = data['comments'] ?? []; // 최신 댓글 저장
        });
      }
    } catch (e) {
      debugPrint("상세 정보 로딩 실패: $e");
    } finally {
      setState(() { _isLoading = false; }); // 성공하든 실패하든 로딩 끝
    }
  }

  // 📝 [API] 댓글 등록
  Future<void> _submitComment() async {
    String content = _commentController.text.trim();
    if (content.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse(Config.addLogComment),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "log_id": widget.logId,
          "userid": widget.userId,
          "username": widget.userName,
          "content": content,
        }),
      );

      if (response.statusCode == 200) {
        _commentController.clear();
        FocusScope.of(context).unfocus();
        _fetchLogDetail(); // 💡 댓글 등록 성공하면 통합 함수 다시 실행해서 갱신!
      }
    } catch (e) {
      debugPrint("댓글 등록 에러: $e");
    }
  }

  // 🔄 [API] 댓글 수정 실행
  Future<void> _modifyComment() async {
    String content = _commentController.text.trim();
    if (content.isEmpty || _editingCommentId == null) return;

    try {
      final response = await http.post(
        Uri.parse(Config.modifyLogComment),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": _editingCommentId,
          "content": content,
        }),
      );

      if (response.statusCode == 200) {
        _commentController.clear();
        setState(() {
          _editingCommentId = null; // 수정 모드 탈출
        });
        _fetchLogDetail(); // 새로고침
      }
    } catch (e) {
      debugPrint("댓글 수정 에러: $e");
    }
  }

  // ❌ [API] 댓글 삭제 실행
  Future<void> _deleteComment(int commentId) async {
    try {
      final response = await http.post(
        Uri.parse(Config.deleteLogComment),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": commentId}),
      );

      if (response.statusCode == 200) {
        _fetchLogDetail(); // 삭제 성공 시 새로고침
      }
    } catch (e) {
      debugPrint("댓글 삭제 에러: $e");
    }
  }

  // 💬 삭제 확인 다이얼로그
  void _showDeleteDialog(int commentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('댓글 삭제', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('이 댓글을 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteComment(commentId);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 💡 1. 로딩 중일 때는 화면 중앙에 깔끔하게 인디케이터만 보여줌
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF166534))),
      );
    }

    // 💡 2. 데이터 로딩이 실패했거나 없는 경우 예외 처리
    if (_logData == null) {
      return const Scaffold(
        body: Center(child: Text("데이터를 불러오지 못했습니다.")),
      );
    }

    // 💡 3. 데이터가 무사히 로딩되면 화면을 그립니다. (null 걱정 ZERO)
    return Scaffold(
      appBar: AppBar(
        title: const Text('일지 상세 보기'),
        backgroundColor: const Color(0xFF166534),
        foregroundColor: Colors.white,
        actions: [
          if (widget.userId == _logData!['userid'] || widget.userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.edit_note, size: 28),
              onPressed: () async {
                // 부모창 바텀시트 열고 닫힐 때까지 대기
                await widget.onEditRequested(context, _logData!);
                // 기존 메모리를 비워서 플러터에게 데이터가 바뀔 것이라고 선언
                setState(() {
                  _logData = null; 
                });
                _fetchLogDetail(); // 💡 수정창 닫히면 통합 함수 다시 실행해서 갱신!
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_logData!['title'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text("작성자: ${_logData!['username']}  |  ${_logData!['log_date']}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const Divider(height: 35, thickness: 1),
                  Text(_logData!['content'] ?? '', style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87)),
                  const Divider(height: 50, thickness: 1),
                  
                  // 댓글 헤더
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.black54),
                      const SizedBox(width: 6),
                      Text("댓글 (${_comments.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // 댓글 리스트
                  _comments.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(child: Text("첫 번째 댓글을 남겨보세요!", style: TextStyle(color: Colors.grey))),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _comments.length,
                          separatorBuilder: (context, index) => const Divider(height: 20),
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            final bool isCommentAuthor = comment['userid'] == widget.userId;
                            final bool isAdmin = widget.userRole == 'Admin';

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(comment['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        const SizedBox(width: 8),
                                        Text(comment['create_at'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                      ],
                                    ),
                                    // 💡 [우측 점세개 팝업 메뉴 추가] 권한자에게만 노출
                                    if (isCommentAuthor || isAdmin)
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            // 수정 선택 시 하단 입력창을 수정모드로 변환
                                            setState(() {
                                              _editingCommentId = comment['id'];
                                              _commentController.text = comment['content'] ?? '';
                                            });
                                          } else if (value == 'delete') {
                                            _showDeleteDialog(comment['id']);
                                          }
                                        },
                                        itemBuilder: (BuildContext context) => [
                                          if (isCommentAuthor) // 💡 운영 노하우: 수정은 본인만 가능하게 제한
                                            const PopupMenuItem(value: 'edit', child: Text('수정', style: TextStyle(fontSize: 14))),
                                          const PopupMenuItem(value: 'delete', child: Text('삭제', style: TextStyle(color: Colors.red, fontSize: 14))),
                                        ],
                                      ),
                                  ],
                                ),
                                
                                const SizedBox(height: 5),
                                Text(comment['content'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                              ],
                            );
                          },
                        ),
                ],
              ),
            ),
          ),         
          
          // 하단 댓글 입력창 고정
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 💡 [수정 모드 전용 상단 안내 바] 수정 버튼을 눌렀을 때만 나타납니다.
              if (_editingCommentId != null)
                Container(
                  color: Colors.green[50],
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '✏️ 댓글 수정 중...', 
                        style: TextStyle(color: Color(0xFF166534), fontSize: 13, fontWeight: FontWeight.bold)
                      ),
                      GestureDetector(
                        onTap: () {
                          // X 버튼 누르면 취소하고 일반 모드로 복귀
                          setState(() {
                            _editingCommentId = null;
                            _commentController.clear();
                          });
                          FocusScope.of(context).unfocus();
                        },
                        child: const Icon(Icons.close, size: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                
              // 실제 입력 테두리 컨테이너
              Container(
                padding: EdgeInsets.only(
                  left: 15, 
                  right: 8, 
                  top: 8, 
                  bottom: MediaQuery.of(context).padding.bottom + 8
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50], 
                  border: Border(top: BorderSide(color: Colors.grey[300]!))
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        maxLines: null,
                        decoration: InputDecoration( // 💡 에러 방지를 위해 const 제거
                          hintText: _editingCommentId != null ? '수정할 내용을 입력하세요...' : '댓글을 입력하세요...',
                          border: InputBorder.none
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _editingCommentId != null ? Icons.check_circle : Icons.send, 
                        color: const Color(0xFF166534)
                      ),
                      onPressed: _editingCommentId != null ? _modifyComment : _submitComment,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ], // ◀ body: Column의 자식 배열(children)이 끝나는 지점입니다.
      ),
    );
  }
}