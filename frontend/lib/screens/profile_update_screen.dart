import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/constants.dart';

class ProfileUpdateScreen extends StatefulWidget {
  final String userId; // 이 ID 하나만 있으면 DB 조회가 가능합니다.

  const ProfileUpdateScreen({super.key, required this.userId});

  @override
  State<ProfileUpdateScreen> createState() => _ProfileUpdateScreenState();
}

class _ProfileUpdateScreenState extends State<ProfileUpdateScreen> {
  // 컨트롤러들
  final _idController = TextEditingController();    // ReadOnly
  final _emailController = TextEditingController(); // ReadOnly
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPwController = TextEditingController();
  final _newPwController = TextEditingController();
  final _newPwConfirmController = TextEditingController();

  bool _isLoading = true; // 로딩 상태 표시
  bool _isPasswordChangeMode = false;

  @override
  void dispose() {
    // 컨트롤러 해제는 필수! (워닝 방지 및 메모리 관리)
    _idController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _currentPwController.dispose();
    _newPwController.dispose();
    _newPwConfirmController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUserData(); // 화면 켜지자마자 데이터 불러오기
  }

  // 🏹 영님의 get_user_by_id 함수를 호출하는 부분
  Future<void> _loadUserData() async {
    try {
      print("데이터 요청중");
      final response = await http.get(
        //Uri.parse('http://localhost:8000/api/get_user/${widget.userId}'),
        Uri.parse('${Config.getUser}/${widget.userId}'),
      ).timeout(const Duration(seconds: 5));

      print("✅ 서버 응답 코드: ${response.statusCode}");
    
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _idController.text = data['userid'] ?? '';
          _emailController.text = data['email'] ?? '';
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _isLoading = false; // 로딩 완료
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage("사용자 정보를 불러오지 못했습니다: $e", Colors.red);
    }
  }

  Future<void> _updateProfile() async {
    // 1. 필수값 체크 (현재 비밀번호는 보안상 항상 입력받는 게 좋습니다)
    if (_currentPwController.text.isEmpty) {
      _showMessage("현재 비밀번호를 입력해야 정보 수정이 가능합니다.", Colors.orange);
      return;
    }

    // 2. 비밀번호 변경 모드일 때 일치 여부 확인
    String? passwordToSend;
    if (_isPasswordChangeMode) {
      if (_newPwController.text != _newPwConfirmController.text) {
        _showMessage("새 비밀번호가 일치하지 않습니다.", Colors.red);
        return;
      }
      passwordToSend = _newPwController.text;
    }

    try {
      final response = await http.post(
        Uri.parse(Config.updateProfile),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userid': widget.userId,
          'current_password': _currentPwController.text, // 서버에서 먼저 확인용
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'new_password': passwordToSend, // 전달 안 하면 null (서버 로직과 매칭)
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) { 
        if (!mounted) return;
        _showMessage("정보가 성공적으로 수정되었습니다.", Colors.green);
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        // message가 없을 경우를 대비해 기본 문구 설정
        _showMessage(data['message'] ?? "수정에 실패했습니다.", Colors.red);
      }
    } catch (e) {
      _showMessage("서버 통신 에러: $e", Colors.red);
    }
  }

  // void _showMessage(String msg, Color color) {
  //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("개인정보 수정"), backgroundColor: const Color(0xFF166534), foregroundColor: Colors.white),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) // 로딩 중일 때 뱅글뱅글
          : SingleChildScrollView(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("계정 정보 (수정 불가)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 15),
                  // 🏹 ReadOnly 필드들
                  _buildTextField(_idController, "아이디", Icons.person, readOnly: true),
                  _buildTextField(_emailController, "이메일", Icons.email, readOnly: true),
                  
                  const SizedBox(height: 20),
                  const Text("기본 정보 수정", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _buildTextField(_nameController, "이름", Icons.badge),
                  _buildTextField(_phoneController, "연락처", Icons.phone),
                  
                  const Divider(height: 40),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("비밀번호 변경", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Switch(
                        value: _isPasswordChangeMode,
                        onChanged: (val) => setState(() => _isPasswordChangeMode = val),
                        // 🏹 최신 방식: 켜졌을 때(selected)와 꺼졌을 때 색상을 직접 지정
                        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.selected)) {
                            return const Color(0xFF166534); // 켜졌을 때 진한 초록색
                          }
                          return Colors.white; // 꺼졌을 때 흰색
                        }),
                        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.selected)) {
                            return const Color(0xFF166534).withValues(alpha: 0.5); // 켜졌을 때 연한 초록색 바탕
                          }
                          return Colors.grey.shade300; // 꺼졌을 때 연한 회색 바탕
                        }),
                      ),
                    ],
                  ),
                  
                  if (_isPasswordChangeMode) ...[
                    const SizedBox(height: 10),
                    _buildTextField(_newPwController, "새 비밀번호", Icons.lock_outline, isObscure: true),
                    _buildTextField(_newPwConfirmController, "새 비밀번호 확인", Icons.lock_reset, isObscure: true),
                  ],
                  
                  const Divider(height: 40),
                  
                  const Text("본인 확인", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 10),
                  _buildTextField(_currentPwController, "현재 비밀번호 입력", Icons.security, isObscure: true),
                  
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF166534),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("정보 수정 완료", style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                ],
              ),
            ),
    );
  }

  void _showMessage(String msg, Color color) {
    // ScaffoldMessenger가 현재 화면(context)에 메시지를 뿌려줍니다.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg), 
        backgroundColor: color,
        duration: const Duration(seconds: 2), // 2초 동안 보여주기
      ),
    );
  }

  // 🏹 readOnly 옵션을 추가한 텍스트 필드 빌더
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, 
      {bool isObscure = false, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        readOnly: readOnly, // 수정 불가 설정
        decoration: InputDecoration(
          labelText: label,
          filled: readOnly, // 읽기 전용일 때 배경색 살짝 주기
          fillColor: readOnly ? Colors.grey[100] : Colors.transparent,
          prefixIcon: Icon(icon, color: const Color(0xFF166534)),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}