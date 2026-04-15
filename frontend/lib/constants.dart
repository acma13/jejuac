// lib/constants.dart
// 서버 주소 환경변수 설정

class Config {
  // 🏹 개발 중일 때 (컴퓨터에서 테스트)
  // 안드로이드 에뮬레이터라면 10.0.2.2를 써야 하고, 실제 폰이면 컴퓨터 IP를 써야 합니다.
  // static const String baseUrl = "http://10.0.2.2:8000"; 

  // 로컬호스트용 (웹)
  //static const String baseUrl = "http://localhost:5000";
  
  // 🏹 나중에 실제 서버에 올렸을 때 (배포용)
  // static const String baseUrl = "http://158.180.89.23:5000";

  // 실제 서버는 이것으로 사용 할 것!!!
  static const String baseUrl = "https://jejuac.duckdns.org/api";

  // 사용자 등록 및 로그인 관련
  static const String invitedEmails = "$baseUrl/api/invited-emails";
  static const String inviteEmail = "$baseUrl/api/invite-email";
  static const String getUser = "$baseUrl/api/get_user";
  static const String updateProfile = "$baseUrl/api/update_profile";
  static const String appLogin = "$baseUrl/api/login";
  static const String mngrRegister = "$baseUrl/api/register";
  // 클럽일정 관련
  static const String addSchedule = "$baseUrl/api/insert_club_schedule";
  static const String getSchedule = "$baseUrl/api/get_schedules";
  static const String updateSchedule = "$baseUrl/api/update_schedule";
  static const String deleteSchedule = "$baseUrl/api/delete_schedule";
  // 회원관리 관련
  static const String addMember = "$baseUrl/api/insert_member";
  static const String getMembersInfo = "$baseUrl/api/get_members";
  static const String updateMember = "$baseUrl/api/update_member";
  static const String deleteMember = "$baseUrl/api/delete_member";

  
}