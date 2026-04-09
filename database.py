import sqlite3
import auth  # 패스워드 암호화 및 검증용
import pandas as pd
import os
from dotenv import load_dotenv

load_dotenv()

DB_PATH = os.getenv("DATABASE_PATH")

def get_connection():
    """DB 커넥션을 생성하고 기본 설정을 적용합니다."""
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = ON")  # 외래 키 활성화
    conn.row_factory = sqlite3.Row            # dict처럼 사용 가능하게 설정
    return conn

def init_db():
    """데이터베이스 테이블 초기화 및 관리자 계정 생성"""
    with get_connection() as conn:
        c = conn.cursor()

        # 1. 초대된 명단 (화이트리스트)
        c.execute("""CREATE TABLE IF NOT EXISTS invited_users (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        email TEXT UNIQUE,
                        is_used INTEGER DEFAULT 0, -- 0:미사용, 1:사용됨
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )""")
        
        # 2. 실제 가입된 사용자
        c.execute("""CREATE TABLE IF NOT EXISTS users (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        userid TEXT UNIQUE, 
                        password TEXT, 
                        name TEXT, 
                        email TEXT, 
                        role TEXT,
                        phone TEXT,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )""")
        
        # 3. 클럽일정 테이블 생성
        c.execute("""
            CREATE TABLE IF NOT EXISTS schedules (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                userid TEXT,
                title TEXT NOT NULL,
                location TEXT,
                manager TEXT,
                start_date TEXT NOT NULL,  
                end_date TEXT NOT NULL,    
                content TEXT,
                color TEXT DEFAULT '#166534',
                use_alarm INTEGER DEFAULT 0, -- 0: 안함, 1: 함
                FOREIGN KEY(userid) REFERENCES users(userid)
            )
        """)

        # 4. TO-DO LIST 테이블 생성
        c.execute("""CREATE TABLE IF NOT EXISTS todos (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        title TEXT NOT NULL,
                        due_date DATE,
                        assignee TEXT,
                        content TEXT,
                        attachment_url TEXT, -- 웹하드 링크 등
                        is_completed INTEGER DEFAULT 0, -- 0:진행중, 1:완료
                        created_by TEXT, -- 등록자 아이디
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )""")
        
        

        # [Admin] 최초 관리자 계정 생성 (없을 때만)
        c.execute("SELECT * FROM users WHERE role = 'Admin'")
        if not c.fetchone():
            initial_pw = auth.make_hashes('admin')
            c.execute("""INSERT INTO users (userid, password, name, email, role, phone) 
                         VALUES (?, ?, ?, ?, ?, ?)""", 
                      ('admin', initial_pw, '권영', 'acma13@gmail.com', 'Admin', '010-0000-0000'))
            conn.commit()
            print("최초 관리자 계정(admin)이 생성되었습니다.")

# --- [1. 가입 권한(초대) 관련 함수] ---

def add_invited_email(email):
    """가입을 허용할 이메일을 화이트리스트에 등록합니다."""
    with get_connection() as conn:
        try:
            c = conn.cursor()
            c.execute("INSERT INTO invited_users (email) VALUES (?)", (email.strip(),))
            conn.commit()
            return True
        except sqlite3.IntegrityError:
            return False # 이미 등록된 이메일

def get_all_invited_emails():
    """모든 초대 명단을 가져옵니다 (Pandas DF용)"""
    with get_connection() as conn:
        return pd.read_sql("SELECT email, is_used, created_at FROM invited_users ORDER BY id DESC", conn)

def check_invitation(email):
    """회원가입 전, 허용된 이메일인지 확인합니다."""
    with get_connection() as conn:
        c = conn.cursor()
        c.execute("SELECT id FROM invited_users WHERE email = ? AND is_used = 0", (email.strip(),))
        return c.fetchone()

# --- [2. 사용자(회원) 관련 함수] ---

