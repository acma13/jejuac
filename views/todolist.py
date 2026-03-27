# views/todolist.py
import streamlit as st
import database as db
from datetime import datetime

def show():
    st.title("✅ To-do List")
    
    # 1. 할 일 추가 버튼 (Dialog 활용)
    if st.button("➕ 새 할 일 등록", use_container_width=True):
        add_modal()

    st.divider()

    # 2. 리스트 출력
    todos_df = db.get_all_todos()
    
    if not todos_df.empty:
        # 진행 중인 목록
        st.subheader("📌 진행 중")
        pending = todos_df[todos_df['is_completed'] == 0]
        for _, row in pending.iterrows():
            with st.expander(f"⭕ {row['title']} (마감: {row['due_date']})"):
                display_todo_detail(row)

        st.divider()

        # 완료된 목록
        st.subheader("✅ 완료됨")
        completed = todos_df[todos_df['is_completed'] == 1]
        for _, row in completed.iterrows():
            with st.expander(f"✔️ {row['title']}"):
                display_todo_detail(row)
    else:
        st.info("등록된 할 일이 없습니다.")

@st.dialog("할 일 등록")
def add_modal():
    title = st.text_input("제목")
    due_date = st.date_input("마감일", value=datetime.now())
    assignee = st.text_input("담당자")
    content = st.text_area("상세내용")
    attach_url = st.text_input("첨부파일 링크 (웹하드 등)")
    
    if st.button("저장하기"):
        db.add_todo(title, due_date, assignee, content, attach_url, st.session_state['userid'])
        st.rerun()

def display_todo_detail(row):
    # 상세 내용 수정 폼
    with st.form(key=f"edit_form_{row['id']}"):
        u_title = st.text_input("제목", value=row['title'])
        u_date = st.date_input("마감일", value=datetime.strptime(row['due_date'], '%Y-%m-%d'))
        u_assignee = st.text_input("담당자", value=row['assignee'])
        u_content = st.text_area("상세내용", value=row['content'])
        u_attach = st.text_input("첨부파일 링크", value=row['attachment_url'])
        u_completed = st.checkbox("완료 여부", value=bool(row['is_completed']))
        
        col1, col2 = st.columns(2)
        if col1.form_submit_button("수정 완료"):
            db.update_todo(row['id'], u_title, u_date, u_assignee, u_content, u_attach, int(u_completed))
            st.rerun()
        if col2.form_submit_button("삭제", type="primary"):
            db.delete_todo(row['id'])
            st.rerun()