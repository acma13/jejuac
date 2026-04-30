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
from firebase_admin import credentials, messaging
from config import initialize_firebase, FCM_TOPIC_NAME, FRONTEND_PATH

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
async def send_notice_push(title, content, is_important):
    try:
        prefix = "📢 [중요] " if is_important else "🔔 [공지] "
        
        message = messaging.Message(
            # 1. notification 객체는 반드시 있어야 브라우저가 인식합니다.
            notification=messaging.Notification(
                title=f"{prefix}{title}",
                body="새로운 공지사항이 등록되었습니다.",
            ),
            # 2. 'data' 필드도 함께 보내야 Flutter의 onMessage가 더 잘 낚아챕니다.
            data={
                "title": f"{prefix}{title}",
                "body": "새로운 공지사항이 등록되었습니다.",
            },
            # 3. ⭐ 웹 전용 설정 (WebpushConfig) - 이게 없으면 웹에서 누락되는 경우가 많습니다.
            webpush=messaging.WebpushConfig(
                # fcm_options=messaging.WebpushFCMOptions(
                #     link="/" # 알림 클릭 시 이동할 경로
                # ),
                notification=messaging.WebpushNotification(
                    body="새로운 공지사항이 등록되었습니다.",
                    icon="/icons/bow-and-arrow.png",
                    tag="jejuac-notification"
                ),
            ),
            topic=FCM_TOPIC_NAME, # 서버 변수 FCM_TOPIC_NAME이 "club_all"인지 꼭 확인!
        )
        response = messaging.send(message)
        print(f"🚀 푸시 발송 완료: {response}")
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
        print("1")
        return {"success": False, "message": "사용자를 찾을 수 없습니다."}

    # [단계 2] 현재 비밀번호가 맞는지 검증 (auth.py의 check_hashes 활용)
    # user['password']는 DB에 저장된 해시값입니다.
    if not auth.check_hashes(req.current_password, user['password']):
        print("2")
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
        print("3")
        return {"success": False, "message": "DB 업데이트 중 오류가 발생했습니다."}
    
# 등록된 클럽 일정 조회
@app.get("/api/get_schedules")
async def get_schedules():
    schedules = db.get_all_schedules()
    return schedules  # FastAPI가 자동으로 JSON 리스트로 변환해줍니다.

# 클럽 일정 및 수정에 대한 전용 규격(모델)
class scheduleRequest(BaseModel):
    id: Optional[str] = None
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
        result = db.insert_club_schedule(req.model_dump())
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
        result = db.update_schedule(req.model_dump())

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

class deleteMember(BaseModel):
    id: int

@app.post("/api/insert_member")
async def insert_member(req: addMember):
    success, message = db.insert_member(req.model_dump())
    
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

# 클럽 일정 수정
@app.post("/api/update_member")
async def update_member(req: modifyMember):
    try:
               
        # 2. 필수 값인 'id'가 있는지 확인 (제주양궁클럽의 안전장치!)
        if not req.id:
            return {"success": False, "message": "수정할 회원 ID가 없습니다."}

        # 3. DB 업데이트 함수 호출
        result = db.update_member(req.model_dump())

        if result:
            return {"success": True, "message": "회원정보가 성공적으로 수정되었습니다."}
        else:
            return {"success": False, "message": "DB 업데이트 중 오류가 발생했습니다."}

    except Exception as e:
        print(f"❌ 수정 API 에러: {e}")
        return {"success": False, "message": str(e)}
 
@app.post("/api/delete_member")
async def delete_member(req: deleteMember):
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
        db.add_notice(req.title, req.content, req.is_important, req.author_name)
        print("[Add_notice] 1. DB 저장 성공 (세션 생존 확인)")
        # 저장 성공 후 푸시 알림 발송
        try:
            print("[Add_notice] 2. 푸시 발송 시도...")
            await send_notice_push(req.title, req.content, req.is_important)
            print("[Add_notice] 3. 푸시 발송 로직 통과")
        except Exception as push_e:
            print(f"[Add_notice] 4. 푸시만 실패(DB는 성공): {push_e}")

        return {"status": "success", "message": "공지가 등록되었습니다."}
    except Exception as e:
        print(f"[Add_notice] 에러: {e}")
        return {"status": "error", "message": str(e)}

@app.post("/api/update_notice")
async def update_notice(req: UpdateNoticeRequest):
    try:
        db.update_notice(req.id, req.title, req.content, req.is_important)
        return {"status": "success", "message": "공지가 수정되었습니다."}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.post("/api/delete_notice")
