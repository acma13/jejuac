import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/constants.dart';

// ---------------------------------------------------------------------------
// 1. 모델 클래스 (파일 상단에 위치)
// ---------------------------------------------------------------------------
class Todo {
  final int? id;
  String title;
  String dueDate;
  String assignee;
  String content;
  String attchement_url;
  bool isCompleted;

  Todo({
    this.id,
    required this.title,
    required this.dueDate,
    required this.assignee,
    required this.content,
    required this.attchement_url,
    this.isCompleted = false,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'],
      title: json['title'] ?? '',
      dueDate: json['due_date'] ?? '',
      assignee: json['assignee'] ?? '',
      content: json['content'] ?? '',
      attchement_url: json['attachment_url'] ?? '',
      // 서버에서 0, 1로 오든 true, false로 오든 대응 가능하게 처리
      isCompleted: json['is_completed'] == 1 || json['is_completed'] == true,
    );
  }
}

// ---------------------------------------------------------------------------
// 2. 메인 페이지 위젯
// ---------------------------------------------------------------------------
class TodoPage extends StatefulWidget {
  final String userName;

  const TodoPage({super.key, required this.userName});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  List<Todo> _todos = [];
  bool _isLoading = true;  

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _assigneeController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  String _selectedDate = "";

  @override
  void initState() {
    super.initState();
    _fetchTodos();
  }

