# app.py (API 서버로 전면 개조)
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
from contextlib import asynccontextmanager
from typing import Optional
import database as db
import auth
import re
import os
import firebase_admin
import io
import pandas as pd
import asyncio
import random
from firebase_admin import credentials, messaging
from config import initialize_firebase, FCM_TOPIC_NAME, FRONTEND_PATH, FCM_ADMIN_TOPIC

# 4. 초기화: DB 연결
# 1. 서버가 켜질 때와 꺼질 때 할 일을 정의하는 'Lifespan' 함수
@asynccontextmanager
async def lifespan(app: FastAPI):
    # [Startup] 서버가 시작될 때 실행 (기존 @app.on_event("startup"))
    db.init_db()
    print("🎯 제주양궁클럽 DB 초기화 완료! (최신 방식)")
    
    yield  # 서버가 돌아가는 동안은 여기서 대기합니다.

    # [Shutdown] 서버가 종료될 때 실행할 일이 있다면 여기에 작성
    print("👋 서버를 종료합니다.")

# 2. FastAPI 앱 선언 시 lifespan을 연결해줍니다.
app = FastAPI(title="제주양궁클럽 API", lifespan=lifespan, redirect_slashes=False)

# ---- 플러터 빌드

# app = FastAPI() 바로 아래에 추가
app.mount("/web", StaticFiles(directory=FRONTEND_PATH), name="web")

# 3. 메인 접속 시 index.html 반환
@app.get("/")
async def read_index():
    index_path = os.path.join(FRONTEND_PATH, "index.html")
    return FileResponse(index_path)

# 2. CORS 설정 (플러터 웹에서 접속 허용)
# 다른 도메인(플러터 웹)에서 이 파이썬 서버에 접근할 수 있게 해줍니다.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 모든 곳에서 접속 허용 (개발용)
    allow_credentials=True,
    allow_methods=["*"],  # 모든 HTTP 메서드 허용 (GET, POST 등)
    allow_headers=["*"],
)

# def send_fcm_notification(token, title, body):
#     """
#     FCM 토큰을 사용하여 특정 기기에 푸시 알림을 전송합니다.
#     """
#     try:
#         message = messaging.Message(
#             notification=messaging.Notification(
#                 title=title,
#                 body=body,
#             ),
#             token=token,
#         )
#         response = messaging.send(message)
#         print(f'✅ 알림 전송 성공: {response}')
#         return True
#     except Exception as e:
#         print(f'❌ 알림 전송 실패: {e}')
#         return False

# -------------- 공지사항 알림 관련 start ---------------
# 1. Firebase 초기화 (파일명 확인!)

# base_dir = os.path.dirname(os.path.abspath(__file__))
# sdk_path = os.path.join(base_dir, "firebase_admin_sdk.json")

# if not firebase_admin._apps:
#     try:
#         if not os.path.exists(sdk_path):
#             print(f"❌ 파일을 찾을 수 없습니다: {sdk_path}")
#         else:
#             cred = credentials.Certificate(sdk_path) 
#             firebase_admin.initialize_app(cred)
#             print("✅ Firebase Admin SDK 초기화 성공")
#     except Exception as e:
#         print(f"❌ Firebase 초기화 실패: {e}")

# 위 내용은 config.py 로 이관

initialize_firebase()

# 2. 웹 푸시 발송 함수
async def send_fcm_notification(p_data):
    print(f"🚀 알림 함수 진입: {p_data}")
    try:
        # 1. 공통 데이터 추출 (add_notice나 add_qna에서 보낸 값들)
        title = p_data.get("title")
        body = p_data.get("body")
        data_type = p_data.get("type", "notice")  # 구분자 (기본값 notice)
        token = p_data.get("token")
        target_topic = p_data.get("target")       # FCM_TOPIC_NAME 또는 FCM_ADMIN_TOPIC

        # 2. 메시지 구성 (아이폰 중복 방지를 위해 notification은 주석 유지) [cite: 2]
        message = messaging.Message(
            data={
                "title": title,
                "body": body,
                "type": data_type                
            },
            webpush=messaging.WebpushConfig(
                notification=messaging.WebpushNotification(
                    # fcm_options=messaging.WebpushFCMOptions(
                    #     link="/" # 클릭 시 이동할 기본 경로
                    # ),
                ),
            ),            
        )

        if token:
            message.token = token
            print(f"📱 개인 토큰으로 발송 시도: {token[:10]}...")
        elif target_topic:
            message.topic = target_topic
            print(f"📢 토픽으로 발송 시도: {target_topic}")
        else:
            print("⚠️ 발송 대상(token 또는 target)이 없습니다.")
            return
        
        response = messaging.send(message)
        print(f"🚀 푸시 발송 성공 ({data_type}): {response}")
    except Exception as e:
        print(f"❌ 푸시 발송 실패: {e}")


