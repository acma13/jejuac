import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '/constants.dart';

class Member {
  final String id;
  final String name;
  Member({required this.id, required this.name});
  String get displayName => name;
}

class PaymentInfo {
  final int? id;          // 등록 시에는 null, 수정 시에는 필수
  final String name;      // 회원 이름
  final String payItem;   // 결제 항목 (식대, 유류비 등)
  final int amount;       // 금액 (정수)
  final bool isPaid;      // 결제 여부
  final String? payMethod;  // 결제 방법
  final String? note;     // 비고
  final String? targetMonth; // 대상 연월 (yyyy-MM)

  PaymentInfo({
    this.id,
    required this.name,
    required this.payItem,
    required this.amount,
    required this.isPaid,
    this.payMethod,
    this.note,
    this.targetMonth,
  });

  // JSON 데이터를 객체로 변환 (서버 -> 플러터)
  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    return PaymentInfo(
      id: json['id'],
      name: json['name'] ?? '',
      payItem: json['pay_item'] ?? '기타',
      amount: json['amount'] ?? 0,
      // 서버의 0/1 값을 bool로 안전하게 변환[cite: 5]
      isPaid: json['is_paid'] == 1 || json['is_paid'] == true,
      payMethod: json['pay_method'],
      note: json['note'],
      targetMonth: json['target_month'],
    );
  }

  // 객체를 JSON으로 변환 (플러터 -> 서버)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'pay_item': payItem,
      'amount': amount,
      'is_paid': isPaid ? 1 : 0, // 서버 DB 타입에 맞춰 변환[cite: 5]
      'note': note,
      'target_month': payItem == "장비료" ? null : targetMonth,
    };
  }
}

final _formatter = NumberFormat('#,###');

class MngPaymentScreen extends StatefulWidget {
  final String userId;

  const MngPaymentScreen({super.key, required this.userId});

  @override
  // ignore: library_private_types_in_public_api
  _MngPaymentScreenState createState() => _MngPaymentScreenState();
}

