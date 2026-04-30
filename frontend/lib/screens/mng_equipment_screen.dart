import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/constants.dart';
import 'mng_equipment_history.dart';

// 1. 장비 모델 클래스
class Equipment {
  final int? id;
  final String name;
  final String spec;     // 추가
  final String location; // 추가
  final String note;     // 추가
  final int stock;

  Equipment({
    this.id,
    required this.name,
    this.spec = '',
    this.location = '',
    this.note = '',
    this.stock = 0,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'],
      name: json['name'] ?? '',
      spec: json['spec'] ?? '',
      location: json['location'] ?? '',
      note: json['note'] ?? '',
      stock: json['stock'] ?? 0,
    );
  }
}

// 2. 입출고 내역 모델 클래스
class Trade {
  final int id;
  final String type;        // '입고' 또는 '출고'
  final int qty;           // 수량
  final String user;        // 처리자(스태프)
  final String date;        // 처리 일시
  final String? note;       // 비고
  final String? memberName; // 빌려간 회원 이름

  Trade({
    required this.id,
    required this.type,
    required this.qty,
    required this.user,
    required this.date,
    this.note,
    this.memberName,
  });

  factory Trade.fromJson(Map<String, dynamic> json) {
    return Trade(
      id: json['id'],
      type: json['type'] ?? '',
      qty: json['qty'] ?? 0,
      user: json['user'] ?? '',
      date: json['date'] ?? '',
      note: json['note'],
      memberName: json['member_name'], // 서버의 'member_name'을 매핑
    );
  }
}

// 3. 활동중인 회원 목록 모델 클래스
class Member {
  final int id;
  final String name;
  final String birth;

  Member({required this.id, required this.name, required this.birth});

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'],
      name: json['name'] ?? '',
      birth: json['birth'] ?? '',
    );
  }

  // 드롭다운에 표시할 이름 (이름 + 생년월일 조합)
  String get displayName => "$name ($birth)";
}

class MngEquipmentScreen extends StatefulWidget {
  final String userName;

  const MngEquipmentScreen({super.key, required this.userName});

  @override
  State<MngEquipmentScreen> createState() => _MngEquipmentScreenState();
}

class _MngEquipmentScreenState extends State<MngEquipmentScreen> {
  List<Equipment> _equipments = [];
  bool _isLoading = true;

  // 컨트롤러 (장비 등록용)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _specController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();  

  @override
  void initState() {
    super.initState();
    _fetchEquipments();
  }

  // [API] 장비 목록 가져오기
  Future<void> _fetchEquipments() async {
  // 시작할 때 로딩 표시
  setState(() {
    _isLoading = true;
  });

  try {
    final response = await http.get(Uri.parse(Config.getEquipments));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _equipments = (data['data'] as List)
            .map((e) => Equipment.fromJson(e))
            .toList();
      });
    }
  } catch (e) {
    debugPrint("장비 목록 로드 실패: $e");
  } finally {
    // 성공하든 실패하든 로딩은 끝내기
    setState(() {
      _isLoading = false;
    });
  }
}