@app.post("/api/register_token")
async def register_token(data: dict):
    token = data.get("token")
    if not token:
        return {"status": "error", "message": "토큰이 없습니다."}
    
    try:
        # 서버 SDK가 직접 이 토큰을 'club_all' 토픽에 가입시킵니다.
        # 웹(PWA) 에러를 해결하는 핵심 코드입니다.
        response = messaging.subscribe_to_topic([token], FCM_TOPIC_NAME)
        
        print(f"✅ 기기 구독 성공: {response.success_count}건")
        return {"status": "success"}
    except Exception as e:
        print(f"❌ 구독 처리 에러: {e}")
        return {"status": "error", "message": str(e)}

class TokenUpdateRequest(BaseModel):
    user_id: str
    fcm_token: str
    user_role: str

@app.post("/api/update_fcm_token")
async def update_fcm_token(req: TokenUpdateRequest):
       
    if db.update_user_token(req):
        if req.user_role == "Admin":
            try:
                messaging.subscribe_to_topic([req.fcm_token], FCM_ADMIN_TOPIC)
                print(f"🎯 관리자 토픽 강제 구독 성공: {req.user_id}")
            except Exception as e:
                print(f"❌ 관리자 토픽 구독 실패: {e}")
        return {"success": True}
    return {"success": False}
    
# -------------- 공지사항 알림 관련 end ---------------

# 로그인 처리

class LoginRequest(BaseModel):
    userid: str
    password: str

@app.post("/api/login")
def login_user(req: LoginRequest):
    # auth.py 에서 함수 호출 (영님의 로직 재활용)
    user_info = auth.login_user(req.userid, req.password)

    if user_info:
        # 로그인 성공: 회원 정보와 권한(role)을 JSON으로 반환
        return {
            "success": True,
            "message": f"{user_info['name']}님, 환영합니다!",
            "user": {
                "id": user_info['userid'],
                "name": user_info['name'],
                "role": user_info['role']  # 영님이 강조하신 Role!
            }
        }
    else:
        # 로그인 실패: 에러 메시지 반환
        return {"success": False, "message": "아이디 또는 비밀번호가 일치하지 않습니다."}

# 6. [API 엔드포인트 2] 회원가입 처리

class RegisterRequest(BaseModel):
    email: str
    name: str
    userid: str
    phone: str
    password: str

@app.post("/api/register")
def register_user(req: RegisterRequest):
    # --- [Step 1: 형식 검증 (영님의 규칙 재활용)] ---
    # 아이디 형식 확인 (영문의 숫 조합 4~15자)
    id_pattern = r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{4,15}$'
    if not re.match(id_pattern, req.userid):
        return {"success": False, "message": "⚠️ 아이디 형식이 올바르지 않습니다. (영문/숫자 조합 4~15자)"}

    # 비밀번호 형식 확인 (영문/숫자 포함 6자 이상)
    if not (len(req.password) >= 6 and any(c.isdigit() for c in req.password) and any(c.isalpha() for c in req.password)):
        return {"success": False, "message": "⚠️ 비밀번호 형식이 올바르지 않습니다. (영문/숫자 포함 6자 이상)"}

    # --- [Step 2: 가입 실행 (db.py 서비스 호출)] ---
    # 영님의 db.register_user_with_invitation 함수 호출
    success, message = db.register_user_with_invitation(
        req.userid, req.password, req.name, req.email, req.phone
    )
    
    return {"success": success, "message": message}

# 7. 기본 경로 확인 (테스트용)
@app.get("/")
def read_root():
    return {"status": "running", "message": "제주양궁클럽 API 서버가 작동 중입니다."}

# 가입자 초대 목록 및 추가 관련 API
# [API 1] 가입 허용 이메일 목록 가져오기
@app.get("/api/invited-emails")
async def get_invited_emails():
    try:
        # DB에서 목록 가져오기 (이미 만들어두신 함수 활용)
        emails = db.get_invited_emails()
        # 리스트 형태이므로 보기 좋게 반환
        return {"status": "success", "data": emails}
    except Exception as e:
        return {"status": "error", "message": str(e)}

# [API 2] 신규 이메일 등록하기
class inviteEmailRequest(BaseModel):
    email: str    

@app.post("/api/invite-email")
async def invite_email(req: inviteEmailRequest):
    target_email = req.email
    if not target_email:
        return {"status": "error", "message": "이메일을 입력해주세요."}
    
    try:
        if db.add_invitation_email(target_email):
            return {"status": "success", "message": f"{target_email} 등록 완료!"}
        else:
            return {"status": "error", "message": "이미 등록된 이메일이거나 오류가 발생했습니다."}
    except Exception as e:
        return {"status": "error", "message": str(e)}
    
# 가입자 정보 조회    
@app.get("/api/get_user/{userid}")
def get_user(userid: str):
    user_data = db.get_user_by_id(userid) 
    if user_data:
        return user_data
    return {"error": "User not found"}, 404

