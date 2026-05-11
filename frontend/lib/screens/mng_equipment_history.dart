import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import '/constants.dart'; // Config URL 등을 위해 필요
import 'mng_equipment_screen.dart'; // Equipment 모델 재활용

final _formatter = NumberFormat('#,###');


class MngEquipmentHistoryScreen extends StatefulWidget {
  final Equipment equipment; // 어떤 장비의 내역인지 넘겨받음
  final String userName;

  const MngEquipmentHistoryScreen({super.key, required this.equipment, required this.userName});

  @override
  State<MngEquipmentHistoryScreen> createState() => _MngEquipmentHistoryScreenState();
}

class _MngEquipmentHistoryScreenState extends State<MngEquipmentHistoryScreen> {
  bool _isLoading = false;
  List<dynamic> _history = []; // 입출고 내역 리스트
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _selectedType = "출고"; // 기본값
  Member? _selectedMember;
  List<Member> _activeMembers = [];
  int _totalAmount = 0;
  int? _currentStock;      // 현재 실시간 재고
  int _memberOutStock = 0; // 선택된 회원이 현재 가지고 있는 수량
  bool isFormValid = false; // 버튼 활성화 여부 결정
  int? _targetParentId;
  
  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _fetchActiveMembers();

    // 🎯 이 리스너들이 있어야 실시간으로 버튼이 켜집니다!
    _qtyController.addListener(_updateTotalAmount);
    _priceController.addListener(_updateTotalAmount);
  }

  // [API] 입출고 내역 가져오기
  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    
    try {
      final stockRes = await http.get(Uri.parse("${Config.getPresentStock}/${widget.equipment.id}"));
      final response = await http.get(Uri.parse("${Config.getTradeList}/${widget.equipment.id}"));

      if (response.statusCode == 200 && stockRes.statusCode == 200) {
        final data = json.decode(response.body);
        final stockData = json.decode(stockRes.body);

        setState(() {
          _history = data['data'] as List;
          _currentStock = stockData['stock'];
        });
      }
    } catch (e) {
      debugPrint("입출고 목록 로드 실패: $e");
    } finally {
      setState(() => _isLoading = false);      
    }
  }

  // 활동 회원 목록 가져오기
  Future<void> _fetchActiveMembers() async {
    try {
      final response = await http.get(Uri.parse(Config.getActiveMembers));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _activeMembers = (data['data'] as List).map((e) => Member.fromJson(e)).toList();
        });
      }      
    } catch (e) {
      debugPrint("회원 목록 로드 실패: $e");
    }
  }

  // 입출고 저장
  Future<void> _handleTransactionSave() async {
    
    try {
      // 2. 서버로 보낼 데이터 뭉치기
      final Map<String, dynamic> tradeData = {
        "equipment_id": widget.equipment.id,
        "member_id": _selectedMember?.id,      // 선택된 회원 ID
        "trade_type": _selectedType,           // '입고' 또는 '출고'
        "quantity": int.parse(_qtyController.text),
        "unit_price": int.parse(_priceController.text.replaceAll(',', '')),
        "total_price": _totalAmount,
        "note": _noteController.text,
        "processed_by": widget.userName,   
        "parent_id": _targetParentId,              
      };

      // 3. 서버에 POST 요청       
      final response = await http.post(
        Uri.parse(Config.addTradeList), 
        headers: {"Content-Type": "application/json"},
        body: json.encode(tradeData),
      );

      if (response.statusCode == 200) {
        _showMessage("성공적으로 저장되었습니다.", Colors.green);
        if (!mounted) return;
        Navigator.pop(context);
        _fetchHistory();
      } else {
        _showMessage("저장에 실패했습니다. 다시 시도해주세요.", Colors.red);
      }
    } catch (e) {
      debugPrint("기록 저장 중 오류 발생: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("저장 실패: $e")),
        );
      }
    }
  }

  Future<void> _fetchMemberOutStock(int memberId) async {
    try {
      final response = await http.get(
        Uri.parse("${Config.getOutMemberStock}/${widget.equipment.id}/$memberId"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _memberOutStock = data['out_stock'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint("회원 점유 수량 로드 실패: $e");
    }
  }

  void _openTransactionEditor({bool isDetail = false, dynamic item}) {

    // print("디버깅 - 선택된 아이템: $item");
    //   if (item != null) {
    //     print("디버깅 - 멤버이름: ${item['member_name']}");
    //     print("디버깅 - 멤버ID: ${item['member_id']}");
    //     print("디버깅 - 멤버생년월일: ${item['member_birth']}");
    //     print("isDetail: $isDetail");
    //   }
    setState(() {
      if (isDetail && item != null) {
        // 🎯 상세 보기 모드: 기존 데이터로 필드 채우기
        _qtyController.text = item['quantity'].toString();
        _priceController.text = _formatter.format(item['unit_price']);
        _noteController.text = item['note'] ?? "";
        _selectedType = item['trade_type'];
        _totalAmount = item['total_price'];
        
        // 만약 출고라면 기존 선택된 멤버 찾기 (ID 비교)
        if (isDetail && item != null) {        
          _selectedMember = Member(
            id: item['member_id'] ?? 0,
            name: item['member_name'] ?? "관리자",
            birth: item['member_birth'] ?? "회원 할당 안됨", // 생년월일 데이터가 있다면 포함
          );
          if (_selectedType == "출고취소") {
            if (item['member_id'] != null) {
              _fetchMemberOutStock(item['member_id']);
            }
          }
        }
      } else {
        // 🎯 신규 등록 모드: 초기화
        _qtyController.clear();
        _priceController.clear();
        _noteController.clear();
        _selectedType = "출고";
        _selectedMember = null;
        _totalAmount = 0;
      }
    });

    // 회원 목록 미리 가져오기 (이미 로드되었다면 생략 가능)
    _fetchActiveMembers();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // 라운드 처리를 위해 투명 배경
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, // 키보드 대응
              ),
              // 별도의 위젯 빌더 함수 호출
              child: _buildTransactionDetail(setModalState, isDetail),
            );
          },
        );
      },
    );
  }

  // 🎯 1. 입력값 검증 (수량, 단가, 재고 체크)
  void _validateForm() {
    setState(() {
      int qty = int.tryParse(_qtyController.text.replaceAll(',', '')) ?? 0;
      int price = int.tryParse(_priceController.text.replaceAll(',', '')) ?? 0;
      int effectiveStock = _currentStock ?? widget.equipment.stock;

      // 공통: 1개 이상 입력
      bool basicOk = qty >= 1;
      bool specificOk = false;

      switch (_selectedType) {
        case "입고":
          // 1. 수량, 단가(0원 이상) 모두 입력
          specificOk = price >= 0; 
          break;
        case "출고":
          // 2. 대상 선택 + 수량 + 단가 + 재고 이내
          specificOk = _selectedMember != null && price >= 0 && qty <= effectiveStock;
          break;
        case "입고취소":
          // 3. 수량 + 단가(0원 고정) + 취소가능 수량 이내
          specificOk = qty <= _memberOutStock;
          break;
        case "출고취소":
          // 4. 대상 선택 + 수량 + 단가 + 취소가능 수량 이내
          specificOk = _selectedMember != null && qty <= _memberOutStock;
          break;
      }

      isFormValid = basicOk && specificOk;
    });
  }

  // 🎯 2. 합계 금액 계산 및 검증 호출
  void _updateTotalAmount() {
    int qty = int.tryParse(_qtyController.text.replaceAll(',', '')) ?? 0;
    int price = int.tryParse(_priceController.text.replaceAll(',', '')) ?? 0;
    setState(() {
      _totalAmount = qty * price;
    });
    _validateForm(); // 👈 값 바뀔 때마다 검증 실행
  }

  // 🎯 3. 간단 메시지 출력
  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("[${widget.equipment.name}] 의 입출고 내역"),
        backgroundColor: const Color(0xFF166534),
        foregroundColor: Colors.white,
        // actions: [
        //   // 내역 화면에서도 수정을 바로 호출할 수 있게 배치
        //   IconButton(
        //     icon: const Icon(Icons.edit),
        //     onPressed: () {
        //       // 부모 창의 수정 함수를 호출하거나 알림을 보냄
        //     },
        //   ),
        // ],
      ),
      body: Column(
        children: [
          // 1. 상단 요약 카드 (현재 상태)
          _buildSummaryCard(),
          
          const Divider(height: 1),
          
          // 2. 입출고 내역 리스트
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _history.isEmpty 
                ? const Center(child: Text("기록된 내역이 없습니다."))
                : ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (context, index) => _buildHistoryItem(_history[index]),
                  ),
          ),
        ],
      ),
      // 3. 입출고 등록 버튼
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTransactionEditor(),
        backgroundColor: const Color(0xFF166534),
        icon: const Icon(Icons.swap_vert, color: Colors.white),
        label: const Text("입출고/취소 등록", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // 상단 요약 위젯
  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.grey[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoColumn("현재 재고", "${_currentStock ?? widget.equipment.stock}개", Colors.black),
          _buildInfoColumn("규격", widget.equipment.spec.isEmpty ? "-" : widget.equipment.spec, Colors.grey[700]!),
          _buildInfoColumn("위치", widget.equipment.location.isEmpty ? "-" : widget.equipment.location, Colors.grey[700]!),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  // 내역 아이템 빌더 (원상복구 버전)
  Widget _buildHistoryItem(dynamic item) {
    // 유형에 따른 아이콘 및 색상 설정
    IconData iconData;
    Color iconColor;

    switch (item['trade_type']) {
      case '입고':
        iconData = Icons.add_circle;
        iconColor = Colors.blue;
        break;
      case '출고':
        iconData = Icons.remove_circle;
        iconColor = Colors.red;
        break;
      case '입고취소':
      case '출고취소':
        iconData = Icons.undo_rounded;
        iconColor = Colors.orange;
        break;
      default:
        iconData = Icons.help_outline;
        iconColor = Colors.grey;
    }

    String target = item['member_name'] ?? "관리자";

    return ListTile(
      // 💡 이제 수정/삭제 대신 상세 확인만 하거나, 
      // 필요한 경우 여기서 정보를 가져와 취소 전표를 작성하는 흐름으로 가시면 됩니다.
      onTap: () => _openTransactionEditor(isDetail: true, item: item),
      leading: Icon(iconData, color: iconColor),      
      title: Text(
        "${item['trade_type']} ${item['quantity']}개 ($target)",
        style: TextStyle(
          // 취소 건은 텍스트에 취소선을 긋거나 흐리게 처리하여 구분 가능
          decoration: item['trade_type'].contains('취소') ? TextDecoration.lineThrough : null,
          color: item['trade_type'].contains('취소') ? Colors.grey : Colors.black87,
        ),
      ),
      subtitle: Text(
        "단가 : ${_formatter.format(item['unit_price'] ?? 0)} 원 | 총 : ${_formatter.format(item['total_price'] ?? 0)} 원",
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text("${item['processed_at']}", style: const TextStyle(fontSize: 12)),
          Text("처리: ${item['processed_by']}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTransactionDetail(StateSetter setModalState, bool isDetail) {
    // 1. 현재 상태값 가져오기 (이미 _validateForm에서 계산된 값들 활용)
    bool readOnly = isDetail;
    int effectiveStock = _currentStock ?? widget.equipment.stock;
    int inputQty = int.tryParse(_qtyController.text.replaceAll(',', '')) ?? 0;
       
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isDetail ? "기록 상세 내역" : "입출고 및 취소 등록", 
             style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // 유형 선택 (입고/출고/입고취소/출고취소)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: '입고', label: Text('입고')),
                ButtonSegment(value: '출고', label: Text('출고')),
                ButtonSegment(value: '입고취소', label: Text('입고취소')),
                ButtonSegment(value: '출고취소', label: Text('출고취소')),
              ],
              selected: {_selectedType},
              onSelectionChanged: (val) async {
                String newType = val.first;

                setModalState(() {
                  _selectedType = val.first;
                  if (_selectedType.contains("취소")) {
                    _priceController.text = "0"; // 취소 시 단가는 0원으로 고정
                    _updateTotalAmount();
                  }
                });

                // 취소 한도 데이터 로드
                if (newType.contains("취소")) {
                  try {
                    String url = "${Config.getCancelLimitInfo}/${widget.equipment.id}/$newType";
                    if (newType == "출고취소" && _selectedMember != null) {
                      url += "?member_id=${_selectedMember!.id}";
                    }

                    final res = await http.get(Uri.parse(url));
                    if (res.statusCode == 200) {
                      final data = json.decode(res.body);
                      setModalState(() {
                        // 단가 무시 로직이므로 quantity만 중요
                        _memberOutStock = data['quantity'] ?? 0;
                        _qtyController.text = _memberOutStock.toString(); // 최대치 자동 입력
                        _updateTotalAmount(); // 합계 및 검증 갱신
                      });
                    }
                  } catch (e) {
                    debugPrint("한도 로드 실패: $e");
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 20),
          
          // 회원 선택
          if (_selectedType == "출고" || _selectedType == "출고취소") ...[
            AbsorbPointer(
              absorbing: readOnly,
              child: SearchAnchor(
                builder: (context, controller) => SearchBar(
                  controller: controller,
                  hintText: _selectedMember?.displayName ?? "대상 선택",
                  enabled: !readOnly,
                  onTap: readOnly ? null : () => controller.openView(),
                  leading: const Icon(Icons.search),
                ),
                suggestionsBuilder: (BuildContext context, SearchController controller) {
                  //실시간 필터링 로직
                  final String keyword = controller.text.toLowerCase();
                  final List<Member> filtered = _activeMembers.where((m) {
                    return m.name.contains(keyword) || m.birth.contains(keyword);
                  }).toList();

                  return filtered.map((member) {
                    return ListTile(
                      title: Text(member.displayName),
                      leading: const Icon(Icons.person_outline, size: 20),
                      onTap: () async {
                        setModalState(() {
                          _selectedMember = member;
                        });
                        await _fetchMemberOutStock(member.id); // 데이터 가져오기
                        setModalState(() {}); // UI 다시 그림
                        controller.closeView(member.displayName);                      
                      },
                    );
                  });
                },
              ),
            ),
            const SizedBox(height: 15),
          ],

          // 수량 입력 및 재고 체크
          TextField(
            controller: _qtyController,
            readOnly: readOnly,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _selectedType == "입고취소" 
                ? "입고취소 (최대 $_memberOutStock개 가능)" 
                : _selectedType == "출고취소"
                    ? "출고취소 (회원보유: $_memberOutStock개)"
                    : "수량 (현재고: $effectiveStock개)",
              border: const OutlineInputBorder(),
              errorText: (_selectedType == "출고" && inputQty > effectiveStock)
                ? "재고가 부족합니다"
                : (_selectedType.contains("취소") && inputQty > _memberOutStock)
                    ? "취소 가능 한도를 초과했습니다"
                    : null,
            ),
            onChanged: (val) {
              // 🎯 합계 계산 + 검증 + 모달 UI 갱신을 한 번에!
              setModalState(() {
                _updateTotalAmount(); 
              });
            },
          ),
          const SizedBox(height: 15),

          // 단가 입력
          TextField(
            controller: _priceController,
            readOnly: _selectedType.contains("취소"),   // 취소 일 때는 단가 고정
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _selectedType.contains("취소") ? "단가 (취소 시 미포함)" : "단가 (원)",
              border: OutlineInputBorder(),
              // 🎯 읽기 전용일 때 바탕색을 회색으로 칠해서 "수정불가"임을 알림
              filled: _selectedType.contains("취소"),
              fillColor: _selectedType.contains("취소") ? Colors.grey[200] : null,
            ),
            onChanged: (value) {
              if (value.isEmpty) return;

              // 1. 기존 콤마 제거 후 숫자로 변환
              String cleanValue = value.replaceAll(',', '');
              int? parsedValue = int.tryParse(cleanValue);

              if (parsedValue != null) {
                // 2. 콤마가 포함된 포맷으로 변경
                String formattedValue = _formatter.format(parsedValue);
                
                // 3. 커서 위치가 튀지 않게 컨트롤러 값 업데이트
                _priceController.value = TextEditingValue(
                  text: formattedValue,
                  selection: TextSelection.collapsed(offset: formattedValue.length),
                );
              }

              // 4. 합계 계산 (화면 갱신)
              setModalState(() {
                _updateTotalAmount();
              });
            },
          ),
          const SizedBox(height: 20),

          // 비고
          
          TextField(
            controller: _noteController,
            readOnly: readOnly, 
            maxLines: 2, // 여러 줄 입력 가능
            decoration: const InputDecoration(
              labelText: "비고 (선택 사항)",
              hintText: "특이사항이나 메모를 입력하세요",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note_alt_outlined),
              alignLabelWithHint: true, // 여러 줄일 때 라벨을 위쪽으로 정렬
            ),
            onChanged: (value) {
              // 비고는 합계 금액에 영향을 주지 않으므로 단순 상태 갱신만
              setModalState(() {}); 
            },
          ),
          
          const SizedBox(height: 20),

          // 합계 금액 표시란
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("합계 금액", style: TextStyle(fontWeight: FontWeight.bold)),
                Flexible(
                  child: Text(
                    "${_formatter.format(_totalAmount)} 원",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                    textAlign: TextAlign.right,
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 저장 버튼
          if (!readOnly)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // 검증 통과 시에만 함수 연결, 아니면 null (비활성화)
                onPressed: isFormValid ? _handleTransactionSave : null,
                style: ElevatedButton.styleFrom(
                  // 활성화 시 제주 맥주 느낌의 초록색, 비활성화 시 회색
                  backgroundColor: isFormValid ? const Color(0xFF166534) : Colors.grey,
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: Text(
                  "기록 저장",
                  style: TextStyle(
                    color: isFormValid ? Colors.white : Colors.black38,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}