# auth.py
import hashlib
import re

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError

import database as db

password_hasher = PasswordHasher()


# 비밀번호를 Argon2 해시값으로 변환
def make_hashes(password):
    return password_hasher.hash(password)


def make_legacy_hash(password):
    return hashlib.sha256(str.encode(password)).hexdigest()


def is_legacy_sha256_hash(hashed_text):
    return bool(hashed_text and re.fullmatch(r"[0-9a-f]{64}", hashed_text))


def verify_password(password, hashed_text):
    """
    기존 SHA-256 해시와 신규 Argon2 해시를 모두 검증합니다.
    SHA-256 검증에 성공하면 새 Argon2 해시를 함께 반환해 점진적으로 전환합니다.
    """
    if not hashed_text:
        return False, None

    if is_legacy_sha256_hash(hashed_text):
        if make_legacy_hash(password) == hashed_text:
            return True, make_hashes(password)
        return False, None

    try:
        is_valid = password_hasher.verify(hashed_text, password)
        if is_valid and password_hasher.check_needs_rehash(hashed_text):
            return True, make_hashes(password)
        return is_valid, None
    except (InvalidHashError, VerificationError, VerifyMismatchError):
        return False, None

# 로그인 시 입력한 비번과 DB 비번 비교
def check_hashes(password, hashed_text):
    is_valid, _ = verify_password(password, hashed_text)
    return is_valid

def login_user(userid, password):
    """
    database.py의 함수를 사용하여 사용자를 조회하고 
    비밀번호 일치 여부를 확인합니다.
    """
    # 1. DB 전용 함수 호출 (이미 dict 형태로 결과를 줍니다)
    user = db.get_user_by_id(userid)

    if not user:
        return None

    # 2. 유저가 존재하고 비밀번호가 일치하는지 확인
    is_valid, upgraded_hash = verify_password(password, user['password'])
    if is_valid:
        if upgraded_hash:
            db.update_password_hash(userid, upgraded_hash)

        # 필요한 정보만 반환 (app.py 세션 저장용)
        return {
            "userid": user['userid'],
            "name": user['name'],
            "role": user['role']
        }
    
    return None