# 가입자 정보 업데이트
# 1. 요청 데이터를 받을 규격 (Pydantic 모델)
class UpdateProfileRequest(BaseModel):
    userid: str
    current_password: str
    name: str
    phone: str
    new_password: Optional[str] = None

@app.post("/api/update_profile")
def update_profile(req: UpdateProfileRequest):
    # [단계 1] DB에서 해당 유저의 현재 정보를 가져옴
    user = db.get_user_by_id(req.userid)
    if not user:
        #print("1")
        return {"success": False, "message": "사용자를 찾을 수 없습니다."}

    # [단계 2] 현재 비밀번호가 맞는지 검증 (auth.py의 check_hashes 활용)
    # user['password']는 DB에 저장된 해시값입니다.
    if not auth.check_hashes(req.current_password, user['password']):
        #print("2")
        return {"success": False, "message": "현재 비밀번호가 일치하지 않습니다."}

    # [단계 3] DB 업데이트 실행
    # new_password가 있으면 새 해시를 만들고, 없으면 기존 정보를 유지하는 로직
    result = db.update_user_profile(
        userid=req.userid,
        name=req.name,
        phone=req.phone,
        password=req.new_password  # None이면 database.py에서 알아서 처리함
    )

    if result:
        return {"success": True, "message": "성공적으로 수정되었습니다!"}
    else:
        #print("3")
        return {"success": False, "message": "DB 업데이트 중 오류가 발생했습니다."}
    
# --------- 가입된 유저 관련 ---------------
class RoleUpdateRequest(BaseModel):
    userid: str
    role: str

class UserDeleteRequest(BaseModel):
    userid: str  # 화면에서 보내는 키값과 일치해야 함

# 등록된 모든 유저 정보
@app.get("/api/get_all_users")
async def get_all_users():
    return {"status": "success", "data": db.get_all_users()}

# 유저 권한 수정
@app.post("/api/update_user_role")
async def update_user_role(req: RoleUpdateRequest):
    if db.update_user_role(req):
        return {"status": "success", "message": "권한이 변경되었습니다."}
    return {"status": "error", "message": "수정 실패"}

# 유저 삭제
@app.post("/api/delete_user")
async def delete_user(req: UserDeleteRequest):
    
    if db.delete_user(req):
        return {"status": "success", "message": "사용자가 삭제되었습니다."}
    return {"status": "error", "message": "삭제 실패"}
    
# 등록된 클럽 일정 조회
@app.get("/api/get_schedules")
async def get_schedules():
    schedules = db.get_all_schedules()
    return schedules  # FastAPI가 자동으로 JSON 리스트로 변환해줍니다.

# 클럽 일정 및 수정에 대한 전용 규격(모델)
class scheduleRequest(BaseModel):
    id: Optional[str] = None
    userid: Optional[str] = None
    title: str
    location: str
    manager: str
    start_date: str
    end_date: str
    content: Optional[str] = None
    color: int
    use_alarm: bool

class deleteScheduleRequest(BaseModel):
    id: str

# 클럽 일정 등록
@app.post("/api/insert_club_schedule")
async def insert_club_schedule(req: scheduleRequest):

    try:
        result = db.insert_club_schedule(req)
        if result:
            return {"status": "success"}
        else:
            return {"status": "error", "message": "DB 저장 실패"}
    except Exception as e:
        return {"status": "error", "message": str(e)}
    
# 클럽 일정 수정
@app.post("/api/update_schedule")
async def api_update_schedule(req: scheduleRequest):
    try:
               
        # 2. 필수 값인 'id'가 있는지 확인 (제주양궁클럽의 안전장치!)
        if not req.id:
            return {"success": False, "message": "수정할 일정 ID가 없습니다."}

        # 3. DB 업데이트 함수 호출
        result = db.update_schedule(req)

        if result:
            return {"success": True, "message": "일정이 성공적으로 수정되었습니다."}
        else:
            return {"success": False, "message": "DB 업데이트 중 오류가 발생했습니다."}

    except Exception as e:
        print(f"❌ 수정 API 에러: {e}")
        return {"success": False, "message": str(e)}

# 클럽 일정 삭제

@app.post("/api/delete_schedule")
async def api_delete_schedule(req: deleteScheduleRequest):
    try:
        # 1. 삭제할 ID 데이터 받기 {"id": "123"}
        # data = await request.json()
        event_id = req.id

        if not event_id:
            return {"success": False, "message": "삭제할 일정 ID가 없습니다."}

        # 2. DB 삭제 함수 호출
        result = db.delete_schedule(event_id)

        if result:
            return {"success": True, "message": "일정이 삭제되었습니다."}
        else:
            return {"success": False, "message": "DB 삭제 중 오류가 발생했습니다."}

    except Exception as e:
        print(f"❌ 삭제 API 에러: {e}")
        return {"success": False, "message": str(e)}
    

# 회원관리 관련 API
# 데이터 모델 정의
class addMember(BaseModel):
    name: str
    phone: str
    birth: str
    member_class: str
    is_active: bool
    created_by : str

