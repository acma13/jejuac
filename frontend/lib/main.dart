import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;
import 'package:flutter_svg/flutter_svg.dart';
//import 'package:intl/date_symbol_data_local.dart';
//import 'package:flutter/foundation.dart'; // kIsWeb 사용을 위해 필요
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
//import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_localizations/flutter_localizations.dart'; // 기본 한국어 패키지
import 'package:syncfusion_localizations/syncfusion_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/user_invite_screen.dart';
import 'screens/profile_update_screen.dart';
import 'screens/club_calendar_screen.dart';
import 'screens/mng_member_screen.dart';
import 'screens/notice_screen.dart';
import 'constants.dart';
import 'firebase_options.dart';
import 'config/app_config.dart';


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

 try {
    // 1. 파이어베이스 초기화 (이건 기다려야 함)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized");

    // 2. 알림 권한 요청 (웹/앱 공통 필수!)
    // 2. 권한 요청 & 구독은 '비동기'로 따로 처리 (await 삭제!)
    _setupMessaging().catchError((e) => print("⚠️ Messaging setup error: $e"));
 } catch (e) {
    print("❌ Critical initialization error: $e");
 }
  
  runApp(const MyApp());
}

Future<void> _setupMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // 1. 현재 권한 상태를 먼저 확인 (팝업 안 뜸)
  NotificationSettings currentSettings = await messaging.getNotificationSettings();

  // 2. 결정되지 않았을 때만 권한 요청 팝업을 띄움
  if (currentSettings.authorizationStatus == AuthorizationStatus.notDetermined) {
    print("🔔 권한 결정 전: 팝업을 띄웁니다.");
    currentSettings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // 3. 허용된 상태라면 토큰 작업 진행
  if (currentSettings.authorizationStatus == AuthorizationStatus.authorized) {
    print("✅ 알림 권한이 허용된 상태입니다.");
    String? token = await messaging.getToken(vapidKey: AppConfig.vapidKey);
    print("토큰 값 : $token");
    
    if (token != null) {
      await registerTokenWithServer(token);
    }

    // await FirebaseMessaging.instance.subscribeToTopic(AppConfig.topicName); // subscribeToTopic 은 모바일용!!
    // print("✅ 'club_all' 토픽 구독 완료!");

    // [포그라운드 리스너] - 앱 켜져 있을 때도 알림을 띄워주는 감시자
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔔 포그라운드 메시지 수신: ${message.notification?.title}");

      if (message.notification != null) {
        // 앱이 켜져 있어도 시스템 알림을 강제로 호출 (중복 방지 로직은 브라우저가 처리)
        web.Notification(
          message.notification!.title ?? '제주양궁클럽',
          web.NotificationOptions(
            body: message.notification!.body ?? '',
            icon: '/icons/bow-and-arrow.png',
            tag: 'jejuac-notification',
          ),
        );
      }
    });
  } else {
    print("🚫 알림 권한이 거부되었거나 제한됨");
  }
}

