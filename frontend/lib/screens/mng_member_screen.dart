import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert'; // jsonEncode 쓰기 위해 필요.
import 'package:http/http.dart' as http; // http.post 를 쓰기 위해 필요.
import '/constants.dart';
import 'package:frontend/utils/formatters.dart';

class MngMemberScreen extends StatefulWidget {
  final String userId;

  const MngMemberScreen({super.key, required this.userId});

  @override
  // ignore: library_private_types_in_public_api
  _MngMemberScreenState createState() => _MngMemberScreenState();
}

class _MngMemberScreenState extends State<MngMemberScreen> {
  // 1. 원본 데이터 (나중에 DB에서 가져올 데이터)
  List<Map<String, dynamic>> members = [];
  // 서버에서 회원 목록 가져오기
  Future<void> fetchMembers() async {
    try {
      final response = await http.get(Uri.parse(Config.getMembersInfo));
      if (response.statusCode == 200) {
        setState(() {
          // 서버에서 받아온 데이터를 members 리스트에 업데이트
          members = List<Map<String, dynamic>>.from(json.decode(response.body));
        });
      }
    } catch (e) {
      print("데이터 로딩 실패: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    fetchMembers(); // 화면 시작하자마자 데이터 가져오기
  }

  // 2. 필터 및 정렬 상태 변수
  String searchQuery = "";  
  bool isAscending = true;
  String selectedClass = "전체";
  String selectedStatus = "전체";
  int sortColumnIndex = 0;

  // 3. 필터링 로직: 화면에 보여줄 리스트를 실시간으로 계산
  List<Map<String, dynamic>> get _filteredMembers {
    return members.where((m) {
      final nameMatch = m['name'].contains(searchQuery) || m['phone'].contains(searchQuery);
      final classMatch = (selectedClass == "전체") || (m['class'] == selectedClass); 

      bool statusMatch = true;
      if (selectedStatus == "활동중") statusMatch = (m['isActive'] == true);
      if (selectedStatus == "비활동") statusMatch = (m['isActive'] == false);
    
      return nameMatch && classMatch && statusMatch;
    }).toList();
  }

  // 4. 정렬 로직
  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      sortColumnIndex = columnIndex;
      isAscending = ascending;
      
      // 이름 기준으로 정렬 (0번째 컬럼)
      if (columnIndex == 0) {
        members.sort((a, b) => ascending 
            ? a['name'].compareTo(b['name']) 
            : b['name'].compareTo(a['name']));
      }
    });
  }
  // ----------- 버튼 처리 (DB 관련 로직) ---------------
  // 회원 등록 저장 로직
  Future<void> _saveMemberToServer(String name, String phone, String birth, String memberClass, bool isActive) async {
    if (name.isEmpty || birth.isEmpty) {
      // 간단한 유효성 검사
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("이름과 생년월일은 필수입니다.")));
      return;
    }

    final response = await http.post(
      Uri.parse(Config.addMember),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "name": name,
        "phone": phone,
        "birth": birth,
        "member_class": memberClass,
        "is_active": isActive,
        "created_by": widget.userId,
      }),
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      Navigator.pop(context); // 팝업 닫기
      fetchMembers(); // 목록 새로고침
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("회원이 등록되었습니다.")));
    } else if (response.statusCode == 400) {
      // 우리가 설정한 중복 에러 처리
      final errorData = json.decode(utf8.decode(response.bodyBytes));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorData['detail'])));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("등록 실패: 서버 오류")));
    }
  }

  // -------------- 화면 빌드 영역 ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원 관리'),
        backgroundColor: Colors.green[800],
        elevation: 0, // 필터바와 자연스럽게 연결되도록
      ),
      body: Column(
        children: [
          // 1. 상단 라운딩 검색바
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: "이름, 연락처 검색",
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => searchQuery = value),
              ),
            ),
          ),
          
          // 2. 표 영역 (카드 디자인 적용)
          Expanded(
            child: members.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.group_off, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      "등록된 회원이 없습니다.",
                      style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text("우측 하단 + 버튼을 눌러 회원을 등록해주세요.",
                        style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              )
              :  SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  clipBehavior: Clip.antiAlias, // 카드 모서리에 맞춰 표 깎기
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      sortColumnIndex: sortColumnIndex,
                      sortAscending: isAscending,
                      showCheckboxColumn: false,
                      // --- 헤더 디자인 ---
                      headingRowColor: WidgetStateProperty.all(Colors.green[800]),
                      headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      columnSpacing: 25,
                      columns: [
                        DataColumn(
                          label: const Text('이름'),
                          onSort: _onSort,
                        ),
                        const DataColumn(label: Text('연락처')),
                        DataColumn(
                          label: Row(
                            children: [
                              const Text('클래스'),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.filter_alt_outlined, size: 18, color: Colors.white70),
                                onSelected: (value) => setState(() => selectedClass = value),
                                itemBuilder: (context) => ["전체", "선수반", "취미반"].map((v) => 
                                  PopupMenuItem(value: v, child: Text(v))
                                ).toList(),
                              ),
                            ],
                          ),
                        ),
                        const DataColumn(label: Text('생년월일')),
                        DataColumn(
                          label: Row(
                            children: [
                              const Text('활동여부'),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.filter_alt_outlined, size: 18, color: Colors.white70),
                                onSelected: (value) => setState(() => selectedStatus = value),
                                itemBuilder: (context) => ["전체", "활동중", "비활동"].map((v) => 
                                  PopupMenuItem(value: v, child: Text(v))
                                ).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // --- 행 디자인 (줄무늬 효과 적용) ---
                      rows: _filteredMembers.asMap().entries.map((entry) {
                        int index = entry.key;
                        var member = entry.value;
                        
                        return DataRow(
                          onSelectChanged: (_) => _showMemberDetail(member),
                          // 짝수 줄에만 아주 연한 녹색 배경을 줘서 줄무늬 효과
                          color: WidgetStateProperty.all(index % 2 == 0 ? Colors.white : Colors.green.withValues(alpha: 0.05)),
                          cells: [
                            DataCell(Text(member['name'] ?? "이름 없음", style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(member['phone'] ?? "연락처 없음")),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  // 1. null 체크: member['class']가 null이면 '취미반'으로 가정하고 비교
                                  color: (member['class'] ?? '취미반') == '선수반' ? Colors.orange[50] : Colors.blue[50],
                                  borderRadius: BorderRadius.circular(12),
                                  // 2. ! 대신 ?? 를 사용하여 null일 때 안전하게 기본 색상을 지정
                                  border: Border.all(
                                    color: (member['class'] ?? '취미반') == '선수반' 
                                        ? (Colors.orange[200] ?? Colors.orange) 
                                        : (Colors.blue[200] ?? Colors.blue)
                                  ),
                                ),
                                child: Text(
                                  // 3. Text 위젯에 null이 들어가지 않도록 기본값 처리
                                  member['class'] ?? '취미반',
                                  style: TextStyle(
                                    fontSize: 12, 
                                    color: (member['class'] ?? '취미반') == '선수반' ? Colors.orange[900] : Colors.blue[900]
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(member['birth'])),
                            DataCell(
                              Icon(
                                // DB의 1을 true로 인식하게 만듦
                                (member['is_active'] == 1 || member['is_active'] == true) 
                                    ? Icons.check_circle 
                                    : Icons.remove_circle,
                                color: (member['is_active'] == 1 || member['is_active'] == true) 
                                    ? Colors.green 
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNewMember(),
        backgroundColor: Colors.green[800],
        child: const Icon(Icons.add),
      ),
    );
  }

  // 회원 상세 보기 (수정/삭제)
  void _showMemberDetail(Map<String, dynamic> member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('회원 정보 수정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Divider(),
            // 이름, 연락처, 생년월일, 클래스 입력 필드들이 들어갈 자리 (일정 수정과 동일 로직)
            Text('이름: ${member['name']}'),
            Text('연락처: ${member['phone']}'),
            Text('생년월일: ${member['birth']}'),
            Text('클래스: ${member['class']}'),
            
            SizedBox(height: 30),
            Container(
              padding: EdgeInsets.all(15),
              color: Colors.grey[200],
              width: double.infinity,
              child: Text('💳 결제 정보: 개발 중인 기능입니다.', style: TextStyle(color: Colors.blueGrey)),
            ),
            
            Spacer(),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), child: Text('수정'))),
                SizedBox(width: 10),
                Expanded(child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text('삭제'))),
              ],
            )
          ],
        ),
      ),
    );
  }
  // 신규 회원 등록
  void _addNewMember() {
    // 입력값을 제어하기 위한 컨트롤러들
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController birthController = TextEditingController();
    String tempSelectedClass = "취미반";
    bool tempIsActive = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 키보드가 올라와도 화면이 가려지지 않게 설정
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) {
        return StatefulBuilder( // 바텀 시트 안에서 스위치나 드롭다운 상태를 바꾸기 위함
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, // 키보드 높이만큼 패딩
                left: 20, right: 20, top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50, height: 5,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text("새 회원 등록", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[800])),
                    const SizedBox(height: 20),

                    // 1. 이름 입력
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: '이름', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                    ),
                    const SizedBox(height: 15),

                    // 2. 연락처 입력
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly, // 숫자만 입력 가능하게
                        LengthLimitingTextInputFormatter(11),   // 최대 11자리
                        PhoneNumberFormatter(),                 // 하이픈 자동 생성 (utils에서 가져온 것)
                      ],
                      decoration: const InputDecoration(labelText: '연락처 (010-0000-0000)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                    ),
                    const SizedBox(height: 15),

                    // 3. 생년월일 입력
                    TextField(
                      controller: birthController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly, // 숫자만 입력 가능하게
                        LengthLimitingTextInputFormatter(8),   // 최대 8자리
                        BirthDateFormatter(),                 // 하이픈 자동 생성 (utils에서 가져온 것)
                      ],
                      decoration: const InputDecoration(labelText: '생년월일 (8자리: 19900101)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.cake)),
                    ),
                    const SizedBox(height: 15),

                    // 4. 클래스 선택 & 활동 여부
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: tempSelectedClass,
                            decoration: const InputDecoration(labelText: '클래스', border: OutlineInputBorder()),
                            items: ["선수반", "취미반"].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                            onChanged: (value) => setModalState(() => tempSelectedClass = value!),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          children: [
                            const Text("활동여부", style: TextStyle(fontSize: 12)),
                            Switch(
                              value: tempIsActive,
                              activeThumbColor: Colors.green,
                              onChanged: (value) => setModalState(() => tempIsActive = value),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // 5. 등록 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          // 여기서 서버로 데이터 전송! (함수는 아래 따로 작성)
                          await _saveMemberToServer(
                            nameController.text,
                            phoneController.text,
                            birthController.text,
                            tempSelectedClass,
                            tempIsActive,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[800],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("등록하기", style: TextStyle(color: Colors.white, fontSize: 16)),
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
}