class modifyMember(BaseModel):
    id: int
    name: str
    phone: str
    birth: str
    member_class: str
    is_active: bool

class memberIdRequest(BaseModel):
    id: int

@app.post("/api/insert_member")
async def insert_member(req: addMember):
    success, message = db.insert_member(req)
    
    if success:
        return {"status": "success"}
    elif message == "duplicate":
        raise HTTPException(status_code=400, detail="이미 등록된 이름과 생년월일입니다.")
    else:
        raise HTTPException(status_code=500, detail="DB 저장 실패")
    
@app.get("/api/get_members")
async def get_members():
    memberlist = db.get_all_members()
    return memberlist

# 회원 정보 수정
@app.post("/api/update_member")
async def update_member(req: modifyMember):
    try:
               
        # 2. 필수 값인 'id'가 있는지 확인 (제주양궁클럽의 안전장치!)
        if not req.id:
            return {"success": False, "message": "수정할 회원 ID가 없습니다."}

        # 3. DB 업데이트 함수 호출
        result = db.update_member(req)

        if result:
            return {"success": True, "message": "회원정보가 성공적으로 수정되었습니다."}
        else:
            return {"success": False, "message": "DB 업데이트 중 오류가 발생했습니다."}

    except Exception as e:
        print(f"❌ 수정 API 에러: {e}")
        return {"success": False, "message": str(e)}
 
@app.post("/api/delete_member")
async def delete_member(req: memberIdRequest):
    try:
        # 1. 삭제할 ID 데이터 받기 {"id": "123"}
        # data = await request.json()
        member_id = req.id

        if not member_id:
            return {"success": False, "message": "삭제할 회원 ID가 없습니다."}

        # 2. DB 삭제 함수 호출
        result = db.delete_member(member_id)

        if result:
            return {"success": True, "message": "회원정보가 삭제되었습니다."}
        else:
            return {"success": False, "message": "DB 삭제 중 오류가 발생했습니다."}

    except Exception as e:
        print(f"❌ 삭제 API 에러: {e}")
        return {"success": False, "message": str(e)}
    
@app.get("/api/get_member_payments/{member_id}")
async def get_member_payments(member_id: int):        
    data = db.get_member_payments(member_id)
    return data
    
# ------ 공지사항 관련 API ----------

class NoticeRequest(BaseModel):
    title: str
    content: str
    is_important: bool
    author_name: str

class UpdateNoticeRequest(BaseModel):
    id: int
    title: str
    content: str
    is_important: bool

class DeleteNoticeRequest(BaseModel):
    id: int

@app.post("/api/add_notice")
async def add_notice(req: NoticeRequest):
    try:
        db.add_notice(req)
        #print("[Add_notice] 1. DB 저장 성공 (세션 생존 확인)")
        # 저장 성공 후 푸시 알림 발송
        try:
            #print("[Add_notice] 2. 푸시 발송 시도...")
            push_data = {
                "target": FCM_TOPIC_NAME,      # 전체 공지 토픽
                "title": f"🔔 [공지] {req.title}",
                "body": "새로운 공지사항이 등록되었습니다.",
                "type": "notice_alert"
            }
            asyncio.create_task(send_fcm_notification(push_data))
            #print("[Add_notice] 3. 푸시 발송 로직 통과")
        except Exception as push_e:
            print(f"[Add_notice] 4. 푸시만 실패(DB는 성공): {push_e}")

        return {"status": "success", "message": "공지가 등록되었습니다."}
    except Exception as e:
        print(f"[Add_notice] 에러: {e}")
        return {"status": "error", "message": str(e)}

@app.post("/api/update_notice")
async def update_notice(req: UpdateNoticeRequest):
    try:
        db.update_notice(req)
        return {"status": "success", "message": "공지가 수정되었습니다."}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.post("/api/delete_notice")
async def delete_notice(req: DeleteNoticeRequest):
    try:
        db.delete_notice(req)
        return {"status": "success", "message": "공지가 삭제되었습니다."}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.get("/api/get_notices")
async def get_notices():
    try:
        # database.py에서 딕셔너리 리스트로 가져온 데이터를 바로 반환
        notices = db.get_all_notices()        
        return {"status": "success", "data": notices}
    except Exception as e:
        return {"status": "error", "message": str(e)}
    
# ----------- TO_DO 관련 API ---------------

# 할 일 데이터 모델
class TodoAddRequest(BaseModel):
    title: str
    due_date: str
    assignee: str
    content: str
    attachment_url: Optional[str] = None
    created_by: Optional[str] = None

class TodoContentUpdateRequest(BaseModel):
    id: int  # Optional이 아니므로 없으면 에러 발생
    title: str
    due_date: str
    assignee: str
    content: str
    attachment_url: Optional[str] = None
    created_by: Optional[str] = None    

class TodoStatusUpdateRequest(BaseModel):
    id: int  # Optional이 아니므로 없으면 에러 발생
    is_completed: bool