// 서버에 토큰을 전달하여 'club_all' 토픽에 등록하게 하는 함수
Future<void> registerTokenWithServer(String token) async {
  try {
    // constants.dart에 정의된 baseUrl을 사용하여 경로 설정
    final url = Uri.parse(Config.registerToken); 
    
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"token": token}),
    );

    if (response.statusCode == 200) {
      print("🚀 서버에 토큰 등록 성공 (전체 공지 구독 완료)");
    } else {
      print("❌ 서버 토큰 등록 실패: ${response.statusCode} - ${response.body}");
    }
  } catch (e) {
    print("❌ 서버 통신 에러: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '제주양궁클럽',
      debugShowCheckedModeBanner: false,
      
      // 🏹 [핵심] 한국어 설정을 위한 대리자(Delegates) 리스트
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        SfGlobalLocalizations.delegate, // 🏹 Syncfusion 내부 텍스트(Today 등)를 한국어로!
      ],
      
      // 🏹 앱이 지원하는 언어 설정
      supportedLocales: const [
        Locale('ko', 'KR'),
      ],
      
      // 🏹 기본 언어를 한국어로 고정
      locale: const Locale('ko', 'KR'),

      theme: ThemeData(
        primaryColor: const Color(0xFF166534),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF166534)),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoggedIn = false;
  String _userName = "";
  String _userRole = "";
  String _userId = "";

  // 로그인 성공 시 호출될 콜백 함수
  void _handleLoginSuccess(String name, String role, String id) {
    //print("여기 왔니?");

    setState(() {
      _isLoggedIn = true;
      _userName = name;
      _userRole = role;
      _userId = id;
    });

    //print("화면 전환 상태: $isLoggedIn");
  }

  // 로그아웃 함수 (영님의 main.py 로직 반영)
  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
      _userName = "";
      _userRole = "";
      _userId = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    // _MyHomePageState 클래스의 build 함수 내부

    if (_isLoggedIn) {
      return MainDashboard(userName: _userName, userRole: _userRole, userId: _userId, onLogout: _handleLogout);
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white, // 배경을 깔끔하게 화이트로
        body: Column(
          children: [
            _buildHeader(), // 로고 영역
            
            const SizedBox(height: 10),
            // --- 탭 바 디자인 개선 ---
            Container(
              color: const Color(0xFF166534), // 헤더와 동일한 진녹색 배경
              child: const TabBar(
                tabs: [
                  Tab(text: '로그인'),
                  Tab(text: '사용자 등록'), // 이름 변경!
                ],
                indicatorColor: Colors.white,      // 밑줄 흰색
                indicatorWeight: 3,                // 밑줄 두께
                labelColor: Colors.white,          // 선택된 탭 글자색
                unselectedLabelColor: Colors.white70, // 선택 안 된 탭 글자색
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            
            // --- 탭 내용 영역 ---
            Expanded(
              child: TabBarView(
                children: [
                  SingleChildScrollView(child: LoginFormWidget(onLoginSuccess: _handleLoginSuccess)),
                  const SingleChildScrollView(child: RegisterFormWidget()), 
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: const BoxDecoration(
        color: Color(0xFF166534), // 영님의 초록색 테마 유지
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(60),
          bottomRight: Radius.circular(60),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. [로고] 영님의 bow-and-arrow.svg 파일을 불러옵니다!
          SvgPicture.asset(
            'assets/bow-and-arrow.svg', // assets 폴더 안에 있을 거라고 믿습니다!
            width: 80, // 크기는 svg 자체를 조절하는 것처럼 width로!
            height: 80,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn), // 하얀색 로고로!
          ),
          const SizedBox(height: 15),
          
          // 2. [타이틀] JEJU ARCHERY
          const Text(
            'JEJU ARCHERY', 
            style: TextStyle(
              color: Colors.white, 
              fontSize: 28, 
              fontWeight: FontWeight.bold, 
              letterSpacing: 2
            ),
          ),
          
          // 3. [서브타이틀] 제주양궁클럽
          const Text(
            '제주양궁클럽', 
            style: TextStyle(
              color: Colors.white70, 
              fontSize: 16
            ),
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final Function(String, String, String) onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🏹 제주양궁클럽'),
          backgroundColor: const Color(0xFF166534),
          bottom: const TabBar(
            tabs: [
              Tab(text: '로그인', icon: Icon(Icons.login)),
              Tab(text: '회원가입 (초대자)', icon: Icon(Icons.person_add)),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
          ),
        ),
        body: TabBarView(
          children: [
            // 1번 탭: 로그인 폼
            LoginFormWidget(onLoginSuccess: widget.onLoginSuccess),
            // 2번 탭: 회원가입 폼
            const RegisterFormWidget(),
          ],
        ),
      ),
    );
  }
}

// --- [독립된 클래스] 로그인 폼 위젯 ---
class LoginFormWidget extends StatefulWidget {
  final Function(String, String, String) onLoginSuccess;
  const LoginFormWidget({super.key, required this.onLoginSuccess});

  @override
  State<LoginFormWidget> createState() => _LoginFormWidgetState();
}

class _LoginFormWidgetState extends State<LoginFormWidget> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();

  Future<void> _login() async {
    //print("로그인 버튼 클릭됨");
    try {
      final response = await http.post(
        Uri.parse(Config.appLogin),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{
          'userid': _idController.text,
          'password': _pwController.text,
        }),
      ).timeout(const Duration(seconds: 5));

      //print("✅ 서버 응답: ${response.statusCode}");
      //print("📝 본문: ${response.body}");

      final data = jsonDecode(response.body);
      if (data['success']) {
        if(mounted) {
          widget.onLoginSuccess(data['user']['name'], data['user']['role'], data['user']['id']);
        }
      } else {
        _showError(data['message']);
      }
    } catch (e) {
      _showError("서버 연결 실패: $e");
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(controller: _idController, decoration: const InputDecoration(labelText: '아이디', prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 15),
            TextField(controller: _pwController, decoration: const InputDecoration(labelText: '비밀번호', prefixIcon: Icon(Icons.lock)), obscureText: true),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF166534),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('로그인'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- [독립된 클래스] 초대자 등록 위젯 ---
class RegisterFormWidget extends StatefulWidget {
  const RegisterFormWidget({super.key});

  @override
  State<RegisterFormWidget> createState() => _RegisterFormWidgetState();
}

class _RegisterFormWidgetState extends State<RegisterFormWidget> {
  // 컨트롤러 6개 (비밀번호 확인 포함)
  final _userIdController = TextEditingController();
  final _pwController = TextEditingController();
  final _pwConfirmController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  Future<void> _handleRegister() async {
    // 1. 유효성 검사: 빈 칸 확인
    if (_userIdController.text.isEmpty || _pwController.text.isEmpty || 
        _nameController.text.isEmpty || _emailController.text.isEmpty) {
      _showMessage("모든 필수 정보를 입력해주세요.", Colors.orange);
      return;
    }

    // 2. 유효성 검사: 비밀번호 일치 확인
    if (_pwController.text != _pwConfirmController.text) {
      _showMessage("비밀번호가 일치하지 않습니다.", Colors.red);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(Config.mngrRegister), // 영님의 FastAPI 엔드포인트
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userid': _userIdController.text.trim(),
          'password': _pwController.text.trim(),
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success']) {
        _showMessage("가입 성공! 로그인 탭에서 접속해주세요.", Colors.green);
        // 성공 시 입력 필드 초기화 로직을 넣거나 탭 이동 처리를 할 수 있습니다.
      } else {
        _showMessage(data['message'], Colors.red);
      }
    } catch (e) {
      _showMessage("서버 연결 실패: $e", Colors.red);
    }
  }

  void _showMessage(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Text("초대받은 정보로 회원가입을 진행하세요.", 
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534))),
            const SizedBox(height: 20),
            
            // 입력 필드들
            _buildTextField(_userIdController, "아이디", Icons.person_outline),
            _buildTextField(_emailController, "초대받은 이메일", Icons.email_outlined),
            _buildTextField(_nameController, "이름", Icons.badge_outlined),
            _buildTextField(_phoneController, "전화번호 (예: 010-1234-5678)", Icons.phone_android),
            _buildTextField(_pwController, "비밀번호", Icons.lock_outline, isObscure: true),
            _buildTextField(_pwConfirmController, "비밀번호 확인", Icons.lock_reset, isObscure: true),
            
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF166534),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              child: const Text("가입 완료", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 텍스트 필드 중복 코드를 줄이기 위한 위젯 함수
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isObscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF166534)),
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF166534), width: 2)),
        ),
      ),
    );
  }
}

