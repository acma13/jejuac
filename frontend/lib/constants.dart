// lib/constants.dart
// 서버 주소 환경변수 설정

class Config {
  // 🏹 개발 중일 때 (컴퓨터에서 테스트)
  // 안드로이드 에뮬레이터라면 10.0.2.2를 써야 하고, 실제 폰이면 컴퓨터 IP를 써야 합니다.
  // static const String baseUrl = "http://10.0.2.2:8000"; 

  // 로컬호스트용 (웹)
  static const String baseUrl = "http://localhost:5000";
  
  // 🏹 나중에 실제 서버에 올렸을 때 (배포용)
  // static const String baseUrl = "http://158.180.89.23:5000";

  // 실제 서버는 이것으로 사용 할 것!!!
  //static const String baseUrl = "https://jejuac.duckdns.org/api";

  // 사용자 등록 및 로그인 관련
  static const String invitedEmails = "$baseUrl/api/invited-emails";
  static const String inviteEmail = "$baseUrl/api/invite-email";
  static const String getUser = "$baseUrl/api/get_user";
  static const String updateProfile = "$baseUrl/api/update_profile";
  static const String appLogin = "$baseUrl/api/login";
  static const String mngrRegister = "$baseUrl/api/register";
  // 사용자 초대 화면에서 사용자에 대한 처리 관련
  static const String getAllUsers = "$baseUrl/api/get_all_users";
  static const String updateUserRole = "$baseUrl/api/update_user_role";
  static const String deleteUser = "$baseUrl/api/delete_user";
  static const String resetPassword = "$baseUrl/api/reset_password";

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
  static const String getMemberPayments = "$baseUrl/api/get_member_payments";
  // 공지사항 관련
  static const String getNotices = "$baseUrl/api/get_notices";
  static const String addNotice = "$baseUrl/api/add_notice";
  static const String updateNotice = "$baseUrl/api/update_notice";
  static const String deleteNotice = "$baseUrl/api/delete_notice";
  // 알림 관련
  static const String registerToken = "$baseUrl/api/register_token";
  static const String updateToken = "$baseUrl/api/update_fcm_token";
  // TO-DO List 관련
  static const String getTodos = "$baseUrl/api/get_todos";
  static const String addTodo = "$baseUrl/api/add_todo";
  static const String updateTodoContent = "$baseUrl/api/update_todo_content";
  static const String updateTodoStatus = "$baseUrl/api/update_todo_status";
  static const String deleteTodo = "$baseUrl/api/delete_todo";
  // 장비 관련 
  static const String getActiveMembers = "$baseUrl/api/get_active_members"; // 활동중인 회원 목록
  static const String getPresentStock = "$baseUrl/api/get_present_stock"; // 현재재고 가져오기
  static const String getOutMemberStock = "$baseUrl/api/get_out_member_stock"; // 해당 회원에 출고된 재고 가져오기
  static const String getEquipmentHistoryExists = "$baseUrl/api/check_equipment_history_exists";  // 입출고내역 있는지 확인
  static const String getEquipments = "$baseUrl/api/get_equipments"; // 장비 목록
  static const String getTradeList = "$baseUrl/api/get_trade_list"; // 장비 입출고 내역
  static const String addEquipment = "$baseUrl/api/add_equipment"; // 장비 등록
  static const String updateEquipment = "$baseUrl/api/update_equipment"; // 장비 수정
  static const String deleteEquipment = "$baseUrl/api/delete_equipment"; // 장비 삭제 (장비 입출고 내역이 있으면 삭제 불가)
  static const String addTradeList = "$baseUrl/api/add_trade_list"; // 장비 입출고 내역 등록
  static const String getCancelLimitInfo = "$baseUrl/api/get_cancel_limit_info";  // 특정회원의 마지막 출고 기록 조회

  // 결제 관련
  static const String addPayment = "$baseUrl/api/add_payment";
  static const String getPayments = "$baseUrl/api/get_payments";
  static const String updatePayment = "$baseUrl/api/update_payment";
  static const String deletePayment = "$baseUrl/api/delete_payment";
  
  // 데이터 마이그레이션 관련
  static const String uploadMembersList = "$baseUrl/api/upload_members_list";
  static const String uploadSecheduleList = "$baseUrl/api/upload_schedule_list";
  static const String uploadTodoList = "$baseUrl/api/upload_todo_list";
  static const String uploadPaymentsList = "$baseUrl/api/upload_payments_list";
  static const String uploadInvitedEmail = "$baseUrl/api/upload_invited_email";
  
  // Q&A 관련
  static const String addQna = "$baseUrl/api/add_qna";
  static const String getQnaList = "$baseUrl/api/get_qna_list";
  static const String answerQna = "$baseUrl/api/answer_qna";
  static const String deleteQna = "$baseUrl/api/delete_qna";
  static const String updateQna = "$baseUrl/api/update_qna";
}