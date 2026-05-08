import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/constants.dart';

class UserInviteScreen extends StatefulWidget {
  const UserInviteScreen({super.key});

  @override
  State<UserInviteScreen> createState() => _UserInviteScreenState();
}

class _UserInviteScreenState extends State<UserInviteScreen> {
  final TextEditingController _emailController = TextEditingController();
  List<dynamic> _invitedEmails = [];
  List<dynamic> _registeredUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchEmails();
    _fetchUsers();
  }

  // 목록 가져오기 (FastAPI 연결)
  Future<void> _fetchEmails() async {
    try {      
      final response = await http.get(Uri.parse(Config.invitedEmails)); // constants.dart 에 셋팅된 값 사용
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        setState(() { _invitedEmails = result['data']; });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // 이메일 등록 (FastAPI 연결)
  Future<void> _inviteEmail() async {
    if (_emailController.text.isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse(Config.inviteEmail),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": _emailController.text}),
      );
      final result = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
        if (result['status'] == 'success') {
          _emailController.clear();
          _fetchEmails();
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // 가입된 유저 리스트 가져오기
  Future<void> _fetchUsers() async {
    final response = await http.get(Uri.parse(Config.getAllUsers));
    if (response.statusCode == 200) {
      setState(() { _registeredUsers = jsonDecode(response.body)['data']; });
    }
  }

  Future<void> _updateRole(String userId, String newRole) async {
    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/api/update_user_role'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'userid': userId,
          'role': newRole,
        }),
      );

      if (!mounted) return;

      final result = jsonDecode(response.body);
      
      if (response.statusCode == 200 && result['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('권한이 성공적으로 변경되었습니다.')),
        );
        Navigator.pop(context); // 바텀시트 닫기
        _fetchUsers(); // 리스트 새로고침
      } else {
        throw Exception(result['message'] ?? '수정 실패');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('에러 발생: $e')),
      );
    }
  }


  Future<void> _deleteUser(String userId) async {
    // 삭제 전 확인 팝업
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("사용자 삭제"),
        content: Text("$userId 사용자를 정말로 삭제하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("삭제", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    if (!mounted) return;

    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/api/delete_user'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'userid': userId}),
      );

      if (!mounted) return;

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사용자가 삭제되었습니다.')),
        );
        Navigator.pop(context); // 바텀시트 닫기
        _fetchUsers(); // 리스트 새로고침
      } else {
        throw Exception(result['message'] ?? '삭제 실패');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('에러 발생: $e')),
      );
    }
  }

  // 수정/삭제 바텀시트
  void _showUserEditSheet(dynamic user) {
    String selectedRole = user['role'];

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder( // 바텀시트 내 상태 변경용
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("사용자 정보 관리", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextField(controller: TextEditingController(text: user['userid']), decoration: const InputDecoration(labelText: '아이디'), readOnly: true),
                  TextField(controller: TextEditingController(text: user['name']), decoration: const InputDecoration(labelText: '이름'), readOnly: true),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    items: const [
                      DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'user', child: Text('user')),
                    ],
                    onChanged: (val) => setSheetState(() => selectedRole = val!),
                    decoration: const InputDecoration(labelText: '권한 설정'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateRole(user['userid'], selectedRole),
                          child: const Text("수정 저장"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => _deleteUser(user['userid']),
                        child: const Text("삭제", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  )
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('💌 사용자 초대'), backgroundColor: const Color(0xFF166534), foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: '허용할 이메일 주소',
                hintText: 'example@naver.com',
                suffixIcon: IconButton(onPressed: _inviteEmail, icon: const Icon(Icons.send, color: Colors.green)),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text("가입 허용 명단", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _invitedEmails.length,
                itemBuilder: (context, index) {
                  final item = _invitedEmails[index];

                  return Card(
                    child: ListTile(
                      leading: Icon(
                        (item['is_used'] ?? 0) == 1 ? Icons.check_circle : Icons.hourglass_empty, 
                        color: (item['is_used'] ?? 0) == 1 ? Colors.green : Colors.orange
                      ),
                      title: Text(item['email']?.toString() ?? "이메일 없음"),
                      subtitle: Text("등록일: ${item['created_at']?.toString() ?? "날짜 없음"}"),
                    ),
                  );
                },
              ),              
            ),

            const Text("가입된 사용자 명단", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _registeredUsers.length,
                itemBuilder: (context, index) {
                  final user = _registeredUsers[index];
                  return Card(
                    child: ListTile(
                      onTap: () => _showUserEditSheet(user), // 클릭 시 바텀시트
                      leading: const Icon(Icons.person),
                      title: Text("${user['name']} (${user['userid']})"),
                      subtitle: Text("연락처: ${user['phone']} / 권한: ${user['role']}"),
                      trailing: const Icon(Icons.edit),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}