class TodoDeleteRequest(BaseModel):
    id: int

# 할 일 목록 가져오기
@app.get("/api/get_todos")
async def get_todos():
    try:
        data = db.get_all_todos()
        return {"success": True, "data": data}
    except Exception as e:
        print(f"Get Content Error: {e}")
        return {"success": False, "data": [], "message": str(e)}

# 할 일 추가
@app.post("/api/add_todo")
async def add_todo(req: TodoAddRequest):
    try:
        result = db.add_todo(req)

        # TODO: 등록 시 알람 쏘는거 만들어야 함.
        #       공지 쏘던거랑 같이 쓰면 될 것 같은데 이 부분은 수정이 필요해보임.

        if result:
            try:
                push_data = {
                    "target": FCM_TOPIC_NAME,  # config에 정의된 전체 공지 토픽
                    "title": f"[TODO] {req.title}",
                    "body": "새로운 할 일이 등록되었습니다",
                    "type": "new_todo_alert"
                }
                
                # 비동기로 알림 발송 (서버 응답 속도에 영향을 주지 않음)
                asyncio.create_task(send_fcm_notification(push_data))
                
            except Exception as push_error:
                print(f"Todo 알림 발송 실패: {push_error}")

            return {"status": "success"}
        else:
            return {"status": "error", "message": "DB 저장 실패"}
    except Exception as e:
        print(f"Add Content Error: {e}")
        return {"success": False, "message": str(e)}

# [1] 내용 수정 API
@app.post("/api/update_todo_content")
async def update_content(req: TodoContentUpdateRequest): 
    try:
        result = db.update_todo_content(req)
        return {"success": result}
    except Exception as e:
        print(f"Update Content Error: {e}")
        return {"success": False, "message": str(e)}

# [2] 상태 변경 API (스와이프 전용)
@app.post("/api/update_todo_status")
async def update_status(req: TodoStatusUpdateRequest): 
    try:
        result = db.update_todo_status(req)
        return {"success": result}
    except Exception as e:
        print(f"Update Status Error: {e}")
        return {"success": False, "message": str(e)}

# 할 일 삭제
@app.post("/api/delete_todo")
async def delete_todo_api(req: TodoDeleteRequest):
    try: 
        # print(f"API 의 할 일 삭제 ID: {req.id}")

        result = db.delete_todo(req)

        return {"success": "success", "message": "할 일이 삭제되었습니다."}
    except Exception as e:
        print(f"Delete Content Error: {e}")
        return {"success": False, "message": str(e)}
    

# ----------- 장비 관련 API ---------------
# 할 일 데이터 모델
class EquipmentAddRequest(BaseModel):
    name: str
    spec: Optional[str] = ""
    location: Optional[str] = ""
    note: Optional[str] = ""
    stock: int = 0
    

class EquipmentUpdateRequest(BaseModel):
    id: int  # Optional이 아니므로 없으면 에러 발생
    name: str
    spec: Optional[str] = ""
    location: Optional[str] = ""
    note: Optional[str] = ""

class AddTradeInfoRequest(BaseModel):
    equipment_id : int
    member_id: Optional[int] = "",
    trade_type: str
    quantity: int
    unit_price: int
    total_price: int
    note: Optional[str] = ""
    processed_by: str


# 1. 활성 회원 목록 조회 (드롭박스용)
@app.get("/api/get_active_members")
async def api_get_active_members():    
    try:
        data = db.get_active_members_db()
        return {"success": True, "data": data}  
    except Exception as e:
        print(f"Get Content Error: {e}")
        return {"success": False, "data": [], "message": str(e)}
    
# 1.1. 현재재고 조회
@app.get("/api/get_present_stock/{equipmentid}")
async def api_get_present_stock(equipmentid: int):
    try:
        stock_count = db.get_equipment_stock(equipmentid)
        return {"success": True, "stock": stock_count}
    except Exception as e:
        print(f"Stock Fetch Error: {e}")
        return {"success": False, "stock": 0, "message": str(e)} 
    
# 1.2. 현 회원의 출고 수량 조회
@app.get("/api/get_out_member_stock/{equipmentId}/{memberId}")
async def api_get_member_stock(equipmentId: int, memberId: int):
    try:
        stock = db.get_member_out_stock(equipmentId, memberId)
        return {"success": True, "out_stock": stock}
    except Exception as e:
        return {"success": False, "message": str(e)}

# 1.3. 현 장비의 입출고 내역 존재 여부 확인
@app.get("/api/check_equipment_history_exists/{equipmentId}")
def check_history(equipmentId: int):
    try:
        has_history = db.check_equipment_history_exists(equipmentId)
        return {"success": True, "has_history": has_history}
    except Exception as e:
        return {"success": False, "message": str(e)}
    
# 2. 장비 목록 조회
@app.get("/api/get_equipments")
async def api_get_equipments():
    try:
        data = db.get_all_equipments()
        return {"success": True, "data": data}    
    except Exception as e:
        print(f"Get Content Error: {e}")
        return {"success": False, "data": [], "message": str(e)}
    

