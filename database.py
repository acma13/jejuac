import sqlite3
import auth  # 패스워드 암호화 및 검증용
import pandas as pd
import os
from config import DB_PATH #
# from dotenv import load_dotenv

# load_dotenv()

# # 1. 환경 변수 읽기
# env_db_path = os.getenv("DATABASE_PATH", "archery_club.db")

# # 2. 만약 경로가 파일명만 있다면(절대 경로가 아니라면)
# if not os.path.isabs(env_db_path):
#     # database.py가 있는 폴더 기준으로 절대 경로를 생성합니다.
#     base_dir = os.path.dirname(os.path.abspath(__file__))
#     DB_PATH = os.path.join(base_dir, env_db_path)
# else:
#     DB_PATH = env_db_path
# --> 위 코드들 config.py 로 이관

def get_connection():
    """DB 커넥션을 생성하고 기본 설정을 적용합니다."""
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = ON")  # 외래 키 활성화
    conn.row_factory = sqlite3.Row            # dict처럼 사용 가능하게 설정
    return conn

print(f"🚩 확정된 DB 경로: {DB_PATH}")

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

        # 4. 회원관리 테이블 생성
        c.execute("""
            CREATE TABLE IF NOT EXISTS members (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                phone TEXT,
                birth TEXT NOT NULL,
                class TEXT, 
                is_active INTEGER DEFAULT 1, 
                created_by TEXT, 
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(name, birth),
                FOREIGN KEY(created_by) REFERENCES users(userid) -- 누가 등록했는지 연결
            )
        """)

        # 5. TO-DO LIST 테이블 생성
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
        
        # 6. 공지사항 테이블 생성
        c.execute("""CREATE TABLE IF NOT EXISTS notices (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        title TEXT NOT NULL,
                        content TEXT NOT NULL,
                        author_name TEXT, 
                        is_important INTEGER DEFAULT 0,
                        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                    )""")
        
        # 7. 장비 마스터 테이블 생성
        c.execute("""
            CREATE TABLE IF NOT EXISTS equipments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,         -- 장비명
                spec TEXT,             -- 사양
                location TEXT,          --  보관위치
                note TEXT,              -- 비고
                stock INTEGER DEFAULT 0,    -- 현재 재고 수량
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)

        # c.execute("ALTER TABLE equipments ADD COLUMN spec TEXT")
        # c.execute("ALTER TABLE equipments ADD COLUMN location TEXT")
        # c.execute("ALTER TABLE equipments ADD COLUMN note TEXT")
        # c.execute("ALTER TABLE equipments DROP COLUMN image_url")

        # 8. 장비 입출고 내역 테이블 생성
        c.execute("""
            CREATE TABLE IF NOT EXISTS equipment_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                equipment_id INTEGER NOT NULL,  -- 어떤 장비인지 (equipments 테이블 연동)
                trade_type TEXT NOT NULL,       -- 거래 구분 ('IN': 입고, 'OUT': 출고)
                member_id INTEGER,     -- 누구에게 갔는지 (members 테이블 연동, 이름 대신 ID 저장!)
                quantity INTEGER NOT NULL,      -- 수량
                unit_price INTEGER NOT NULL DEFAULT 0,  -- 단가
                total_price INTEGER NOT NULL DEFAULT 0, -- 합계 금액
                note TEXT,                          -- 비고
                processed_by TEXT NOT NULL,     -- 처리자 (예: 권영)
                processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- 처리 일시
                -- 외래키(Foreign Key) 설정: 장비나 회원이 지워질 때의 규칙
                FOREIGN KEY (equipment_id) REFERENCES equipments (id) ON DELETE CASCADE,
                FOREIGN KEY (member_id) REFERENCES members (id)
            )
        """)

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
        c = conn.cursor()
        # invited_code 자리에 'NONE' 혹은 빈 값을 넣어서 기존 스키마 유지
        sql = "INSERT INTO invited_users (email, is_used) VALUES (?, 0)"
        c.execute(sql, (email.strip(),))
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
        c = conn.cursor()
        # 등록된 이메일과 사용 여부만 가져옴
        c.execute("SELECT email, is_used, created_at FROM invited_users ORDER BY id DESC")
        return c.fetchall()
    finally:
        conn.close()

# --- [3. TO-DO LIST 관련 함수] ---

def get_all_todos():
    with get_connection() as conn:
        try:
            c = conn.cursor()
            # 진행 중인 항목(상단), 완료된 항목(하단) 순으로 가져오기
            c.execute("SELECT * FROM todos order by due_date ASC")            
            rows = c.fetchall()

            # print(f"✅ DB에서 가져온 Row 개수: {len(rows)}")
            # if rows:
            #     print(f"✅ 첫 번째 Row 데이터: {dict(rows[0])}")
            # sqlite3.Row 객체들을 딕셔너리 리스트로 변환해서 반환합니다.
            return [dict(row) for row in rows]            
        except Exception as e:
            print(f"❌ 할일 조회 실패: {e}")
            return []
    

def add_todo(title, due_date, assignee, content, attachment_url, created_by):
    with get_connection() as conn:
        try:
            c = conn.cursor()
            c.execute("""INSERT INTO todos (title, due_date, assignee, content, attachment_url, created_by)
                        VALUES (?, ?, ?, ?, ?, ?)""", 
                    (title, due_date, assignee, content, attachment_url, created_by))
            conn.commit()
        except Exception as e:
            # 에러 발생 시 되돌리기
            conn.rollback()
            print(f"❌ 할일 저장 실패: {e}")
            return False 

# [1] 내용 전체 수정 (수정 폼용)
def update_todo_content(todo_id, title, due_date, assignee, content, attachment_url):
    with get_connection() as conn:
        try:
            c = conn.cursor()
            query = """
                UPDATE todos 
                SET title=?, due_date=?, assignee=?, content=?, attachment_url=?
                WHERE id=?
            """
            c.execute(query, (title, due_date, assignee, content, attachment_url, todo_id))
            conn.commit()
            return True
        except Exception as e:
            # 에러 발생 시 되돌리기
            conn.rollback()
            print(f"❌ 할일 내용수정 실패: {e}")
            return False 

# [2] 상태만 변경 (스와이프용)
def update_todo_status(todo_id, is_completed):
    with get_connection() as conn:
        try:
            c = conn.cursor()
            # is_completed는 bool로 받아서 1 또는 0으로 저장
            query = "UPDATE todos SET is_completed=? WHERE id=?"
            c.execute(query, (1 if is_completed else 0, todo_id))
            conn.commit()
            return True
        except Exception as e:
            # 에러 발생 시 되돌리기
            conn.rollback()
            print(f"❌ 할일 완료여부 수정 실패: {e}")
            return False

def delete_todo(todo_id):
    with get_connection() as conn:
        try:
            c = conn.cursor()
            c.execute("DELETE FROM todos WHERE id=?", (todo_id,))

            # print(f"✅ 삭제할 id 값: {todo_id}")

            conn.commit()
        except Exception as e:
            # 에러 발생 시 되돌리기
            conn.rollback()
            print(f"❌ 할일 삭제 실패: {e}")
            return False 

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

# --- 5. 회원관리 관련 함수 ----
# 회원등록
def insert_member(data):
    with get_connection() as conn:
        try:
            c = conn.cursor()
            
            query = """
                INSERT INTO members (name, phone, birth, class, is_active, created_by)
                VALUES (?, ?, ?, ?, ?, ?)
            """
            
            c.execute(query, (
                data.get('name'),
                data.get('phone'),
                data.get('birth'),
                data.get('member_class'),
                1 if data.get('is_active') else 0,
                data.get('created_by')                
            ))
            
            # 2. 변경사항 확정
            conn.commit()
            print(f"✅ 회원등록 성공: {data.get('name')}")
            return True, "success"
        except sqlite3.IntegrityError:
            # 중복 에러
            return False, "duplicate"
        except Exception as e:
            # 에러 발생 시 되돌리기
            conn.rollback()
            print(f"❌ 회원정보 저장 실패: {e}")
            return False, str(e)        

# 회원 리스트 조회
def get_all_members():
    with get_connection() as conn:
        try:
            c = conn.cursor()            
            c.execute("SELECT id, name, phone, birth, class, is_active FROM members")
            rows = c.fetchall()
            # sqlite3.Row 객체들을 딕셔너리 리스트로 변환해서 반환합니다.
            return [dict(row) for row in rows]
        except Exception as e:
            print(f"❌ 일정 조회 실패: {e}")
            return []
        
# 회원 정보 업데이트
def update_member(data):
    with get_connection() as conn:
        try:
            c = conn.cursor();
            
            query = """
                update members
                set
                    name = ?,
                    phone = ?,
                    birth = ?,
                    class = ?,
                    is_active = ?                
                where id = ?
            """

            c.execute(query, (                
                data.get('name'),
                data.get('phone'),
                data.get('birth'),
                data.get('member_class'),
                data.get('is_active'),                
                data.get('id')
            ))

            conn.commit()
            return True
    
        except Exception as e:
            conn.rollback()
            print(f"❌ 회원정보 업데이트 실패: {e}")
            return False
        
# 회원정보 삭제
def delete_member(memberId):
    with get_connection() as conn:
        try:
            c = conn.cursor();

            c.execute("DELETE FROM members WHERE id=?", (memberId,))
            conn.commit()
            return True
        except Exception as e:
            conn.rollback()
            print(f"❌ 회원 삭제 실패: {e}")
            return False
        
# ---------------- 공지사항 관련 DB CRUD ---------------

# 1. 공지사항 조회
def get_all_notices():
    with get_connection() as conn:
        try:
            conn.row_factory = sqlite3.Row            
            # 1. 중요 공지(is_important=1)를 가장 위로
            # 2. 그 다음 최신 등록순(id DESC 또는 created_at DESC)으로 정렬
            query = "SELECT * FROM notices ORDER BY is_important DESC, id DESC"
            cursor = conn.execute(query)
            notices = cursor.fetchall()
            
            # Row 객체들을 딕셔너리 리스트로 변환하여 반환
            return [dict(row) for row in notices]
        except Exception as e:
            print(f"❌ 공지사항 조회 실패: {e}")
            return []

# 2. 공지사항 추가
def add_notice(title, content, is_important, author_name):
    with get_connection() as conn:
        try:
            conn.execute('INSERT INTO notices (title, content, is_important, author_name) VALUES (?, ?, ?, ?)',
                        (title, content, 1 if is_important else 0, author_name))
            conn.commit()
            # conn.close()  # with 문은 블록이 끝나는 순간 알아서 정리하고 닫아줌. 하지마삼.
        except Exception as e:
            conn.rollback()
            print(f"❌ 공지사항 등록 실패: {e}")
            return False


# 3. 공지사항 수정
def update_notice(notice_id, title, content, is_important):
    with get_connection() as conn:
        try:
            conn.execute('UPDATE notices SET title = ?, content = ?, is_important = ? WHERE id = ?',
                        (title, content, 1 if is_important else 0, notice_id))
            conn.commit()
            
        except Exception as e:
            conn.rollback()
            print(f"❌ 공지사항 수정 실패: {e}")
            return False

# 4. 공지사항 삭제
def delete_notice(notice_id):
    with get_connection() as conn:
        try:
            conn.execute('DELETE FROM notices WHERE id = ?', (notice_id,))
            conn.commit()
            
        except Exception as e:
            conn.rollback()
            print(f"❌ 공지사항 삭제 실패: {e}")
            return False

# ---------------- 장비 관련 DB CRUD ---------------

# [장비] 목록 조회
def get_all_equipments():
    with get_connection() as conn:
        try:
            c = conn.cursor()
            # 진행 중인 항목(상단), 완료된 항목(하단) 순으로 가져오기
            c.execute("SELECT * FROM equipments")            
            rows = c.fetchall()

            # print(f"✅ DB에서 가져온 Row 개수: {len(rows)}")
            # if rows:
            #     print(f"✅ 첫 번째 Row 데이터: {dict(rows[0])}")
            # sqlite3.Row 객체들을 딕셔너리 리스트로 변환해서 반환합니다.
            return [dict(row) for row in rows]            
        except Exception as e:
            print(f"❌ 장비목록 조회 실패: {e}")
            return []

# [장비] 현 재고 조회
def get_equipment_stock(equipment_id):
    with get_connection() as conn:
        try:
            c = conn.cursor()
            c.execute("SELECT stock FROM equipments WHERE id = ?", (equipment_id,))
            row = c.fetchone()
            return row[0] if row else 0
        except Exception as e:
            print(f"❌ 장비 재고 조회 실패: {e}")
            return 0
        
# [입출고] 현 회원의 출고 수량 조회
def get_member_out_stock(equipment_id, member_id):
    with get_connection() as conn:
        try:
            # 해당 회원의 출고(+) 수량과 출고취소(-) 수량을 합산하여 현재 보유량 계산
            query = '''
                SELECT 
                    SUM(CASE WHEN trade_type = '출고' THEN quantity 
                             WHEN trade_type = '출고취소' THEN -quantity 
                             ELSE 0 END) as current_out_stock
                FROM equipment_history
                WHERE equipment_id = ? AND member_id = ?
            '''
            cursor = conn.execute(query, (equipment_id, member_id))
            row = cursor.fetchone()
            return row[0] if row[0] is not None else 0
        except Exception as e:
            print(f"❌ 회원별 점유 수량 조회 실패: {e}")
            return 0
        
# [입출고] 현 장비의 입출고 내역 존재 여부 확인
def check_equipment_history_exists(equipment_id):
    """장비의 입출고 내역이 존재하는지 확인"""
    with get_connection() as conn:
        c = conn.cursor()
        c.execute("SELECT COUNT(*) FROM equipment_history WHERE equipment_id = ?", (equipment_id,))
        count = c.fetchone()[0]
        return count > 0

# [장비] 등록
def add_equipment_db(name, spec, location, note, stock):
    with get_connection() as conn:
        try:
            c = conn.cursor()
            c.execute("""INSERT INTO equipments (name, spec, location, note, stock)
                        VALUES (?, ?, ?, ?, ?)""", 
                    (name, spec, location, note, stock))
            conn.commit()
        except Exception as e:
            # 에러 발생 시 되돌리기
            conn.rollback()
            print(f"❌ 장비 등록 실패: {e}")
            return False 

# [장비] 수정
def update_equipment_db(equipment_id, name, spec, location, note):
    with get_connection() as conn:        
        try:
            c = conn.cursor()
            query = """
                UPDATE equipments 
                SET name=?, spec=?, location=?, note=?
                WHERE id=?
            """
            c.execute(query, (name, spec, location, note, equipment_id))
            conn.commit()
            return True            
        except Exception as e:
            # 에러 발생 시 되돌리기
            conn.rollback()
            print(f"❌ 장비 수정 실패: {e}")
            return False 

# [장비] 삭제
def delete_equipment_db(equipment_id):
    """장비 삭제 (ON DELETE CASCADE 설정 덕분에 내역도 자동 삭제됨)"""
    with get_connection() as conn:
        c = conn.cursor()
        c.execute("DELETE FROM equipments WHERE id = ?", (equipment_id,))
        conn.commit()
        return True

# [입출고] 내역 조회 (장비별)
def get_trade_history(equipment_id):
    with get_connection() as conn:
        c = conn.cursor()
        # history와 members를 JOIN하여 회원 이름을 가져옵니다.
        # members 테이블에 데이터가 없는 경우를 대비해 LEFT JOIN 사용
        query = '''
            SELECT 
                h.id,
                h.trade_type,
                h.quantity,
                h.unit_price,
                h.total_price,
                h.processed_by,
                h.processed_at,
                h.note,
                h.member_id,
                m.name as member_name,
                m.birth as member_birth
            FROM equipment_history h
            LEFT JOIN members m ON h.member_id = m.id
            WHERE h.equipment_id = ?
            ORDER BY h.processed_at DESC
        '''
        c.execute(query, (equipment_id,))
        rows = c.fetchall()
        
        return [dict(row) for row in rows]

def add_trade_record(equipment_id, member_id, trade_type, quantity, unit_price, total_price, note, processed_by):
    """
    입출고 기록 저장 및 장비 재고 업데이트
    """
    with get_connection() as conn:
        try:
            c = conn.cursor()
            
            # 1. 입출고 내역(equipment_history)에 기록 추가
            # data 딕셔너리 키 값은 플러터에서 보낸 것과 맞춰야 합니다.
            history_query = """
                INSERT INTO equipment_history 
                (equipment_id, member_id, trade_type, quantity, unit_price, total_price, note, processed_by, processed_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, DATETIME('now', 'localtime'))
            """
            c.execute(history_query, (equipment_id, member_id, trade_type, quantity, unit_price, total_price, note, processed_by))                

            # 2. 장비 마스터(equipments) 테이블 재고 업데이트
            # 입고면 +, 출고면 - 계산
            op = "+" if trade_type == "입고" else "-"
            update_query = f"UPDATE equipments SET stock = stock {op} ? WHERE id = ?"
            c.execute(update_query, (quantity, equipment_id))

            conn.commit() # 모든 작업이 성공하면 확정!
            return True, "저장 완료"
            
        except Exception as e:
            conn.rollback() # 하나라도 실패하면 원래대로 되돌림
            print(f"❌ 입출고 등록 실패: {e}")
            return False, str(e)


# [기타] 활동 회원 목록 조회
def get_active_members_db():    
    with get_connection() as conn:
        try:
            c = conn.cursor()
            # 진행 중인 항목(상단), 완료된 항목(하단) 순으로 가져오기
            c.execute("SELECT id, name, birth FROM members where is_active = 1 ORDER BY name ASC")            
            rows = c.fetchall()
            
            # sqlite3.Row 객체들을 딕셔너리 리스트로 변환해서 반환합니다.
            return [dict(row) for row in rows]            
        except Exception as e:
            print(f"❌ 활동회원 목록 조회 실패: {e}")
            return []
        
# --------------- 데이터 마이그레이션 ---------------

def upload_members_from_list(member_list, admin_id):
    with get_connection() as conn:
        
        try:
            c = conn.cursor()

            query = """
                INSERT OR REPLACE INTO members (name, phone, birth, class, is_active, created_by, created_at)
                VALUES (?, ?, ?, ?, ?, ?, datetime('now', 'localtime'))
            """
            
            # executemany를 쓰면 대량 데이터 처리가 훨씬 빠릅니다.
            data_tuples = [
                (m['name'], m['phone'], m['birth'], m['class'], m['is_active'], admin_id)
                for m in member_list
            ]
            
            c.executemany(query, data_tuples)
            conn.commit()
            return True, c.rowcount  # 성공 여부와 삽입된 개수 반환
        except Exception as e:
            conn.rollback()
            print(f"Migration Error: {e}")
            return False, 0       
            