def get_user_by_id(userid):
    """로그인 및 정보 조회용 (dict 반환)"""
    with get_connection() as conn:
        c = conn.cursor()
        c.execute("SELECT * FROM users WHERE userid = ?", (userid,))
        row = c.fetchone()
        return dict(row) if row else None

def register_new_user(userid, password, name, email, phone):
    """회원가입 처리 및 초대장 사용 완료 처리 (트랜잭션)"""
    with get_connection() as conn:
        try:
            c = conn.cursor()
            # 1. 사용자 추가
            hashed_pw = auth.make_hashes(password)
            c.execute("""INSERT INTO users (userid, password, name, email, role, phone) 
                         VALUES (?, ?, ?, ?, 'user', ?)""", 
                      (userid.strip(), hashed_pw, name.strip(), email.strip(), phone.strip()))
            
            # 2. 화이트리스트 사용 완료 처리
            c.execute("UPDATE invited_users SET is_used = 1 WHERE email = ?", (email.strip(),))
            conn.commit()
            return True
        except Exception as e:
            conn.rollback()
            return False

def update_user_profile(userid, name, phone, password=None):
    """개인정보 수정 (비밀번호 변경 여부 선택)"""
    with get_connection() as conn:
        try:
            c = conn.cursor()
            if password:
                hashed_pw = auth.make_hashes(password)
                sql = "UPDATE users SET name = ?, phone = ?, password = ? WHERE userid = ?"
                c.execute(sql, (name, phone, hashed_pw, userid))
            else:
                sql = "UPDATE users SET name = ?, phone = ? WHERE userid = ?"
                c.execute(sql, (name, phone, userid))
            conn.commit()
            return True
        except:
            return False
        
def register_user_with_invitation(userid, password, name, email, phone):
    """
    초대장 확인부터 유저 등록, 초대장 상태 변경까지 트랜잭션으로 처리합니다.
    """
    with get_connection() as conn:
        try:
            c = conn.cursor()
            
            # Step 1: 초대 명단 확인 (is_used=0 인 것만)
            c.execute("SELECT id FROM invited_users WHERE email = ? AND is_used = 0", (email.strip(),))
            invitation = c.fetchone()
            
            if not invitation:
                return False, "초대된 이메일이 아니거나 이미 가입이 완료된 이메일입니다."

            # Step 2: 실제 유저 등록
            hashed_pw = auth.make_hashes(password)
            c.execute("""INSERT INTO users (userid, password, name, email, role, phone) 
                         VALUES (?, ?, ?, ?, 'user', ?)""", 
                      (userid.strip(), hashed_pw, name.strip(), email.strip(), phone.strip()))
            
            # Step 3: 초대장 사용 완료 처리 (is_used=1)
            c.execute("UPDATE invited_users SET is_used = 1 WHERE id = ?", (invitation[0],))
            
            conn.commit() # 모든 과정 성공 시 커밋
            return True, "가입 성공"
            
        except sqlite3.IntegrityError:
            conn.rollback()
            return False, "이미 존재하는 아이디입니다."
        except Exception as e:
            conn.rollback()
            return False, f"데이터베이스 오류: {str(e)}"        
        
def add_invitation_email(email):
    """ 초대할 신규 유저 이메일 등록 """
    conn = get_connection()
    try:
        cursor = conn.cursor()
        # invited_code 자리에 'NONE' 혹은 빈 값을 넣어서 기존 스키마 유지
        sql = "INSERT INTO invited_users (email, is_used) VALUES (?, 0)"
        cursor.execute(sql, (email.strip(),))
        conn.commit()
        return True
    except Exception as e:
        print(f"이메일 등록 오류: {e}")
        return False
    finally:
        conn.close()

def get_invited_emails():
    """ 초대된 사용자 리스트 조회"""
    conn = get_connection()
    try:
        cursor = conn.cursor()
        # 등록된 이메일과 사용 여부만 가져옴
        cursor.execute("SELECT email, is_used, created_at FROM invited_users ORDER BY id DESC")
        return cursor.fetchall()
    finally:
        conn.close()