# 3. 장비 등록
@app.post("/api/add_equipment")
async def api_add_equipment(req: EquipmentAddRequest):    
    try:
        result = db.add_equipment_db(req)
        
        if result:
            return {"status": "success"}
        else:
            return {"status": "error", "message": "DB 저장 실패"}
    except Exception as e:
        print(f"Add Content Error: {e}")
        return {"success": False, "message": str(e)}

# 4. 장비 수정
@app.post("/api/update_equipment/equipmentId}")
async def api_update_equipment(req: EquipmentUpdateRequest):
    # update_equipment_db(data['id'], data)    
    try:
        result = db.update_equipment_db(req)
        return {"success": result}
    except Exception as e:
        print(f"Update Content Error: {e}")
        return {"success": False, "message": str(e)}

# 5. 장비 삭제
@app.post("/api/delete_equipment/{equipmentId}")
async def api_delete_equipment(equipmentId: int):
    try:
        result = db.delete_equipment_db(equipmentId)

        return {"success": "success", "message": "장비 내역이 삭제되었습니다."}
    except Exception as e:
        print(f"Delete Content Error: {e}")
        return {"success": False, "message": str(e)}

# 6. 입출고 내역 조회
@app.get("/api/get_trade_list/{equipmentId}")
async def api_get_trade_list(equipmentId: int):    
    try:
        data = db.get_trade_history(equipmentId)
        return {"success": True, "data": data}    
    except Exception as e:
        print(f"Get Content Error: {e}")
        return {"success": False, "data": [], "message": str(e)}

# 7. 입출고 내역 등록
@app.post("/api/add_trade_list")
async def api_add_trade(req: AddTradeInfoRequest):    
    # database.py에 만든 함수 호출
    success, msg = db.add_trade_record(req)
    
    if success:
        return {"success": True, "message": msg}
    else:
        # 실패 시 400 에러나 500 에러를 줄 수도 있지만, 
        # 우선 success: False로 처리해서 플러터에서 메시지를 띄우게 합니다.
        return {"success": False, "message": msg}
    
# 8. 특정회원의 최신 출고내역 조회
@app.get("/api/get_cancel_limit_info/{equipment_id}/{trade_type}")
async def api_get_cancel_limit_info(equipment_id: int, trade_type: str, member_id: Optional[int] = None):
    info = db.get_cancel_limit_info(equipment_id, trade_type, member_id)
    if info:
        return {"success": True, "unit_price": info['unit_price'], "quantity": info['quantity']}
    return {"success": False, "message": "해당 내역이 없습니다."}

# ---------------- 결제 관련 API ------------------------------

class AddPaymentRequest(BaseModel):
    member_id: int
    name: str
    pay_item: str
    pay_method: str
    target_month: Optional[str] = ""
    amount: int
    is_paid: bool
    note: Optional[str] = ""
    created_by: str

class UpdatePaymentRequest(BaseModel):
    id: int
    pay_item: str
    target_month: Optional[str] = ""
    pay_method: str
    amount: int
    is_paid: bool
    note: str

class deletePaymentRequest(BaseModel):
    id: int

@app.post("/api/add_payment")
async def api_add_payment(req: AddPaymentRequest):
    # TODO : 여기처럼 클래스를 넘겨줄 수 있음. 이것 참조해서 나머지도 다 바꿀 것
    if db.add_payment(req):         
        return {"status": "success", "message": "결제 정보가 등록되었습니다."}
    else:
        return {"status": "error", "message": "등록 실패"}

@app.get("/api/get_payments")
async def api_get_payments():
    data = db.get_all_payments()
    return data

@app.post("/api/update_payment")
async def api_update_payment(req: UpdatePaymentRequest):
    success = db.update_payment(req)
    if success:
        return {"status": "success", "message": "결제 정보가 수정되었습니다."}
    else:
        raise HTTPException(status_code=500, detail="수정에 실패했습니다.")

@app.post("/api/delete_payment")
async def api_delete_payment(req: deletePaymentRequest):
           
    success = db.delete_payment(req)
    if success:
        return {"status": "success", "message": "결제 정보가 삭제되었습니다."}
    else:
        raise HTTPException(status_code=500, detail="삭제에 실패했습니다.")


# ---------------- 데이터 마이그레이션 관련 API ----------------

class MigrationRequest(BaseModel):
    url: str
    admin_id: str
    data_type: str

def get_sheet_data(sheet_url: str, required_cols: list):
    try:
        # 1. URL 변환 로직 (공통)
        csv_url = sheet_url.replace('/edit?usp=sharing', '/export?format=csv')
        if '/edit#gid=' in csv_url:
            csv_url = csv_url.replace('/edit#gid=', '/export?format=csv&gid=')
        elif '/edit' in csv_url and '/export' not in csv_url:
            csv_url = csv_url.replace('/edit', '/export?format=csv')

        # 2. 데이터 읽기
        df = pd.read_csv(csv_url)
        
        # 3. 필수 컬럼 검사 (공통)
        current_cols = df.columns.tolist()
        missing_cols = [col for col in required_cols if col not in current_cols]
        
        if missing_cols:
            raise Exception(f"빠진 항목: {', '.join(missing_cols)}")
            
        return df
    except Exception as e:
        raise Exception(f"시트 읽기 실패: {str(e)}")

