# views/modiftyuser.py 개인정보 수정 페이지
import streamlit as st
import database as db
import hashlib

def show():
    st.title("👤 개인정보 수정")
    user_id = st.session_state.get('user_id') 
    user_data = db.get_user_by_id(user_id)

    if not user_data:
        st.error("사용자 정보를 찾을 수 없습니다.")
        return

    with st.form("modify_user_form"):
        # 1. 이름은 언제든 수정 가능
        new_name = st.text_input("성명", value=user_data['name'])
        st.text_input("아이디", value=user_data['userid'], disabled=True)
        st.text_input("이메일", value=user_data['email'], disabled=True)
        
        st.divider()
        st.subheader("🔒 비밀번호 변경 (변경 시에만 입력)")
        curr_pw = st.text_input("현재 비밀번호 확인", type="password", help="정보 수정을 위해 현재 비밀번호를 입력해주세요.")
        
        col1, col2 = st.columns(2)
        with col1:
            new_pw = st.text_input("새 비밀번호", type="password", help="바꾸지 않으려면 비워두세요.")
        with col2:
            conf_pw = st.text_input("새 비밀번호 확인", type="password")

        if st.form_submit_button("변경 내용 저장", use_container_width=True):
            # [검증 1] 현재 비밀번호는 본인 확인을 위해 무조건 입력받음
            if not curr_pw:
                st.warning("본인 확인을 위해 현재 비밀번호를 입력해야 합니다.")
                return
                
            hashed_curr = hashlib.sha256(curr_pw.encode()).hexdigest()
            if hashed_curr != user_data['password']:
                st.error("현재 비밀번호가 일치하지 않습니다.")
                return

            # [검증 2] 새 비밀번호 처리 로직 (자바의 if (newPw != null && !newPw.isEmpty()))
            final_pw = user_data['password'] # 기본값은 기존 비번
            
            if new_pw: # 새 비번 칸에 입력이 있다면
                if new_pw != conf_pw:
                    st.error("새 비밀번호 확인이 일치하지 않습니다.")
                    return
                # 새로운 비밀번호로 교체
                final_pw = hashlib.sha256(new_pw.encode()).hexdigest()
                pw_changed_msg = " 및 비밀번호가"
            else:
                pw_changed_msg = "이"

            # [DB 업데이트]
            if db.update_user_profile(user_id, new_name, final_pw):
                st.success(f"회원 정보{pw_changed_msg} 성공적으로 변경되었습니다.")
                st.session_state['user_name'] = new_name # 사이드바 즉시 반영
                st.rerun()