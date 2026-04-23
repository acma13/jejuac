# config.py
import os
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials

# 1. 환경 변수 로드
load_dotenv()

# --- [공통 상수] ---
FCM_TOPIC_NAME = "club_all"
DATABASE_NAME = "archery_club.db"

# --- [공통 경로 설정] ---
# config.py 파일이 있는 폴더를 기준으로 모든 경로를 잡습니다.
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# 2. DB 경로 설정
env_db_path = os.getenv("DATABASE_PATH", DATABASE_NAME)
if not os.path.isabs(env_db_path):
    DB_PATH = os.path.join(BASE_DIR, env_db_path)
else:
    DB_PATH = env_db_path

# 3. Firebase SDK 경로 설정
SDK_PATH = os.path.join(BASE_DIR, "firebase_admin_sdk.json")

# 4. flutter 경로 설정.
# 빌드된 파일들이 있는 실제 '절대 경로'를 계산합니다.
# 현재 app.py가 있는 위치에서 frontend/build/web 폴더를 가리킵니다.
FRONTEND_PATH = os.path.join(BASE_DIR, "frontend", "build", "web")

# --- [Firebase 초기화 함수] ---
def initialize_firebase():
    if not firebase_admin._apps:
        try:
            if not os.path.exists(SDK_PATH):
                print(f"❌ Firebase 키 파일을 찾을 수 없습니다: {SDK_PATH}")
                return
            
            cred = credentials.Certificate(SDK_PATH)
            firebase_admin.initialize_app(cred)
            print("✅ Firebase Admin SDK 초기화 성공")
        except Exception as e:
            print(f"❌ Firebase 초기화 실패: {e}")