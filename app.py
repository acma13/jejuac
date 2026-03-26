# app.py
import streamlit as st
import database as db
import auth
import base64
import pandas as pd  # 나중에 CSV 처리를 위해 미리 임포트
import re
from pathlib import Path

# [함수] SVG 파일을 브라우저가 인식할 수 있는 데이터 주소로 변환
def get_svg_data_url(svg_path):
    try:
        with open(svg_path, "rb") as f:
            svg_bytes = f.read()
            # Base64 인코딩 (자바의 Base64.getEncoder().encodeToString()과 동일)
            b64 = base64.b64encode(svg_bytes).decode("utf-8")
            return f"data:image/svg+xml;base64,{b64}"
    except:
        return "🎯" # 에러 나면 기본 이모지로 대체

# [설정] 여기서 page_icon에 함수 결과값을 넣습니다.
icon_data_url = get_svg_data_url("bow-and-arrow.svg")

# --- [1. 선언부: 페이지 설정 및 SVG 함수] ---
st.set_page_config(
    page_title="제주양궁클럽",
    page_icon=icon_data_url, # 경로를 문자열로 변환해서 전달
    layout="centered" # 모바일 가독성을 위해 centered 권장
)

# 회원 가입 검증 유틸리티 함수
def check_id_format(userid):
    if not userid : return None
    pattern = r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{4,15}$'
    return bool(re.match(pattern, userid))

def check_pw_format(pw):
    if not pw : return None
    return len(pw) >= 6 and any(c.isdigit() for c in pw) and any(c.isalpha() for c in pw)

db.init_db()

# 세션 초기화
if 'logged_in' not in st.session_state:
    st.session_state['logged_in'] = False
    st.session_state['user_role'] = None
    st.session_state['user_name'] = ""

# --- 메인 로직 ---
if not st.session_state['logged_in']:
    tab1, tab2 = st.tabs(["로그인", "회원가입(초대 전용)"])
    
    with tab1:
        # 로그인 UI 
        userid = st.text_input("아이디")
        password = st.text_input("비밀번호", type="password")

        if st.button("로그인"):
            # auth.py 에서 함수 호출
            user_info = auth.login_user(userid,password)

            if user_info:
                # 세션에 정보 저장
                st.session_state['logged_in'] = True
                st.session_state['user_role'] = user_info['role']
                st.session_state['user_name'] = user_info['name']
                st.session_state['user_id'] = user_info['userid']

                #st.success(f"{user_info['name']}님, 환영합니다!")
                st.rerun() # 세션 반영을 위해 즉시 새로고침
            else:
                # login_user가 None을 반환했다면 아이디가 없거나 비번이 틀린 것
                st.error("아이디 또는 비밀번호가 일치하지 않습니다.")            

    with tab2:
        st.subheader("제주양궁클럽 신규 가입")
        with st.form("register_form"):
            reg_email = st.text_input("초대받은 이메일", placeholder="example@naver.com")
            st.divider()

            reg_name = st.text_input("이름", placeholder="성함을 입력하세요")
            reg_userid = st.text_input("사용할 아이디", placeholder="영문/숫자조합")
            reg_phone = st.text_input("연락처", placeholder="번호만 넣어주세요") 
            reg_pw = st.text_input("비밀번호", type="password", placeholder="영문/숫자 포함 6자 이상")
            reg_pw_confirm = st.text_input("비밀번호 확인", type="password")
            
            submit = st.form_submit_button("가입 신청하기")
            
            if submit:
                # --- [Step 1: 형식 검증 (UI Validation)] ---
                id_status = check_id_format(reg_userid)
                pw_status = check_pw_format(reg_pw)
                
                if not (reg_email and reg_name and reg_userid and reg_pw):
                    st.error("⚠️ 모든 항목을 입력해주세요.")
                elif not id_status:
                    st.error("⚠️ 아이디 형식이 올바르지 않습니다. (영문/숫자 조합 4~15자)")
                elif not pw_status:
                    st.error("⚠️ 비밀번호 형식이 올바르지 않습니다. (영문/숫자 포함 6자 이상)")
                elif reg_pw != reg_pw_confirm:
                    st.error("❌ 비밀번호 확인이 일치하지 않습니다.")
                else:
                    # --- [Step 2: 가입 실행 (Service 호출)] ---
                    success, message = db.register_user_with_invitation(
                        reg_userid, reg_pw, reg_name, reg_email, reg_phone
                    )
                    
                    if success:
                        st.success(f"🎯 {message}! 이제 로그인 탭에서 접속하세요.")
                        #st.balloons()
                    else:
                        st.error(f"⚠️ {message}")

# --- [3. 메인 로직: 로그인 성공 상태 (메인 앱)] ---
else:
    import main
    main.display_main()