@app.post("/api/upload_members_list")
async def upload_members_list(req: MigrationRequest):
    sheet_url = req.url
    admin_id = req.admin_id

    # 회원 등록에 꼭 필요한 시트 항목들
    required = ['name', 'phone', 'class', 'birth', 'is_active']

    try:
        # 1. 공통 함수로 데이터 가져오기 및 항목 검사
        df = get_sheet_data(sheet_url, required)

        # 2. 회원 전용 데이터 가공 (1900-01-01 전략 등)
        df['birth'] = df['birth'].fillna('1900-01-01').astype(str)
        df['is_active'] = df['is_active'].fillna(1).astype(int)
        df['class'] = df['class'].fillna('취미반')
        
        # dict 리스트로 변환
        member_list = df.to_dict('records')

        # 3. DB 저장 함수 호출
        success, count = db.upload_members_from_list(member_list, admin_id)

        if success:
            return {"status": "success", "message": f"{count}명의 회원이 성공적으로 등록되었습니다."}
        else:
            raise HTTPException(status_code=500, detail="DB 등록 중 오류가 발생했습니다.")

    except Exception as e:
        print(f"❌ 회원 마이그레이션 에러: {e}")
        # 공통 함수나 가공 단계에서 발생한 에러 메시지를 프론트엔드로 전달
        raise HTTPException(status_code=400, detail=str(e))
    
@app.post("/api/upload_schedule_list")
async def upload_schedule_list(req: MigrationRequest):
    # 1. 일정에 필요한 필수 컬럼 정의
    required = ['제목', '장소', '담당자', '시작일', '종료일', '내용', '알람여부']
    
    try:
        # 2. 공통 함수 호출
        df = get_sheet_data(req.url, required)
        
        # 3. 일정 전용 가공 (랜덤 컬러, admin 고정 등)
        color_options = [
            0xFFE53935, # 빨강
            0xFFFB8C00, # 주황
            0xFFFFEB3B, # 노랑
            0xFF43A047, # 초록
            0xFF1E88E5, # 파랑
            0xFF8E24AA, # 보라
            0xFF784E4E  # 찍은 색 (ARGB: 255, 120, 78, 78)
        ]
        
        success_count = 0
        for _, row in df.iterrows():

            selected_color = random.choice(color_options)

            schedule_data = {
                "userid": "admin",
                "title": row['제목'],
                "location": row['장소'],
                "manager": row['담당자'],
                "start_date": row['시작일'],
                "end_date": row['종료일'],
                "content": row['내용'],
                "color": selected_color,
                "use_alarm": int(row.get('알람여부', 0))
            }
            db.upload_schedule_data_list(schedule_data)
            success_count += 1
            
        return {"status": "success", "success": success_count}
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    
@app.post("/api/upload_todo_list")
async def upload_todo_list(req: MigrationRequest):
    # 1. 일정에 필요한 필수 컬럼 정의
    required = ['제목', '기한', '담당자', '내용', '파일url', '완료여부']
    
    try:
        # 2. 공통 함수 호출
        df = get_sheet_data(req.url, required)

        df['기한'] = df['기한'].fillna('').astype(str)
              
        success_count = 0
        for _, row in df.iterrows():
            todo_data = {                
                "title": row['제목'],
                "due_date": row['기한'],
                "assignee": row['담당자'],                
                "content": row['내용'],
                "attachment_url": row['파일url'],
                "is_completed": int(row.get('완료여부', 0))
            }
            db.upload_todo_list(todo_data)
            success_count += 1
            
        return {"status": "success", "success": success_count}
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    
# 초대된 이메일 리스트 업로드
@app.post("/api/upload_invited_email")
async def upload_invited_email(req: MigrationRequest):
    # 1. 일정에 필요한 필수 컬럼 정의
    required = ['email', '사용여부']
    
    try:
        # 2. 공통 함수 호출
        df = get_sheet_data(req.url, required)
              
        success_count = 0
        for _, row in df.iterrows():
            email_data = {                
                "email": row['email'],                
                "is_used": int(row.get('사용여부', 0))
            }
            db.upload_invited_email(email_data)
            success_count += 1
            
        return {"status": "success", "success": success_count}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# 결제 정보 일괄 업로드