# --- [3. TO-DO LIST 관련 함수] ---

def get_all_todos():
    with get_connection() as conn:
        # 진행 중인 항목(상단), 완료된 항목(하단) 순으로 가져오기
        query = "SELECT * FROM todos ORDER BY is_completed ASC, due_date ASC"
        return pd.read_sql(query, conn)

def add_todo(title, due_date, assignee, content, attachment_url, created_by):
    with get_connection() as conn:
        c = conn.cursor()
        c.execute("""INSERT INTO todos (title, due_date, assignee, content, attachment_url, created_by)
                     VALUES (?, ?, ?, ?, ?, ?)""", 
                  (title, due_date, assignee, content, attachment_url, created_by))
        conn.commit()

def update_todo(todo_id, title, due_date, assignee, content, attachment_url, is_completed):
    with get_connection() as conn:
        c = conn.cursor()
        c.execute("""UPDATE todos SET title=?, due_date=?, assignee=?, content=?, 
                     attachment_url=?, is_completed=? WHERE id=?""",
                  (title, due_date, assignee, content, attachment_url, is_completed, todo_id))
        conn.commit()

def delete_todo(todo_id):
    with get_connection() as conn:
        c = conn.cursor()
        c.execute("DELETE FROM todos WHERE id=?", (todo_id,))
        conn.commit()

# --- [4. 클럽 일정 관련 함수] ---
def insert_club_schedule(data):
    with get_connection() as conn:
        try:
            c = conn.cursor()
            
            query = """
                INSERT INTO schedules 
                (userid, title, location, manager, start_date, end_date, content, color, use_alarm)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            
            c.execute(query, (
                data.get('userid'),
                data.get('title'),
                data.get('location'),
                data.get('manager'),
                data.get('start_date'),
                data.get('end_date'),
                data.get('content'),
                data.get('color'),
                data.get('use_alarm')
            ))
            
            # 2. 변경사항 확정
            conn.commit()
            print(f"✅ 일정 저장 성공: {data.get('title')}")
            return True
            
        except Exception as e:
            # 에러 발생 시 되돌리기
            conn.rollback()
            print(f"❌ 일정 저장 실패: {e}")
            return False        
        
def get_all_schedules():
    with get_connection() as conn:
        try:
            c = conn.cursor()
            # 모든 일정을 시작일 순으로 가져옵니다.
            c.execute("SELECT * FROM schedules ORDER BY start_date ASC")
            rows = c.fetchall()
            # sqlite3.Row 객체들을 딕셔너리 리스트로 변환해서 반환합니다.
            return [dict(row) for row in rows]
        except Exception as e:
            print(f"❌ 일정 조회 실패: {e}")
            return []

# 클럽일정 수정        
def update_schedule(data):
    with get_connection() as conn:
        try:
            c = conn.cursor();
            
            query = """
                update schedules
                set
                    title = ?,
                    location = ?,
                    manager = ?,
                    start_date = ?,
                    end_date = ?,
                    content = ?,
                    color = ?,
                    use_alarm = ?                
                where id = ?
            """

            c.execute(query, (                
                data.get('title'),
                data.get('location'),
                data.get('manager'),
                data.get('start_date'),
                data.get('end_date'),
                data.get('content'),
                data.get('color'),
                data.get('use_alarm'),
                data.get('id')
            ))

            conn.commit()
            return True
    
        except Exception as e:
            conn.rollback()
            print(f"❌ 일정 업데이트 실패: {e}")
            return False

# 클럽일정 삭제
def delete_schedule(eventId):
    with get_connection() as conn:
        try:
            c = conn.cursor();

            c.execute("DELETE FROM schedules WHERE id=?", (eventId,))
            conn.commit()
            return True
        except Exception as e:
            conn.rollback()
            print(f"❌ 일정 삭제 실패: {e}")
            return False

            