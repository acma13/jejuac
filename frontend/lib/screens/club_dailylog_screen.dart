import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/constants.dart';
import 'dart:convert'; // jsonEncode 쓰기 위해 필요.
import 'package:http/http.dart' as http; // http.post 를 쓰기 위해 필요.
import 'package:table_calendar/table_calendar.dart';

class ClubDailylogScreen extends StatefulWidget {
  final String userRole;
  final String userId;
  final String userName;

  const ClubDailylogScreen({
    super.key,
    required this.userRole,
    required this.userId,
    required this.userName,
  });

  @override
  State<ClubDailylogScreen> createState() => _ClubDailylogScreenState();
}

class _ClubDailylogScreenState extends State<ClubDailylogScreen> {
  DateTime _selectedDate = DateTime.now(); // 사용자가 콕 찍은 날짜
  DateTime _focusedDate = DateTime.now();  // 달력이 현재 포커스하고 있는 월(Month) 기준 날짜
  bool _isExpanded = false; // 기본 주간 뷰 모드
  // 백엔드 getMonthlyMarkers에서 받아온 '데이터가 존재하는 날짜 목록'을 담을 리스트
  List<String> _markedDates = [];
  // 선택한 날짜에 작성된 일지 목록을 저장할 리스트 (피드 카드 리스트 바인딩용)
  List<dynamic> _dayLogs = [];
  // 🎯 로딩 상태를 관리할 변수 추가 (기본값 true)
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  // 🎯 마커와 일지 데이터를 동시에 다 가져올 때까지 기다린 후 로딩을 끄는 함수
  Future<void> _initData() async {
    setState(() => _isLoading = true);
    
    // 두 대기 작업을 동시에 실행해서 병렬로 빠르게 처리합니다.
    await Future.wait([
      _fetchMarkers(_focusedDate.year, _focusedDate.month),
      _fetchLogForDate(_selectedDate),
    ]);

    if (mounted) {
      setState(() => _isLoading = false); // 🎯 데이터 로딩 완료!
    }
  }

  // 달력 날짜를 찍어서 단건 갱신할 때 쓰는 용도
  Future<void> _refreshDayLog(DateTime date) async {
    setState(() => _isLoading = true);
    await _fetchLogForDate(date);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }


  // ① 특정 월의 마커 리스트 가져오기 (달력 넘길 때마다 호출)
  Future<void> _fetchMarkers(int year, int month) async {
    try {
      final String monthStr = month.toString().padLeft(2, '0');
      final url = Uri.parse("${Config.getMonthlyMarkers}?year=$year&month=$monthStr");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(utf8.decode(response.bodyBytes));
        if (decodedData['success'] == true) {
          setState(() {
            _markedDates = List<String>.from(decodedData['markers']);
          });
        }
      }
    } catch (e) {
      print("❌ 마커 가져오기 실패: $e");
    }
  }

  // ② 선택한 날짜의 일지 상세 내용 가져오기
  Future<void> _fetchLogForDate(DateTime date) async {
    try {
      final String dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final url = Uri.parse("${Config.getClubDailylogs}?date=$dateStr");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(utf8.decode(response.bodyBytes));
        if (decodedData['success'] == true) {
          setState(() {
            // 백엔드가 주는 data가 배열(List) 형태이므로 그대로 담아줍니다.
            // 만약 비어있다면 빈 리스트([])로 안전하게 대입합니다.
            if (decodedData['data'] != null && decodedData['data'] is List) {
              _dayLogs = decodedData['data'];
            } else if (decodedData['data'] != null) {
              // 혹시 백엔드가 단건 객체로 보내는 예외 상황 방어용
              _dayLogs = [decodedData['data']];
            } else {
              _dayLogs = [];
            }
          });
        }
      }
    } catch (e) {
      print("❌ 일지 조회 실패: $e");
    }
  }

  // ③ 일지 등록 (POST)
  Future<void> _addLog(String title, String content) async {
    try {
      final String dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      final url = Uri.parse(Config.addClubDailylog);
      
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "log_date": dateStr,
          "title": title,
          "content": content,
          "userid": widget.userId,
          "username": widget.userName
        }),
      );

      if (response.statusCode == 200) {
        _refreshData();
      }
    } catch (e) {
      print("❌ 일지 등록 실패: $e");
    }
  }

  // ④ 일지 수정 (POST)
  Future<void> _updateLog(int id, String title, String content) async {
    try {
      final url = Uri.parse(Config.updateClubDailylog);
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": id,
          "title": title,
          "content": content,
        }),
      );

      if (response.statusCode == 200) {
        _refreshData();
      }
    } catch (e) {
      print("❌ 일지 수정 실패: $e");
    }
  }

  // ⑤ 일지 삭제 (POST)
  Future<void> _deleteLog(int id) async {
    try {
      final url = Uri.parse(Config.deleteClubDailylog);
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": id}),
      );

      if (response.statusCode == 200) {
        _refreshData();
      }
    } catch (e) {
      print("❌ 일지 삭제 실패: $e");
    }
  }

  // 데이터 갱신 공통 처리
  void _refreshData() {
    _fetchMarkers(_focusedDate.year, _focusedDate.month);
    _fetchLogForDate(_selectedDate);
  }

  // 🎯 접이식 가변 달력 UI 구현
  Widget _buildFlexibleCalendar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      height: _isExpanded ? 370 : 95, // 헤더가 위로 빠졌으므로 순수 달력 알맹이 높이만 컴팩트하게 조절
      color: Colors.white,
      // 애니메이션 도중 그릇 밖으로 튀어나오는 찌꺼기 픽셀을 물리적으로 커팅해 줍니다.
      clipBehavior: Clip.hardEdge,
      child: TableCalendar(
        locale: 'ko_KR',
        firstDay: DateTime.utc(2025, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDate,
        selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
        calendarFormat: _isExpanded ? CalendarFormat.month : CalendarFormat.week,
        headerVisible: false,
        // 좌우 스와이프 제스처 활성화 (주간 상태에선 한주씩, 월간에선 한달씩 이동)
        availableGestures: AvailableGestures.horizontalSwipe,           
        daysOfWeekHeight: 22,
        rowHeight: 52,          
        headerStyle: HeaderStyle(
          formatButtonVisible: false, // 뷰 전환 버튼 숨김
          titleCentered: true,        // 타이틀 중앙 정렬
          leftChevronVisible: false,  // 왼쪽 화살표 숨김
          rightChevronVisible: false, // 오른쪽 화살표 숨김
          headerPadding: EdgeInsets.zero, // 패딩을 없애서 영역 최소화
        ),
        onFormatChanged: (format) {
          setState(() {
            _isExpanded = (format == CalendarFormat.month);
          });
        },          
        // 🎯 스와이프로 주/월이 변경될 때 상단 연월 텍스트와 마커를 동기화합니다.
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDate = focusedDay;
          });
          // 월이 바뀐 경우에만 백엔드에서 마커를 새로 긁어옵니다.
          _fetchMarkers(focusedDay.year, focusedDay.month);
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDate = selectedDay;
            _focusedDate = focusedDay;
            _isExpanded = false; 
          });
          _refreshDayLog(selectedDay);
        },
        eventLoader: (day) {
          final dayStr = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
          return _markedDates.contains(dayStr) ? ['has_data'] : [];
        },
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isNotEmpty) {
              return Positioned(
                bottom: 4,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFF166534), 
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }
            return null;
          },
          todayBuilder: (context, date, focusedDay) {
            return Container(
              margin: const EdgeInsets.all(8),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFF166534),
                shape: BoxShape.circle,
              ),
              child: Text(
                date.day.toString(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            );
          },
          selectedBuilder: (context, date, focusedDay) {
            return Container(
              margin: const EdgeInsets.all(8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // 💡 오늘 날짜(진한 녹색)와 구분되도록, 선택된 날짜는 연한 녹색 바탕으로 지정합니다.
                color: const Color(0xFF166534).withValues(alpha: 0.2), 
                shape: BoxShape.circle,
                // 만약 채우는 원 말고 '테두리 선만 있는 원'을 원하시면 아래 주석을 풀고 color를 빼시면 됩니다.
                // border: Border.all(color: const Color(0xFF166534), width: 1.5),
              ),
              child: Text(
                date.day.toString(),
                style: const TextStyle(
                  color: Color(0xFF166534), // 글자색도 깔끔하게 클럽 그린으로 통일
                  fontWeight: FontWeight.bold, 
                  fontSize: 14,
                ),
              ),
            );
          },
        ),
      ),
    );   
  }

  // 등록 / 상세 / 수정 / 삭제 통합 처리 바텀시트
  void _openLogBottomSheet({Map<String, dynamic>? log}) {
    final bool isEditMode = log != null;
    final TextEditingController titleController = TextEditingController(text: isEditMode ? log['title'] : '');
    final TextEditingController contentController = TextEditingController(text: isEditMode ? log['content'] : '');

    final String logDateStr = DateFormat('yyyy.MM.dd').format(_selectedDate);

    // 🎯 권한 제어 조건 분기
    final bool isAuthor = isEditMode && (log['userid'] == widget.userId);
    final bool isAdmin = widget.userRole == 'Admin';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        // 바텀시트의 전체 최대 높이를 화면 높이의 65%로 고정
        final double availableHeight = MediaQuery.of(context).size.height * 0.65;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20, left: 16, right: 16,
          ),
          child: SizedBox(
            height: availableHeight,
            child: Column(              
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditMode ? "클럽일지 상세 ($logDateStr)" : "클럽일지 등록 ($logDateStr)",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (isEditMode && (isAuthor || isAdmin))
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {                          
                          _showDeleteConfirmDialog(context, log['id']);
                        },
                      )
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  // enabled: !isEditMode || isAuthor, // 본인 글이 아니면 읽기전용
                  readOnly: isEditMode && !isAuthor,
                  decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                if (isEditMode) ...[
                  Text("작성자: ${log['username']}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 12),
                ],
                Expanded(                  
                  child: TextField(
                    controller: contentController,                    
                    readOnly: isEditMode && !isAuthor,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,                    
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: '내용', 
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true, // 라벨 텍스트도 맨 위에 고정
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // 본인 글이거나 신규 등록 모드일 때만 하단 완료 버튼 활성화
                if (!isEditMode || isAuthor)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) return;
                        if (isEditMode) {
                          _updateLog(log['id'], titleController.text, contentController.text);
                        } else {
                          _addLog(titleController.text, contentController.text);
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF166534)),
                      child: Text(isEditMode ? '수정 완료' : '등록 완료', style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // 삭제 확인 다이얼로그.
  void _showDeleteConfirmDialog(BuildContext context, int eventId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("일지 삭제"),
          content: const Text("정말 이 클럽 일지를 삭제하시겠습니까?\n삭제된 데이터는 복구할 수 없습니다."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), // 취소
              child: const Text("취소", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(dialogContext); // 다이얼로그 닫기
                Navigator.pop(context);
                await _deleteLog(eventId); // 🏹 실제 삭제 API 호출
              },
              child: const Text("삭제", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedSelectedDate = DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_selectedDate);
    String currentYearMonth = DateFormat('yyyy년 MM월', 'ko_KR').format(_focusedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('클럽일지'),
        backgroundColor: const Color(0xFF166534),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 상단 연월 표시 및 달력 확장/축소 버튼 바
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currentYearMonth,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                // 버튼을 누르면 월간 ↔ 주간이 토글됩니다.
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF166534),
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
              ],
            ),
          ),
          _buildFlexibleCalendar(),
          const Divider(height: 1),

          // 🎯 주단위 달력 아래 고정된 오늘 날짜 / 선택 날짜 텍스트바
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[50],
            child: Text(
              formattedSelectedDate,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),

          // 🎯 피드 카드 리스트 본문 영역
          Expanded(
            child: _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF166534), // 클럽 그린 색상 뱅글뱅글이
                ),
              )
              : _dayLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_stories, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('작성된 클럽일지가 없습니다.', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    itemCount: _dayLogs.length,
                    itemBuilder: (context, index) {
                      final log = _dayLogs[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            log['title'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text("작성자: ${log['username']}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          // 카드를 탭하면 상세 조회 및 권한별 수정/삭제 분기 바텀시트 열림
                          onTap: () => _openLogBottomSheet(log: log),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      
      // 하단 우측 일지 등록용 플로팅 액션 버튼
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openLogBottomSheet(), 
        backgroundColor: const Color(0xFF166534),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }
}  


