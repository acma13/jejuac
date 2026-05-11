import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '/constants.dart';
import 'dart:convert'; // jsonEncode 쓰기 위해 필요.
import 'package:http/http.dart' as http; // http.post 를 쓰기 위해 필요.

class ArcherAppointment extends Appointment {
  final String manager; // 담당자 필드 추가!
  final String id;

  ArcherAppointment({
    required this.id,
    required super.startTime,
    required super.endTime,
    super.subject = '',
    super.color = Colors.lightBlue,
    super.notes,
    super.location,
    required this.manager, // 🏹 생성자에서 받기
  });
}

class AppointmentDataSource extends CalendarDataSource {
  AppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }
}

class ClubCalendarScreen extends StatefulWidget {
  final String userId;
  const ClubCalendarScreen({super.key, required this.userId});

  @override
  State<ClubCalendarScreen> createState() => _ClubCalendarScreenState();
}

class _ClubCalendarScreenState extends State<ClubCalendarScreen> {

  List<ArcherAppointment> _selectedAppointments = [];
  List<ArcherAppointment> _allAppointments = [];

  List<Color> colorOptions = [
      const Color(0xFFE53935), // 빨강
      const Color(0xFFFB8C00), // 주황
      const Color(0xFFFFEB3B), // 노랑
      const Color(0xFF43A047), // 초록
      const Color(0xFF1E88E5), // 파랑
      const Color(0xFF8E24AA), // 보라
      const Color.fromARGB(255, 120, 78, 78), // 찍은 색.
    ];

  @override
  void initState() {
    super.initState();
    
    _fetchSchedules();
  }