  // [API] 전체 목록 가져오기
  Future<void> _fetchTodos() async {
    try {
      final response = await http.get(Uri.parse(Config.getTodos));
      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = json.decode(response.body);
        final List<dynamic> data = decodedData['data'];
        setState(() {
          _todos = data.map((item) => Todo.fromJson(item)).toList();
          _isLoading = false;
          // print("서버에서 받은 데이터 개수: ${data.length}");
          // print("첫 번째 항목의 완료 상태: ${data[0]['is_completed']}");
        });
      }
    } catch (e) {
      print("Error fetching todos: $e");
      setState(() => _isLoading = false);
    }
  }

  // [API] 스와이프 상태 변경
  Future<void> _updateStatus(Todo todo) async {
    final targetStatus = !todo.isCompleted;
    try {
      final response = await http.post(
        Uri.parse(Config.updateTodoStatus),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id": todo.id, "is_completed": targetStatus}),
      );
      if (response.statusCode == 200) {
        setState(() => todo.isCompleted = targetStatus);
      }
    } catch (e) {
      print("Error updating status: $e");
      _fetchTodos(); // 실패 시 데이터 동기화를 위해 재호출
    }
  }

  // 1. 새로운 할 일 등록 (공지사항 addNotice 로직 참고)
  Future<bool> _addTodo() async {
    try {
      final response = await http.post(Uri.parse(Config.addTodo), 
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "title": _titleController.text,
          "due_date": _selectedDate,
          "assignee": _assigneeController.text,
          "content": _contentController.text,
          "attachment_url": _urlController.text,
          "created_by": widget.userName, // 생성자에서 받은 이름 사용
        }),
      );

      // 공지사항 성공 조건(200 또는 201)과 동일하게 처리 [cite: 14]
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("등록 실패: $e");
      return false;
    }
  }

  // 2. 기존 할 일 내용 수정 (공지사항 updateNotice 로직 참고)
  Future<bool> _updateTodo(int id) async {
    try {
      final response = await http.post(
        Uri.parse(Config.updateTodoContent), // 상세 내용 수정용 상수 사용
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "id": id,
          "title": _titleController.text,
          "due_date": _selectedDate,
          "assignee": _assigneeController.text,
          "content": _contentController.text,
          "attachment_url": _urlController.text,
        }),
      );

      return response.statusCode == 200; // 성공 시 true 반환 [cite: 16]
    } catch (e) {
      print("수정 실패: $e");
      return false;
    }
  }

  // 할 일 삭제
  static Future<bool> deleteTodo(int id) async {
    try {
      final response = await http.post(
        Uri.parse(Config.deleteTodo),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": id}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("삭제 실패: $e");
      return false;
    }
  }

  // 공지사항 등록/수정 호출 방식 그대로 반영 [cite: 35, 43]
  void _openTodoEditor(Todo todo) {
    // 컨트롤러 초기화
    _titleController.text = todo.title;
    _contentController.text = todo.content;
    _assigneeController.text = todo.assignee;
    _urlController.text = todo.attchement_url;
    _selectedDate = todo.dueDate.isEmpty 
      ? DateTime.now().toString().split(' ')[0]
      : todo.dueDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // [cite: 43]
      builder: (context) {
        return StatefulBuilder( // [cite: 44]
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), // [cite: 45]
              child: _buildTodoDetail(todo, setModalState),
            );
          },
        );
      },
    );
  }

  // 삭제 확인 다이얼로그
  Future<bool> _showDeleteConfirmDialog() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('할일 삭제'),
        content: const Text('이 할일을 정말 삭제하시겠습니까?'),
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(
          title: const Text('TO-DO LIST', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: const Color(0xFF166534),
          foregroundColor: Colors.white,          
        ),
        body: Column(
          children: [
            const SizedBox(height: 12),
            // 1. 탭 바는 로딩 중에도 항상 자리를 지키고 있어야 합니다.
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
              child: TabBar(
                labelColor: const Color(0xFF166534),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF166534),
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 3,
                tabs: const [
                  Tab(height: 45, text: "진행 중"),
                  Tab(height: 45, text: "완료됨"),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 2. 데이터가 들어가는 리스트 영역만 로딩 처리를 합니다.
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF166534)), // 초록색 로딩바
                      ),
                    )
                  : TabBarView(
                      children: [
                        _buildListSection(false),
                        _buildListSection(true),
                      ],
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // 여기에 등록 다이얼로그나 페이지 이동 연결!
            _openTodoEditor(Todo(title: "", dueDate: "", assignee: "", content: "", attchement_url: ""));
          },
          backgroundColor: const Color(0xFF166534), // 공지사항과 동일한 초록색
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  // 탭별 리스트 구성
  Widget _buildListSection(bool isCompleted) {
    final list = _todos.where((t) => t.isCompleted == isCompleted).toList();

    return list.isEmpty
        ? Center(child: Text(isCompleted ? "완료된 일이 없습니다." : "할 일을 등록해 보세요!"))
        : ListView.builder(
            itemCount: list.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final todo = list[index];
              return _buildTodoItem(todo);
            },
          );
  }

  // 스와이프 가능한 리스트 아이템
  Widget _buildTodoItem(Todo todo) {
    return Dismissible(
      key: Key(todo.id.toString()),      
      // 진행중(isCompleted=false)일 때는 왼쪽->오른쪽(startToEnd)만 허용
      // 완료됨(isCompleted=true)일 때는 오른쪽->왼쪽(endToStart)만 허용
      direction: todo.isCompleted 
          ? DismissDirection.endToStart 
          : DismissDirection.startToEnd,
      // 실수 방지를 위해 60% 이상 밀어야 동작하도록 설정
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.6,
        DismissDirection.endToStart: 0.6,
      },
      background: Container(
        color: todo.isCompleted ? Colors.orange : Colors.green,
        // 한쪽 방향으로만 밀기 때문에 Alignment를 고정해줘도 됩니다.
        alignment: todo.isCompleted ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Icon(
          todo.isCompleted ? Icons.undo : Icons.check, 
          color: Colors.white,
          size: 30,
        ),
      ),
      onDismissed: (_) => _updateStatus(todo),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
        child: ListTile(
          title: Text(todo.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("마감: ${todo.dueDate} | 담당: ${todo.assignee}"),
          trailing: const Icon(Icons.chevron_right, size: 16),
          onTap: () {            
            _openTodoEditor(todo);
          }
        ),
      ),
    );
  }

  // 1. 공지사항과 동일한 방식의 상세/등록 빌더
  Widget _buildTodoDetail(Todo todo, StateSetter setModalState) {
    // todo가 비어있으면 등록, 있으면 수정 모드
    bool isEdit = todo.id != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 핸들러 (공지사항 스타일) [cite: 51]
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 완료 상태일 때만 앞에 체크 아이콘 표시
                      if (todo.isCompleted) ...[
                        const Icon(Icons.check_circle, color: Color(0xFF166534), size: 24),
                        const SizedBox(width: 8),
                      ],
                      
                      // 상황에 맞는 텍스트 출력
                      Expanded(
                        child: Text(
                          todo.isCompleted 
                              ? "할 일 상세 보기" 
                              : (isEdit ? "할 일 수정" : "새로운 할 일 등록"),
                          style: const TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis, // 혹시 제목이 너무 길면 말줄임표 처리
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 제목 입력창 [cite: 62, 63]
                  TextField(
                    controller: _titleController,
                    enabled: !todo.isCompleted,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: '할 일 제목',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // 마감일 선택 (달력) 
                  InkWell(
                    onTap: todo.isCompleted ? null : () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: isEdit ? DateTime.parse(todo.dueDate) : DateTime.now(),
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) {
                        setModalState(() {
                          _selectedDate = picked.toString().split(' ')[0];
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: "마감 기한",
                        border: OutlineInputBorder(),
                        enabled: !todo.isCompleted,
                        filled: todo.isCompleted,
                        fillColor: todo.isCompleted ? Colors.grey[100] : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDate, 
                            style: TextStyle(
                              fontSize: 16,
                              color: todo.isCompleted ? Colors.grey[600] : Colors.black87,
                            )
                          ),
                          Icon(
                            Icons.calendar_today, 
                            color: todo.isCompleted ? Colors.grey : Color(0xFF166534)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // 담당자 입력창
                  TextField(
                    controller: _assigneeController,
                    enabled: !todo.isCompleted,
                    decoration: const InputDecoration(
                      labelText: '담당자',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // 세부 내용 입력창 [cite: 69, 70]
                  TextField(
                    controller: _contentController,
                    enabled: !todo.isCompleted,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '세부 내용',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  // 첨부파일 URL 입력창
                  TextField(
                    controller: _urlController,
                    enabled: !todo.isCompleted,
                    decoration: const InputDecoration(
                      labelText: '파일 URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // 하단 버튼들 (공지사항 스타일 그대로) [cite: 79, 87]
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isEdit && !todo.isCompleted) // 수정 모드 이면서 완료되지 않은 상태 일 때만 노출
                        TextButton.icon(
                          onPressed: () async {
                            // 삭제 로직 호출 (이미 만드신 delete_todo 사용)
                            bool confirm = await _showDeleteConfirmDialog();
                            if (confirm) {
                              // ... 삭제 API 호출 ...
                              if (confirm) {
                                bool success = await deleteTodo(todo.id!);
                                if (success) {
                                  if (mounted) Navigator.pop(context); // 바텀시트 닫기
                                  await _fetchTodos(); // 목록 새로고침
                                }
                              }                                                        
                            }
                          },
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          label: const Text('삭제', style: TextStyle(color: Colors.red)),
                        ),
                      const SizedBox(width: 12),
                      
                      if(!todo.isCompleted) // 완료된 상태가 아닐 경우에만 노출
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (_titleController.text.isEmpty) return;
                            
                            // 저장/수정 API 로직 [cite: 91, 92]
                            bool success;
                            if (!isEdit) {
                              success = await _addTodo(); // 등록 API
                            } else {
                              // todo.id 뒤에 !를 붙여서 '이 ID는 절대 비어있지 않음'을 컴파일러에게 알려줍니다.
                              success = await _updateTodo(todo.id!); // 수정 API
                            }

                            if (success) {
                              if (mounted) Navigator.pop(context);
                              await _fetchTodos(); // 목록 새로고침 [cite: 95]
                            } else {
                                if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("저장에 실패했습니다. 다시 시도해주세요."))
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF166534),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          icon: const Icon(Icons.save),
                          label: Text(isEdit ? '저장하기' : '등록하기'),
                        ),
                    ],
                  ),
                  // 키보드 대응 여백 [cite: 98]
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}