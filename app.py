# app.py (API 서버로 전면 개조)
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from contextlib import asynccontextmanager
from typing import Optional
import database as db
import auth
import re

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

# 2. CORS 설정 (플러터 웹에서 접속 허용)
# 다른 도메인(플러터 웹)에서 이 파이썬 서버에 접근할 수 있게 해줍니다.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 모든 곳에서 접속 허용 (개발용)
    allow_credentials=True,
    allow_methods=["*"],  # 모든 HTTP 메서드 허용 (GET, POST 등)
    allow_headers=["*"],
)

# 5. [API 엔드포인트 1] 로그인 처리

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

class deleteScheduleRequest(BaseModel):
    id: str

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