  // 📡 서버에서 데이터 가져오는 핵심 함수
  Future<void> _fetchSchedules() async {
    try {
      final response = await http.get(Uri.parse(Config.getSchedule));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        setState(() {          
          _allAppointments = _getDataSource(data);

          // 데이터를 가져온 후 오늘 날짜의 일정을 하단에 먼저 보여줌
          _updateSelectedAppointments(DateTime.now());
        });
      }
    } catch (e) {
      print("❌ 일정 로딩 실패: $e");
    }
  }

  // 🏹 날짜 선택 시 하단 리스트 갱신
  void _updateSelectedAppointments(DateTime date) {
    setState(() {
      _selectedAppointments = _allAppointments.where((app) {
        // 날짜 비교 (시간 제외하고 년,월,일만 비교)
        final startDate = DateTime(app.startTime.year, app.startTime.month, app.startTime.day);
        final endDate = DateTime(app.endTime.year, app.endTime.month, app.endTime.day);
        final targetDate = DateTime(date.year, date.month, date.day);
        
        return targetDate.isAtSameMomentAs(startDate) || 
               targetDate.isAtSameMomentAs(endDate) ||
               (targetDate.isAfter(startDate) && targetDate.isBefore(endDate));
      }).toList();
    });
  }

  // 서버 수정 요청.
  Future<void> _updateSchedule(Map<String, dynamic> data) async {
    try {
      // 보통 수정은 PUT이나 POST를 씁니다.
      final response = await http.post(
        Uri.parse(Config.updateSchedule), 
        body: jsonEncode(data),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("일정이 수정되었습니다.")));
        _fetchSchedules(); // 🏹 목록 새로고침
      }
    } catch (e) {
      debugPrint("❌ 수정 실패: $e");
    }
  }

  // 서버 삭제 요청.
  Future<void> _deleteSchedule(String eventId) async {
    try {
      final response = await http.post(
        Uri.parse(Config.deleteSchedule),
        body: jsonEncode({"id": eventId}),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("일정이 삭제되었습니다.")));
          Navigator.pop(context); // 수정 창까지 닫기
        }
        _fetchSchedules(); // 🏹 목록 새로고침
      }
    } catch (e) {
      debugPrint("❌ 삭제 실패: $e");
    }
  }
  // 삭제 확인 다이얼로그.
  void _showDeleteConfirmDialog(BuildContext context, String eventId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("일정 삭제"),
          content: const Text("정말 이 훈련 일정을 삭제하시겠습니까?\n삭제된 데이터는 복구할 수 없습니다."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // 취소
              child: const Text("취소", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context); // 다이얼로그 닫기
                await _deleteSchedule(eventId); // 🏹 실제 삭제 API 호출
              },
              child: const Text("삭제", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Color getForegroundTextColor(Color bgColor) {
    // 배경색의 밝기가 밝으면(light) 검정색, 어두우면(dark) 흰색 반환
    return ThemeData.estimateBrightnessForColor(bgColor) == Brightness.light
        ? Colors.black
        : Colors.white;
  }

  // 추가 바텀 시트
  void _showAddEventSheet(BuildContext context, DateTime selectedDate, String userId) {
    // 입력값을 받을 컨트롤러들
    final TextEditingController titleController = TextEditingController();
    final TextEditingController managerController = TextEditingController();
    final TextEditingController locationController = TextEditingController();
    final TextEditingController contentController = TextEditingController();

    DateTime startDate = selectedDate;
    DateTime endDate = selectedDate;

    Color selectedColor = Colors.blue;
    bool useAlarm = false;

    // List<Color> colorOptions = [
    //   const Color(0xFFE53935), // 빨강
    //   const Color(0xFFFB8C00), // 주황
    //   const Color(0xFFFFEB3B), // 노랑
    //   const Color(0xFF43A047), // 초록
    //   const Color(0xFF1E88E5), // 파랑
    //   const Color(0xFF8E24AA), // 보라
    //   const Color.fromARGB(255, 120, 78, 78), // 찍은 색.
    // ];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 키보드가 올라와도 화면이 가려지지 않게 설정
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // 바텀 시트 내부에서 화면을 갱신하기 위해 StatefulBuilder 사용
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("새 일정 만들기", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),

                    // 🏹 시작일 선택 행
                    ListTile(
                      title: const Text("시작일"),
                      trailing: Text("${startDate.year}-${startDate.month}-${startDate.day}"),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setSheetState(() => startDate = picked); // 시트 내부 UI 갱신
                        }
                      },
                    ),

                    // 🏹 종료일 선택 행
                    ListTile(
                      title: const Text("종료일"),
                      trailing: Text("${endDate.year}-${endDate.month}-${endDate.day}"),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: endDate,
                          firstDate: startDate, // 시작일보다 이전일 순 없음
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setSheetState(() => endDate = picked);
                        }
                      },
                    ),

                    TextField(controller: titleController, decoration: const InputDecoration(labelText: "일정 제목")),
                    TextField(controller: managerController, decoration: const InputDecoration(labelText: "담당자")),
                    TextField(controller: locationController, decoration: const InputDecoration(labelText: "장소")),
                    TextField(controller: contentController, decoration: const InputDecoration(labelText: "상세 내용"), maxLines: 3),
                    // ... 나머지 TextField들 ...

                    const SizedBox(height: 20),

                    // 색상 선택
                    const Text("일정 색상", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center, // 🔥 이게 핵심! 가운데로 모아줍니다.
                      children: colorOptions.map((color) {
                        final bool isSelected = selectedColor == color;
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedColor = color),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5), // 좌우 간격 살짝
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              // 선택 시 검정 테두리, 미선택 시 아주 연한 회색 테두리 (구분용)
                              border: isSelected 
                                  ? Border.all(color: Colors.black, width: 2.5) 
                                  : Border.all(color: Colors.black12, width: 1),
                            ),
                            // 선택되었을 때만 체크 표시
                            child: isSelected
                                ? Icon(Icons.check, color: getForegroundTextColor(color), size: 20)
                                : null,
                          ),
                        );
                      }).toList(), // 여기서 .toList()는 에러 안 납니다! (Spread Operator ...가 없으니까요)
                    ),

                    const SizedBox(height: 15),
                  
                    SwitchListTile(
                      title: const Text("알림 설정"),
                      value: useAlarm,
                      thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.selected)) return const Color(0xFF166534);
                        return Colors.white;
                      }),
                      trackColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.selected)) return const Color(0xFF166534).withValues(alpha: 0.5);
                        return Colors.grey.shade300;
                      }),
                      onChanged: (val) => setSheetState(() => useAlarm = val),
                    ),

                    const SizedBox(height: 20),

                    // 저장 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF166534)),
                        onPressed: () async {
                          // 1. 데이터 준비 (DB 구조에 딱 맞게!)
                          Map<String, dynamic> data = {
                            "userid": userId,       // 등록자 아이디
                            "title": titleController.text,
                            "location": locationController.text,
                            "manager": managerController.text,
                            "content": contentController.text,
                            "start_date": startDate.toIso8601String().split('T')[0], // "2026-04-03"
                            "end_date": endDate.toIso8601String().split('T')[0],
                            "color": selectedColor.toARGB32(),  // 색상을 정수(int)로 저장
                            "use_alarm": useAlarm ? 1 : 0, // 알람 켜면 1, 끄면 0
                          };

                          try {
                            final response = await http.post(
                              Uri.parse(Config.addSchedule), // 아까 만든 constants 주소
                              headers: {"Content-Type": "application/json"},
                              body: jsonEncode(data),
                            );

                            print("상태코드: ${response.statusCode}");
                            print("userId : $userId");

                            
                            if (response.statusCode == 200) {
                              print("서버 저장 완료!");
                              Navigator.pop(context); // 입력창 닫기
                              _fetchSchedules(); // 달력리스트 새로 고침                                                           
                            }                            
                          } catch (e) {
                            print("통신 에러: $e");
                          }
                        },
                        child: const Text("일정 저장", style: TextStyle(color: Colors.white)),
                      ),
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

  // 수정 바텀 시트
  void _showEditEventSheet(BuildContext context, ArcherAppointment app) {
    // 1. 기존 데이터로 입력창 초기화
    final titleController = TextEditingController(text: app.subject);
    final managerController = TextEditingController(text: app.manager);
    final locationController = TextEditingController(text: app.location);
    final contentController = TextEditingController(text: app.notes);

    DateTime startDate = app.startTime;
    DateTime endDate = app.endTime;
    Color selectedColor = app.color;
    bool useAlarm = true; // DB 설계에 따라 app.useAlarm 등으로 변경 가능

    // final List<Color> colorOptions = [
    //   const Color(0xFFE53935), const Color(0xFFFB8C00), const Color(0xFFFFEB3B),
    //   const Color(0xFF43A047), const Color(0xFF1E88E5), const Color(0xFF8E24AA),
    //   const Color(0xFF784E4E),
    // ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: Text("🎯 일정 수정", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 20),

                    // 📝 제목 & 담당자 & 장소
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: "일정 제목", prefixIcon: Icon(Icons.title))),
                    TextField(controller: managerController, decoration: const InputDecoration(labelText: "담당자", prefixIcon: Icon(Icons.person))),
                    TextField(controller: locationController, decoration: const InputDecoration(labelText: "장소", prefixIcon: Icon(Icons.location_on))),
                    TextField(controller: contentController, decoration: const InputDecoration(labelText: "상세 내용", prefixIcon: Icon(Icons.notes)), maxLines: 2),

                    const SizedBox(height: 20),

                    // 📅 일정 (시작일 ~ 종료일)
                    const Text("📅 일정 설정", style: TextStyle(fontWeight: FontWeight.bold)),
                    ListTile(
                      title: const Text("시작일"),
                      trailing: Text("${startDate.year}-${startDate.month}-${startDate.day}"),
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: startDate, firstDate: DateTime(2025), lastDate: DateTime(2030));
                        if (picked != null) setSheetState(() => startDate = picked);
                      },
                    ),
                    ListTile(
                      title: const Text("종료일"),
                      trailing: Text("${endDate.year}-${endDate.month}-${endDate.day}"),
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: endDate, firstDate: startDate, lastDate: DateTime(2030));
                        if (picked != null) setSheetState(() => endDate = picked);
                      },
                    ),

                    const SizedBox(height: 10),

                    // 🎨 라벨 색상 선택
                    const Text("🎨 라벨 색상", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: colorOptions.map((color) {
                        final bool isSelected = selectedColor == color;
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedColor = color),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: 35, height: 35,
                            decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: Colors.black, width: 2.5) : Border.all(color: Colors.black12, width: 1),
                            ),
                            child: isSelected ? Icon(Icons.check, color: getForegroundTextColor(color), size: 18) : null,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 10),

                    // 🔔 알림 설정 (Material 3 최신 규격)
                    SwitchListTile(
                      title: const Text("알림 받기"),
                      value: useAlarm,
                      thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.selected)) return const Color(0xFF166534);
                        return Colors.white;
                      }),
                      trackColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.selected)) return const Color(0xFF166534).withValues(alpha: 0.5);
                        return Colors.grey.shade300;
                      }),
                      onChanged: (val) => setSheetState(() => useAlarm = val),
                    ),

                    const SizedBox(height: 20),

                    // 💾 수정 완료 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF166534), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () async {
                          final updateData = {
                            "id": app.id, // 👈 ArcherAppointment 모델에 ID가 꼭 있어야 합니다!
                            "title": titleController.text,
                            "manager": managerController.text,
                            "location": locationController.text,
                            "content": contentController.text,
                            "start_date": startDate.toIso8601String(),
                            "end_date": endDate.toIso8601String(),
                            "color": selectedColor.toARGB32(), 
                            "use_alarm": useAlarm ? 1 : 0,
                          };
                          await _updateSchedule(updateData);
                          if (!context.mounted) return; // 화면이 아직 떠 있는지 체크
                          Navigator.pop(context); // 화면이 살아 있을 때만 팝업 닫기
                          _fetchSchedules(); // 목록 새로고침
                        },
                        child: const Text("수정 완료", style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                    // 삭제 버튼
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          _showDeleteConfirmDialog(context, app.id);
                        },
                        child: const Text("이 일정 삭제하기", style: TextStyle(color: Colors.red)),
                      ),
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

  // 데이터 가져와서 트럭에 넣어주기 
  List<ArcherAppointment> _getDataSource(List<dynamic> serverData) {
    return serverData.map((item) {
      
      // 🏹 DB에 저장된 4280191205 같은 숫자를 가져옵니다.
      // 만약 데이터가 String으로 오면 int.parse를 쓰고, 아니면 바로 형변환 합니다.
      int colorValue = int.tryParse(item['color'].toString()) ?? 4281358132; // 기본값(초록)

      return ArcherAppointment(
        id: item['id'].toString(),
        subject: item['title'] ?? '제목 없음',
        startTime: DateTime.parse(item['start_date']),
        endTime: DateTime.parse(item['end_date']),
        location: item['location'] ?? '',
        manager: item['manager'] ?? '',
        notes: item['content'] ?? '',
        // 🎨 숫자 값을 그대로 Color 객체로 변환!
        color: Color(colorValue), 
      );
    }).toList();
  }  

  // -------------------------------------------------------------------------------
  // 화면 빌드(widget build)
  // -------------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("클럽 일정"),
        backgroundColor: const Color(0xFF166534),
        foregroundColor: Colors.white,
      ),
      // 🏹 전체를 스크롤 가능하게 감싸서 달력이 안 찌그러지게 합니다.
      body: SingleChildScrollView( 
        child: Column(
          children: [
            // 1. 달력 영역 (높이를 고정해서 찌그러짐 방지!)
            SizedBox(
              height: 600, // 🏹 영님 화면에 맞춰서 높이를 시원하게 고정하세요!
              child: SfCalendar(
                view: CalendarView.month,
                backgroundColor: const Color(0xFFF5F5F5),
                todayHighlightColor: const Color(0xFF166534),
                cellBorderColor: Colors.white,
                
                dataSource: AppointmentDataSource(_allAppointments),
                monthViewSettings: const MonthViewSettings(
                  showTrailingAndLeadingDates: false,                                  
                  showAgenda: false, 
                  monthCellStyle: MonthCellStyle(
                    textStyle: TextStyle(fontSize: 13, color: Colors.black87),
                    backgroundColor: Color(0xFFE0E0E0),
                  ),
                  appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
                  appointmentDisplayCount: 3,
                ),

                appointmentBuilder: (context, details) {
                  final Appointment appointment = details.appointments.first;
                  return Container(
                    width: details.bounds.width,
                    height: details.bounds.height,
                    decoration: BoxDecoration(
                      color: appointment.color.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      appointment.subject,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: getForegroundTextColor(appointment.color),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },                

                // 날짜를 길게 누르면 일정 추가 기능 팝업
                onLongPress:(CalendarLongPressDetails details) {
                  if (details.targetElement == CalendarElement.calendarCell && details.date != null) {
                  // 꾹 누른 날짜 정보를 가지고 입력창을 띄웁니다.
                  _showAddEventSheet(context, details.date!, widget.userId);
                  }
                },
                
                // 날짜를 누르면 디테일일정이 나오고 일정을 클릭하면 수정창이 나오도록 함.
                onTap: (CalendarTapDetails details) {
                  // 1. 일정 Bar를 클릭했을 때만 실행                  
                  if (details.targetElement == CalendarElement.appointment) {
                    if (details.appointments != null && details.appointments!.isNotEmpty) {
                      // 클릭한 일정을 가져와서 수정 창 띄우기
                      final ArcherAppointment selectedApp = details.appointments!.first as ArcherAppointment;
                      _showEditEventSheet(context, selectedApp);
                    }
                  }
                  // 2. 빈 날짜 클릭했을 때
                  if (details.targetElement == CalendarElement.calendarCell) {
                    setState(() {
                      // 클릭한 날짜에 있는 일정들만 뽑아서 변수에 넣기
                      _selectedAppointments = details.appointments?.cast<ArcherAppointment>() ?? [];
                    });
                  }                  
                },               
              ),
            ),

            // 2. 구분선 (유럽 돌담 느낌 살려서)
            const Divider(height: 1, color: Colors.grey),

            // 3. 하단 상세 리스트 영역 (여기에 매니저, 장소 다 때려 넣기!)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedAppointments.isEmpty ? "일정이 없습니다." : "📜 상세 일정", 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF166534))
                  ),
                  const SizedBox(height: 10),
                  
                  // 선택된 일정 개수만큼 카드를 자동으로 생성
                  //_buildDetailCard("필드 훈련", "김코치", "제주 양궁장", "오전 9시 70m 사로 집합"), << 이건 테스트용 하드코딩
                  ..._selectedAppointments.map((app) {
                    String startDate = app.startTime.toString().split(' ')[0];
                    String endDate = app.endTime.toString().split(' ')[0];                    
                    
                    return _buildDetailCard(
                      app.subject,                    
                      startDate, endDate,
                      app.manager,
                      app.location ?? "장소미정",
                      app.notes ?? "상세 내용 없음",
                    );
                  }),                  
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🏹 상세 내용을 보여줄 예쁜 카드 위젯 (영님 스타일로 둥글게!)
  Widget _buildDetailCard(String subject, String startDate, String endDate, String manager, String location, String notes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [          
          Text(subject, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(height: 20),
          Text("📅 일정: $startDate ~ $endDate", style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          Text("📍 장소: $location", style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          Text("👤 담당자: $manager", style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          Text("📝 내용: $notes", style: const TextStyle(fontSize: 14, color: Colors.black54)),
        ],
      ),
    );
  }
  
}