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

  @override
  void initState() {
    super.initState();
    _fetchEmails();
  }

  // 목록 가져오기 (FastAPI 연결)
  Future<void> _fetchEmails() async {
    try {
      // final response = await http.get(Uri.parse('http://localhost:8000/api/invited-emails')); 하드코딩
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
          ],
        ),
      ),
    );
  }
}