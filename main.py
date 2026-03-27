import streamlit as st
# import database as db
# import pandas as pd
# import secrets
# import string
import base64
from views import announcement, equipment, members, parents, payment, schedule, todolist, adduser, modifyuser

def display_main():
      
    user_name = st.session_state.get('user_name', '사용자')
    user_role = st.session_state.get('user_role', 'None')

    # [1] 로고는 st.logo를 써야만 메뉴 "위"에 붙습니다. (크기는 SVG 자체를 조절해야 함)
    with open("bow-and-arrow.svg", "rb") as f:
        svg_encoded = base64.b64encode(f.read()).decode()
    st.logo(f"data:image/svg+xml;base64,{svg_encoded}")

    # [2] 메뉴를 딕셔너리 구조로 묶어서 '사용자 이름'을 섹션 타이틀로 씁니다.
    # 추후 상단으로 메뉴를 바꾸던지 대시보드 처럼 여러 메뉴 버튼이 아이콘처럼 나오는 방식으로 가던지 해야함.
    nav_dict = {
        f"{user_name}님 ({user_role})": [
            st.Page(announcement.show, title="공지사항", icon="📣", url_path="announcement"),
            st.Page(schedule.show, title="클럽 일정", icon="📅", url_path="schedule"),
            st.Page(todolist.show, title="To-do List", icon="✅", url_path="todo"),
        ],
        "관리 및 설정": [
            st.Page(members.show, title="회원 관리", icon="👥", url_path="members"),
            st.Page(payment.show, title="결제 관리", icon="💳", url_path="payment"),
            st.Page(equipment.show, title="장비 관리", icon="🧰", url_path="equipment"),
            st.Page(modifyuser.show, title="개인정보 수정", icon="👤", url_path="modify_user"),
        ]
    }

    if user_role == 'Admin':
        nav_dict["관리 및 설정"].append(st.Page(adduser.show, title="사용자 초대 관리", icon="💌", url_path="add_user"))

    pg = st.navigation(nav_dict)
    #pg = st.navigation(nav_dict, position="top")

    # [3] 로그아웃은 메뉴 아래에 잘 붙습니다.
    with st.sidebar:
        
        if st.button("로그아웃", use_container_width=True):
            # 1. 모든 세션 상태 초기화 
            st.session_state.clear()
            st.session_state['logged_in'] = False
            # 2. [추가] 브라우저의 쿼리 파라미터(URL 뒤에 붙는 정보)를 강제 초기화
            # st.navigation이 URL 기반으로 동작하기 때문에 이걸 비워줘야 잔상이 사라집니다.
            st.query_params.clear()

            # 3. 브라우저 강제 새로고침
            st.markdown('<meta http-equiv="refresh" content="0; url=/">', unsafe_allow_html=True)
            st.stop()
    
    pg.run()