@app.post("/api/upload_payments_list")
async def upload_payments_list(req: MigrationRequest):
    # 1. 필수 컬럼 정의
    required = ['이름', '생년월일', '대상월', '금액', '구분', '결제방법', '결제여부']
    
    try:
        df = get_sheet_data(req.url, required)
        
        success_count = 0
        fail_count = 0
        fail_list = []

        def clean_val(val):
            # Pandas의 NaN이거나 None이면 None(DB의 NULL) 반환
            if pd.isna(val) or val is None:
                return None
            # 값이 있으면 문자열로 바꾸고 공백 제거
            return str(val).strip()

        for _, row in df.iterrows():
            # 날짜 및 숫자 데이터 안전하게 가공
            payment_data = {
                "name": str(row['이름']).strip(),
                "birth_date": str(row['생년월일']).strip(), # 회원 매칭용
                "target_month": clean_val(row['대상월']),
                "amount": int(row['금액']) if row['금액'] else 0,
                "pay_item": clean_val(row['구분']),
                "pay_method": clean_val(row['결제방법']),     # TODO: 숫자로 저장 할 것인지 글자 그대로 저장할 것인지에 따라 바꿀 것
                "is_paid": 1 if str(row['결제여부']) in ['1', '완납', 'TRUE', 'true'] else 0,
                "created_by": "admin"
            }
            
            # DB 저장 및 결과 확인 (매칭 실패 시 False 반환하도록 설계)
            is_success = db.upload_payments_data(payment_data)
            
            if is_success:
                success_count += 1
            else:
                fail_count += 1
                fail_list.append(f"{row['이름']}({row['생년월일']})")
            
        return {
            "status": "success", 
            "success": success_count, 
            "fail": fail_count,
            "fail_list": fail_list # 매칭 안 된 사람 확인용
        }
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# ---------------- Q&A 관련 API ----------------    

class QnaCreateRequest(BaseModel):
    title: str
    content: str
    author_id: str
    author_name: str
    fcm_token: Optional[str] = None

class QnaAnswerRequest(BaseModel):
    id: int
    answer: str

class QnaUpdateRequest(BaseModel):
    id: int
    title: str
    content: str

@app.post("/api/add_qna")
async def api_add_qna(req: QnaCreateRequest):    
    if db.add_qna(req):
        # 질문 등록 성공 후 관리자들에게 알림 전송
        try:
            push_data = {
                "target": FCM_ADMIN_TOPIC,     # 관리자용 토픽
                "title": f"'{req.author_name}' 님의 질문: {req.title}",
                "body": "❓ 새 질문이 등록되었습니다.",
                "type": "admin_qna_alert"                
            }

            asyncio.create_task(send_fcm_notification(push_data))

            print("🎯 관리자 알림 전송 완료 (Topic: admin_notifications)")
        except Exception as e:
            print(f"❌ 관리자 알림 전송 실패: {e}")

        return {"success": True}
    raise HTTPException(status_code=500, detail="등록 실패")

@app.post("/api/answer_qna")
async def api_answer_qna(req: QnaAnswerRequest):
    result = db.answer_qna(req)
    print(f"등록 결좌 조회 : {result}")
    if result:
        # result['fcm_token']으로 푸시 알림 발송 로직 추가 (Firebase 서비스 호출)
        # send_fcm_notification(result['fcm_token'], "문의 답변 완료", f"[{result['title']}] 글에 답변이 등록되었습니다.")
        fcm_token, qna_title = result
        print(f"토큰 값 조회 : {fcm_token}")
        print(f"타이틀 조회 : {qna_title}")
        # 2. 질문자의 토큰이 존재할 경우 알림 발송
        if fcm_token:
            try:
                push_data = {
                    "token": fcm_token,     
                    "title": "Q&A 답변 등록 완료",
                    "body": f"문의하신 '{qna_title}'에 대한 답변이 등록되었습니다.",
                    "type": "answer_qna_alert"                
                }

                asyncio.create_task(send_fcm_notification(push_data))
                
            except Exception as e:
                print(f"알림 발송 실패: {e}")
        return {"success": True}
    return {"success": False}

@app.post("/api/update_qna")
async def api_update_qna(req: QnaUpdateRequest):    
    if db.update_qna(req):
        return {"success": True}
    raise HTTPException(status_code=500, detail="수정 실패")


# Q&A 목록 조회 (최신순)
@app.get("/api/get_qna_list")
async def get_qna_list():
    with db.get_connection() as conn:
        c = conn.cursor()
        # 제목, 작성자, 답변여부, 날짜만 가볍게 가져옴
        c.execute("""
            SELECT id, title, content, author_id, author_name, answer, is_answered, created_at 
            FROM qna 
            ORDER BY created_at DESC
        """)
        return [dict(row) for row in c.fetchall()]

# Q&A 삭제 (답변 전 본인 또는 관리자)
@app.post("/api/delete_qna/{qna_id}")
async def delete_qna(qna_id: int):
    # DB 함수에서 권한 체크 후 삭제 로직 수행
    success = db.delete_qna(qna_id)
    if success:
        return {"success": True}
    raise HTTPException(status_code=400, detail="삭제할 수 없는 상태이거나 권한이 없습니다.")