// --- 메인 대시보드 위젯 (영님의 main.py 메뉴 8개 반영) ---
class MainDashboard extends StatelessWidget {
  final String userName;
  final String userRole;
  final String userId;
  final VoidCallback onLogout;

  const MainDashboard({super.key, required this.userName, required this.userRole, required this.userId, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    // [메인 테마 컬러] 제주양궁클럽의 딥그린
    const Color primaryGreen = Color(0xFF166534);

    final List<Map<String, dynamic>> menus = [
      {'title': '공지사항', 'icon': Icons.campaign, 'colors': [Colors.orange, Colors.deepOrangeAccent]},
      {'title': '클럽 일정', 'icon': Icons.calendar_month, 'colors': [Colors.blue, Colors.lightBlueAccent]},
      {'title': 'To-do List', 'icon': Icons.task_alt, 'colors': [Colors.green, Colors.lightGreenAccent]},
      {'title': '회원 관리', 'icon': Icons.groups, 'colors': [Colors.indigo, Colors.indigoAccent]},
      {'title': '결제 관리', 'icon': Icons.payments, 'colors': [Colors.teal, Colors.tealAccent]},
      {'title': '장비 관리', 'icon': Icons.handyman, 'colors': [Colors.brown, Colors.orangeAccent]},
      {'title': '개인정보', 'icon': Icons.manage_accounts, 'colors': [Colors.blueGrey, Colors.grey]},
    ];

    if (userRole == 'Admin') {
      menus.add({'title': '사용자 초대', 'icon': Icons.forward_to_inbox, 'colors': [Colors.pink, Colors.redAccent]});
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // 배경을 아주 연한 회색으로 해서 카드가 돋보이게!
      appBar: AppBar(
        title: Text('$userName님 ($userRole)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(onPressed: onLogout, icon: const Icon(Icons.logout))],
      ),
      body: Column(
        children: [
          // 상단에 살짝 포인트를 주는 장식 (선택사항)
          Container(height: 10, decoration: const BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)))),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              // 핵심: 한 줄에 3개 배치!
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, 
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85, // 카드의 세로 비율 살짝 조정
              ),
              itemCount: menus.length,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Material(
                      color: Colors.white,
                      child: InkWell(
                        onTap: () {
                          // 클릭된 메뉴의 제목을 확인합니다.
                          final String title = menus[index]['title'];
                          
                          if (title == '사용자 초대') {
                            // 화면 전환
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const UserInviteScreen()),
                            );
                          } 
                          else if (title == '개인정보') { 
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileUpdateScreen(userId: userId),
                              ),
                            );     
                          }
                          else if ( title == '클럽 일정' ) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ClubCalendarScreen(userId: userId),
                              ),
                            );                             
                          } 
                          else if (title == '회원 관리') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MngMemberScreen(userId: userId),
                              ),
                            );
                          } 
                          else if (title == '공지사항') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NoticeScreen(userRole: userRole, userName: userName),
                              ),
                            );  
                          } else {
                            // 아직 구현 안 된 메뉴들은 그냥 출력만!
                            print("$title 클릭됨 - 아직 화면이 연결되지 않았습니다.");
                            
                            // (선택사항) "준비 중입니다" 알림 띄우기
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("$title 기능은 준비 중입니다! 🏹")),
                            );
                          }
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 그라데이션 아이콘 배경
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: menus[index]['colors'],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Icon(menus[index]['icon'], size: 28, color: Colors.white),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              menus[index]['title'],
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                              textAlign: TextAlign.center,
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
    );
  }
}