// [로직] 저장 / 수정 버튼 클릭 시
  Future<void> _handleSave(Equipment? original) async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("장비명을 입력해주세요.")));
      return;
    }

    final bool isEdit = original != null;
    final url = isEdit ? Config.updateEquipment : Config.addEquipment;
    
    final body = {
      if (isEdit) "id": original.id,
      "name": _nameController.text,
      "spec": _specController.text,
      "location": _locationController.text,
      "note": _noteController.text,
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        if (mounted) Navigator.pop(context);
        _fetchEquipments(); // 목록 새로고침
      }
    } catch (e) {
      debugPrint("저장 오류: $e");
    }
  }

  // [로직] 삭제 처리  
  Future<void> _handleDelete(Equipment equipment) async {
    // 1. 재고가 있는지 먼저 확인 (앱 모델에 이미 stock 정보가 있음)
    if (equipment.stock > 0) {
      _showAlertDialog("삭제 불가", "현재 재고가 ${equipment.stock}개 남아있어 삭제가 불가능합니다.\n먼저 모든 재고를 출고 처리해주세요.");
      return;
    }

    // 2. 서버에 내역이 있는지 물어보기
    try {
      final response = await http.get(Uri.parse("${Config.getEquipmentHistoryExists}/${equipment.id}"));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        bool hasHistory = data['has_history'];

        String message = hasHistory 
            ? "입출고 내역은 있으나 현재 재고가 0입니다.\n삭제 시 모든 내역이 사라집니다. 정말 삭제하시겠습니까?"
            : "장비 정보를 삭제하시겠습니까?";

        // 3. 확인 다이얼로그 띄우기
        bool confirm = await _showConfirmDialog("장비 삭제", message);
        
        if (confirm) {
          final delRes = await http.post(Uri.parse("${Config.deleteEquipment}/${equipment.id}"));
          if (delRes.statusCode == 200) {
            if (mounted) {
              Navigator.pop(context); // 폼 닫기
              _fetchEquipments();    // 리스트 새로고침
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("삭제되었습니다.")));
            }
          }
        }
      }
    } catch (e) {
      _showAlertDialog("오류", "삭제 확인 중 오류가 발생했습니다.");
    }
  }

  // 공통 확인창
  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("취소")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("삭제", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }

  // 공통 경고창
  void _showAlertDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("확인")),
        ],
      ),
    );
  }

  // 장비 등록/수정 바텀 시트 열기
  void _openEquipmentEditor({Equipment? equipment}) {
    final bool isEdit = equipment != null;

    // 1. 컨트롤러 초기화 (수정 시 기존 값, 등록 시 빈 값)
    _nameController.text = isEdit ? equipment.name : "";
    _specController.text = isEdit ? equipment.spec : "";
    _locationController.text = isEdit ? equipment.location : "";
    _noteController.text = isEdit ? equipment.note : "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // 배경 투명하게 해서 라운드 적용
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: _buildEquipmentDetail(equipment, setModalState),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("장비 관리"),
        backgroundColor: const Color(0xFF166534),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _equipments.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _equipments.length,
                  itemBuilder: (context, index) {
                    final item = _equipments[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () async {
                          //debugPrint("${item.name} 클릭됨!"); // 로그 확인용
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MngEquipmentHistoryScreen(equipment: item, userName: widget.userName),
                            ),
                          );
                           _fetchEquipments(); 
                        },
                        onLongPress: () => _openEquipmentEditor(equipment: item),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          // 1. 왼쪽: 장비 번호 또는 양궁 아이콘
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF166534).withValues(alpha: 0.1),
                            child: Text("${index + 1}", 
                              style: const TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.bold)),
                          ),
                        
                          // 2. 중앙: 장비명 및 상세 정보
                          title: Text(
                            item.name, 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.spec.isNotEmpty)
                                  Text("사양: ${item.spec}", style: TextStyle(color: Colors.grey[700])),
                                Text("위치: ${item.location.isEmpty ? '미지정' : item.location}", 
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              ],
                            ),
                          ),

                          // 3. 오른쪽: 재고 수량 강조
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text("재고", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text(
                                    "${item.stock}", 
                                    style: const TextStyle(
                                      fontSize: 18, 
                                      fontWeight: FontWeight.bold, 
                                      color: Color(0xFF166534)
                                    )
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                            ],
                          ),                        
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEquipmentEditor(),
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
          // 장비 관리 느낌이 나는 아이콘 배치
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          const Text(
            "등록된 장비가 없습니다.",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "우측 하단의 + 버튼을 눌러\n새로운 장비를 추가해 보세요!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 40), // 플로팅 버튼 쪽으로 시선을 유도하는 여백
        ],
      ),
    );
  }

  Widget _buildEquipmentDetail(Equipment? equipment, StateSetter setModalState) {
    final bool isEdit = equipment != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더: 타이틀과 삭제 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEdit ? "장비 정보 수정" : "신규 장비 등록",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),                
              ],
            ),
            const SizedBox(height: 20),

            // 입력 필드들
            _buildTextField(_nameController, "장비명 (예: 리커브 핸들)", Icons.inventory),
            const SizedBox(height: 15),
            _buildTextField(_specController, "사양 (예: 28lbs / 68inch)", Icons.settings),
            const SizedBox(height: 15),
            _buildTextField(_locationController, "보관 위치 (예: 공용함 A-1)", Icons.place),
            const SizedBox(height: 15),
            _buildTextField(_noteController, "비고 (특이사항)", Icons.edit_note, maxLines: 3),
            
            const SizedBox(height: 25),

            if (isEdit) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _handleDelete(equipment), // 삭제 로직 연결
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text("장비 삭제", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // 저장 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handleSave(equipment),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF166534),
                  foregroundColor: Colors.white, // 글자색 확실히 지정!
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  isEdit ? "수정 내용 저장" : "장비 등록",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // 공통 텍스트 필드 빌더 (코드 중복 줄이기)
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF166534)),
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF166534), width: 2),
        ),
      ),
    );
  }

}