async def delete_notice(req: DeleteNoticeRequest):
    try:
        db.delete_notice(req.id)
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
        result = db.add_todo(
            req.title, req.due_date, req.assignee, 
            req.content, req.attachment_url, req.created_by
        )

        # TODO: 등록 시 알람 쏘는거 만들어야 함.
        #       공지 쏘던거랑 같이 쓰면 될 것 같은데 이 부분은 수정이 필요해보임.
        if result:
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
        result = db.update_todo_content(
            req.id, req.title, req.due_date, req.assignee, req.content, req.attachment_url
        )
        return {"success": result}
    except Exception as e:
        print(f"Update Content Error: {e}")
        return {"success": False, "message": str(e)}

# [2] 상태 변경 API (스와이프 전용)
@app.post("/api/update_todo_status")
async def update_status(req: TodoStatusUpdateRequest): 
    try:
        result = db.update_todo_status(req.id, req.is_completed)
        return {"success": result}
    except Exception as e:
        print(f"Update Status Error: {e}")
        return {"success": False, "message": str(e)}

# 할 일 삭제
@app.post("/api/delete_todo")
async def delete_todo_api(req: TodoDeleteRequest):
    try: 
        # print(f"API 의 할 일 삭제 ID: {req.id}")

        result = db.delete_todo(req.id)

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
        result = db.add_equipment_db(req.name, req.spec, req.location, req.note, req.stock)
        
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
        result = db.update_equipment_db(req.id, req.name, req.spec, req.location, req.note)
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
    success, msg = db.add_trade_record(req.equipment_id, req.member_id, req.trade_type, req.quantity, req.unit_price, req.total_price, req.note, req.processed_by)
    
    if success:
        return {"success": True, "message": msg}
    else:
        # 실패 시 400 에러나 500 에러를 줄 수도 있지만, 
        # 우선 success: False로 처리해서 플러터에서 메시지를 띄우게 합니다.
        return {"success": False, "message": msg}


# ---------------- 데이터 마이그레이션 관련 API ----------------

class MigrationRequest(BaseModel):
    url: str
    admin_id: str
    data_type: str

@app.post("/api/upload_members_list")
async def upload_members_list(req: MigrationRequest):
    sheet_url = req.url
    admin_id = req.admin_id

    if not sheet_url:
        raise HTTPException(status_code=400, detail="URL이 없습니다.")

    try:
        # 1. 구글 시트 URL을 CSV 다운로드 링크로 변환
        csv_url = sheet_url.replace('/edit?usp=sharing', '/export?format=csv')
        if '/edit#gid=' in csv_url:
            csv_url = csv_url.replace('/edit#gid=', '/export?format=csv&gid=')
        elif '/edit' in csv_url and '/export' not in csv_url:
             csv_url = csv_url.replace('/edit', '/export?format=csv')

        # 2. Pandas로 데이터 읽기
        # 주의: FastAPI 환경이므로 별도의 requests 없이 pandas가 직접 URL을 읽을 수 있습니다.
        df = pd.read_csv(csv_url)

        required_columns = {
            '회원': ['name', 'phone', 'class', 'birth', 'is_active'],
            '결제': ['member_id', 'amount', 'payment_date'], # TODO: 추후에 변경 할 것
            '장비': ['equipment_name', 'serial_number']     # TODO: 추후에 변경 할 것
        }
        current_cols = df.columns.tolist()
        missing_cols = [col for col in required_columns[req.data_type] if col not in current_cols]

        if missing_cols:
            raise HTTPException(
                status_code=400, 
                detail=f"잘못된 시트 양식입니다. 빠진 항목: {', '.join(missing_cols)}"
            )
        
        # 3. 데이터 가공 (선배님의 1900-01-01 전략 적용)
        # 시트 컬럼명: name, phone, class, birth, is_active
        df['birth'] = df['birth'].fillna('1900-01-01').astype(str)
        df['is_active'] = df['is_active'].fillna(1).astype(int)
        
        # 'member_class'로 DB 컬럼명이 되어있다면 시트의 'class'를 매칭해줍니다.
        # 시트 열 이름이 'class'라면 아래처럼 처리
        df['class'] = df['class'].fillna('일반')
        
        # NaN 값들을 dict 리스트로 변환
        member_list = df.to_dict('records')

        # 4. database.py의 함수 호출 (db 객체 사용)
        # database.py에 작성하신 함수명이 upload_members_from_list 인지 확인하세요!
        success, count = db.upload_members_from_list(member_list, admin_id)

        if success:
            return {"status": "success", "message": f"{count}명의 회원이 성공적으로 등록되었습니다."}
        else:
            raise HTTPException(status_code=500, detail="DB 등록 중 오류가 발생했습니다.")

    except Exception as e:
        print(f"❌ 마이그레이션 에러: {e}")
        raise HTTPException(status_code=500, detail=f"시트 읽기 실패: {str(e)}")