class _MngPaymentScreenState extends State<MngPaymentScreen> {
  // 1. 데이터 리스트
  List<Map<String, dynamic>> payments = [];
  List<Member> _activeMembers = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  // 초기 데이터 로딩
  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchPayments(), _fetchActiveMembers()]);
    setState(() => _isLoading = false);
  }

  // 결제 목록 가져오기
  Future<void> _fetchPayments() async {
    try {
      final response = await http.get(Uri.parse(Config.getPayments));
      if (response.statusCode == 200) {
        setState(() {
          payments = List<Map<String, dynamic>>.from(json.decode(response.body));
        });
      }
    } catch (e) {
      debugPrint("결제 데이터 로딩 실패: $e");
    }
  }

  // DB에서 회원 명단을 가져오는 함수
  Future<void> _fetchActiveMembers() async {
    try {
      final response = await http.get(Uri.parse(Config.getActiveMembers)); 
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        
        // 만약 데이터가 리스트라면 그대로 사용하고, 
        // 특정 키(예: 'data') 안에 들어있다면 해당 키를 참조합니다.
        List<dynamic> data = [];
        if (decodedData is List) {
          data = decodedData;
        } else if (decodedData is Map && decodedData.containsKey('data')) {
          data = decodedData['data']; // 서버 구조에 따라 'members' 등일 수 있음
        }

        setState(() {
          _activeMembers = data.map((m) => Member(
            id: m['id'].toString(),
            name: m['name'] ?? '이름 없음',
          )).toList();
        });
      }
    } catch (e) {
      debugPrint("회원 목록 로딩 실패: $e");
    }
  }

  // 결제 등록 및 수정
  Future<void> _savePaymentToServer({
    PaymentInfo? original,
    required String memberId,
    required String selectedUser,
    required String selectedItem,
    required String selectedPayMethod,
    required String amountText,
    required bool isPaid,
    required String note,
    required String targetMonth,
  }) async {
    final bool isEdit = original != null;
    final url = isEdit ? Config.updatePayment : Config.addPayment;

    // 금액에서 콤마 제거 후 숫자로 변환
    int finalAmount = int.tryParse(amountText.replaceAll(',', '')) ?? 0;

    // 서버 API 모델(UpdatePaymentRequest 등)이 기대하는 키 값으로 구성
    final body = {
      if (isEdit) "id": original.id, // 수정 시 필수
      "member_id": isEdit ? null : memberId,
      "name": selectedUser,
      "pay_item": selectedItem,    // 서버 DB 컬럼명과 일치
      "pay_method": selectedPayMethod,
      "amount": finalAmount,        // int 타입으로 전송
      "is_paid": isPaid,        // bool로 보내면 서버에서 0/1 처리
      "note": note,
      "target_month": selectedItem == "장비료" ? null : targetMonth,
      "created_by": widget.userId,
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEdit ? "수정되었습니다." : "등록되었습니다."))
          );
        }
        _fetchPayments(); // 목록 새로고침
      } else {
        debugPrint("서버 응답 에러: ${response.body}");
      }
    } catch (e) {
      debugPrint("저장 오류: $e");
    }
  }

  // 2. 상태 변수
  String searchQuery = "";
  String selectedPaidStatus = "전체";
  bool isAscending = true;
  int sortColumnIndex = 0;

  // 3. 필터링 로직
  List<Map<String, dynamic>> get _filteredPayments {
    return payments.where((p) {
      final nameMatch = (p['name'] ?? "").toString().contains(searchQuery);
      bool statusMatch = true;
      if (selectedPaidStatus == "완납") statusMatch = (p['is_paid'] == 1 || p['is_paid'] == true);
      if (selectedPaidStatus == "미납") statusMatch = (p['is_paid'] == 0 || p['is_paid'] == false);
      return nameMatch && statusMatch;
    }).toList();
  }
    
  Future<void> _deletePayment(dynamic id) async {
    try {
      final response = await http.post(
        Uri.parse(Config.deletePayment), // constants.dart에 정의 필요
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id": id}),
      );
      if(mounted) {
        if (response.statusCode == 200) {
          Navigator.pop(context);
          _fetchPayments();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("삭제되었습니다.")));
        }
      }
    } catch (e) {
      debugPrint("삭제 오류: $e");
    }
  }

  Future<void> _togglePaymentStatus(PaymentInfo info) async {
    try {
      final response = await http.post(
        Uri.parse(Config.updatePayment),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "id": info.id,             // 모델에 정의된 'id'와 일치
          "pay_item": info.payItem,
          "amount": info.amount,
          "is_paid": !info.isPaid,   // bool 타입 그대로 전송
          "note": info.note ?? "",   // 필수 필드이므로 null 방지
        }),
      );

      if (response.statusCode == 200) {
        _fetchPayments(); // 목록 새로고침[cite: 3]
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(info.isPaid ? "미납으로 변경되었습니다." : "완납 처리되었습니다."))
          );
        }
      }
    } catch (e) {
      debugPrint("상태 업데이트 실패: $e");
    }
  }
  
  // -------------- 화면 빌드 ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('결제 관리'),
        backgroundColor: const Color(0xFF166534),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 검색바
          _buildSearchAndFilterBar(),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: "이름으로 검색",
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => searchQuery = value),
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : payments.isEmpty
                  ? const Center(child: Text("결제 내역이 없습니다."))
                  : ListView.builder(
                      itemCount: _filteredPayments.length,
                      itemBuilder: (context, index) {
                        final p = _filteredPayments[index];
                        final info = PaymentInfo.fromJson(p);

                        return Dismissible(
                          key: Key(info.id.toString()),
                          direction: DismissDirection.endToStart, // 우에서 좌로 밀기
                          confirmDismiss: (direction) async {
                            // 밀었을 때 바로 결제 상태 업데이트 함수 호출
                            _togglePaymentStatus(info);
                            return false; // 화면에서 아이템이 사라지지 않게 false 반환
                          },
                          background: Container(
                            color: Colors.blue,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(Icons.check_circle_outline, color: Colors.white),
                          ),
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: InkWell( // [1] 줄 전체 터치 시 수정창
                              onTap: () => _showPaymentDialog(payment: info, isEdit: true),
                              child: ListTile(
                                title: Text(info.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(info.payItem == "장비료"
                                  ? info.payItem
                                  : "${info.targetMonth} / ${info.payItem}"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatter.format(info.amount),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(
                                      info.isPaid ? Icons.check_circle : Icons.error_outline,
                                      color: info.isPaid ? Colors.green : Colors.red,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async{
          await _fetchActiveMembers();

          _showPaymentDialog();
        },  
        backgroundColor: Colors.green[800],
        child: const Icon(Icons.add),
      ),
    );
  }

  // 바텀 시트
  void _showPaymentDialog({PaymentInfo? payment, bool isEdit = false}) {
    // 초기값 설정
    String? selectedUser = isEdit ? payment!.name : null;
    String? selectedMemberId = isEdit ? payment!.id.toString() : null;
    String selectedItem = isEdit ? payment!.payItem : "수업료";
    String selectedPayMethod = isEdit ? (payment!.payMethod ?? "카드") : "카드";
    bool tempIsPaid = isEdit ? payment!.isPaid : false;
    
    final amountController = TextEditingController(
      text: isEdit ? _formatter.format(payment!.amount) : ""
    );
    final noteController = TextEditingController(
      text: isEdit ? payment!.note ?? "" : ""
    );

    // 현재 날짜 기준 정보 추출
    DateTime now = DateTime.now();
    
    // 기존 데이터가 있으면 해당 날짜를, 없으면 현재 날짜를 기본값으로 사용
    String targetMonthStr = isEdit ? (payment!.targetMonth ?? DateFormat('yyyy-MM').format(now)) : DateFormat('yyyy-MM').format(now);
    
    // 연도와 월 분리 (예: "2026-04" -> "2026", "04")
    String localYear = targetMonthStr.split('-')[0];
    String localMonth = targetMonthStr.split('-')[1];

    // 선택 가능한 연도 리스트 (현재 기준 +-1년)
    List<String> yearOptions = [
      (now.year - 1).toString(),
      now.year.toString(),
      (now.year + 1).toString(),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 키보드가 올라와도 화면이 가려지지 않게 설정
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            bool isButtonEnabled = selectedUser != null;

            return Padding(
              // 키보드 높이만큼 여백을 주어 입력 필드가 가려지지 않게 함
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isEdit ? "결제 내역 수정" : "새 결제 등록",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // 회원 선택 (등록 시에만 활성)
                    const Text("결제 대상 회원", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    AbsorbPointer(
                      absorbing: isEdit, // 수정 모드일 때 모든 터치 이벤트를 차단함
                      child: SearchAnchor(
                        builder: (BuildContext context, SearchController controller) {
                          return SearchBar(
                            controller: controller,
                            hintText: selectedUser ?? "회원 이름을 검색하세요",
                            onTap: isEdit ? null : () => controller.openView(),
                            onChanged: isEdit ? null : (_) => controller.openView(),
                            leading: const Icon(Icons.search),
                            // 시각적으로 비활성 상태임을 보여주기 위해 사용
                            enabled: !isEdit, 
                            elevation: WidgetStateProperty.all(0),
                            backgroundColor: isEdit 
                                ? WidgetStateProperty.all(Colors.grey[200]) 
                                : null,
                          );
                        },
                        suggestionsBuilder: (BuildContext context, SearchController controller) {
                          final String input = controller.value.text.toLowerCase();
                          return _activeMembers
                              .where((member) => member.name.toLowerCase().contains(input))
                              .map((member) => ListTile(
                                    title: Text(member.name),
                                    onTap: () {
                                      setBottomSheetState(() {
                                        selectedUser = member.name;
                                        selectedMemberId = member.id;
                                        controller.closeView(member.name);
                                      });
                                    },
                                  ));
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 🔘 결제 항목 (라디오 버튼 적용)
                    const Text("결제 항목", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity, // 가로로 꽉 차게
                      child: SegmentedButton<String>(
                        // 현재 선택된 값 (Set 형태여야 함)
                        segments: const [
                          ButtonSegment<String>(
                            value: "수업료",
                            label: Text("수업료"),
                            icon: Icon(Icons.school_outlined),
                          ),
                          ButtonSegment<String>(
                            value: "장비료",
                            label: Text("장비료"),
                            icon: Icon(Icons.build_outlined),
                          ),
                        ],
                        selected: {selectedItem}, // 현재 선택 값
                        onSelectionChanged: (Set<String> newSelection) {
                          setBottomSheetState(() {
                            selectedItem = newSelection.first; // 첫 번째 선택값 적용
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 📅 대상연월 선택 섹션
                    if (selectedItem != "장비료") ...[
                      const Text("결제 대상 연월", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // 연도 선택 (SegmentedButton)
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(                                  
                                    initialValue: localYear,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                                    ),
                                    // 숫자만 들어가게 설정
                                    items: yearOptions.map((y) => DropdownMenuItem(
                                      value: y, 
                                      child: Text(y), 
                                    )).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setBottomSheetState(() {
                                          localYear = val; // 변수 값을 변경하고 UI를 다시 그립니다.
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text("년"), // 연도 옆에 '년' 표시
                              ],
                            ),
                          ),
                          const SizedBox(width: 15),
                          
                          // --- 월 선택 드랍다운 ---
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(                                  
                                    initialValue: localMonth,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                                    ),
                                    // 01~12 형식으로 생성
                                    items: List.generate(12, (i) => (i + 1).toString().padLeft(2, '0'))
                                        .map((m) => DropdownMenuItem(
                                          value: m, 
                                          child: Text(int.parse(m).toString()), // 숫자로 표시
                                        )).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setBottomSheetState(() {
                                          localMonth = val; // 변수 값을 변경하고 UI를 다시 그립니다.
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text("월"), // 월 옆에 '월' 표시
                              ],
                            ),
                          ),
                        ],
                      ),                    
                      const SizedBox(height: 20),
                    ],

                    // 💳 결제 방법 (🎯 카드/현금 라디오 버튼 스타일)
                    const Text("결제 방법", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: "카드", label: Text("카드"), icon: Icon(Icons.credit_card)),
                        ButtonSegment(value: "현금", label: Text("현금"), icon: Icon(Icons.payments_outlined)),
                      ],
                      selected: {selectedPayMethod},
                      onSelectionChanged: (newSelection) {
                        setBottomSheetState(() => selectedPayMethod = newSelection.first);
                      },
                    ),
                    const SizedBox(height: 20),

                    // 금액 입력
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "금액"),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          String cleanValue = value.replaceAll(',', '');
                          int? parsedValue = int.tryParse(cleanValue);
                          if (parsedValue != null) {
                            String formatted = _formatter.format(parsedValue);
                            amountController.value = TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(offset: formatted.length),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // 비고
                    TextField(
                      controller: noteController,
                      readOnly: isEdit, 
                      maxLines: 2, // 여러 줄 입력 가능
                      decoration: const InputDecoration(
                        labelText: "비고 (선택 사항)",
                        hintText: "특이사항이나 메모를 입력하세요",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note_alt_outlined),
                        alignLabelWithHint: true, // 여러 줄일 때 라벨을 위쪽으로 정렬
                      ),                     
                    ),
                    const SizedBox(height: 10),

                    // 결제 완료 체크박스
                    CheckboxListTile(
                      title: const Text("결제 완료"),
                      value: tempIsPaid,
                      onChanged: (value) => setBottomSheetState(() => tempIsPaid = value!),
                    ),
                    const SizedBox(height: 20),

                    // 저장/수정 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isButtonEnabled ? Colors.green[800] : Colors.grey, // 비활성 색상
                        ),
                        onPressed: isButtonEnabled ? () {
                          if (selectedUser == null) return;

                          String finalTargetMonth = "$localYear-$localMonth";

                          _savePaymentToServer(
                            original: payment,
                            memberId: selectedMemberId ?? "",
                            selectedUser: selectedUser!,
                            selectedItem: selectedItem,
                            selectedPayMethod: selectedPayMethod,
                            amountText: amountController.text,
                            isPaid: tempIsPaid,
                            note: noteController.text,
                            targetMonth: finalTargetMonth, // 연월 합치기
                          );
                        } : null,
                        child: Text(isEdit ? "수정하기" : "등록하기", style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                    
                    // 수정 모드일 때만 삭제 버튼 표시
                    if (isEdit)
                      TextButton(
                        onPressed: () => _deletePayment(payment!.id),
                        child: const Text("삭제하기", style: TextStyle(color: Colors.red)),
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

  // 🔍 검색 및 필터바 함수
  Widget _buildSearchAndFilterBar() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: "이름으로 검색",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => searchQuery = value),
          ),
        ),
        // 완납/미납 필터 칩
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
          child: Row(
            children: ["전체", "완납", "미납"].map((status) {
              final isSelected = selectedPaidStatus == status;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(status),
                  selected: isSelected,
                  selectedColor: const Color(0xFF166534),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                  onSelected: (val) {
                    if (val) setState(() => selectedPaidStatus = status);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
  
}