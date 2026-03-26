# auth.py
import hashlib
import database as db

# 비밀번호를 해시값으로 변환 (자바의 MessageDigest 역할)
def make_hashes(password):
    return hashlib.sha256(str.encode(password)).hexdigest()

# 로그인 시 입력한 비번과 DB 비번 비교
def check_hashes(password, hashed_text):
    if make_hashes(password) == hashed_text:
        return True
    return False

def login_user(userid, password):
    """
    database.py의 함수를 사용하여 사용자를 조회하고 
    비밀번호 일치 여부를 확인합니다.
    """
    # 1. DB 전용 함수 호출 (이미 dict 형태로 결과를 줍니다)
    user = db.get_user_by_id(userid)

    # 2. 유저가 존재하고 비밀번호가 일치하는지 확인
    if user and check_hashes(password, user['password']):
        # 필요한 정보만 반환 (app.py 세션 저장용)
        return {
            "userid": user['userid'],
            "name": user['name'],
            "role": user['role']
        }
    
    return None