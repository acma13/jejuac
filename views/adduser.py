import streamlit as st
import database as db
import pandas as pd

def show():
    st.title("💌 신규 사용자 초대")
    st.write("가입을 허용할 사용자의 이메일을 사전에 등록합니다.")
    st.info("이메일이 등록된 사용자만 회원가입이 가능합니다.")
    st.divider()

    # --- [섹션 1: 가입 허용 이메일 추가] ---
    st.subheader("신규 이메일 등록")
    
    with st.form("email_invite_form", clear_on_submit=True):
        col1, col2 = st.columns([3, 1])
        with col1:
            target_email = st.text_input("허용할 이메일 주소", placeholder="example@naver.com")
        with col2:
            st.write(" ") # 레이아웃 맞춤용
            submit_btn = st.form_submit_button("등록하기", use_container_width=True)

        if submit_btn:
            if target_email:
                if db.add_invitation_email(target_email):
                    st.success(f"✅ {target_email} 등록 완료!")
                    #st.balloons() # 가벼운 축하 효과
                else:
                    st.error("이미 등록된 이메일이거나 오류가 발생했습니다.")
            else:
                st.warning("이메일 주소를 입력해주세요.")

    st.divider()

    # --- [섹션 2: 등록 현황 목록] ---
    st.subheader("가입 허용 명단")
    email_list = db.get_invited_emails()

    if email_list:
        df = pd.DataFrame(email_list, columns=['이메일', '가입 상태', '등록일'])
        
        # 가입 상태 가독성 처리
        df['가입 상태'] = df['가입 상태'].map({0: '⏳ 미가입', 1: '✅ 가입완료'})
        
        # 표 형식으로 출력
        st.dataframe(df, use_container_width=True, hide_index=True)
        
        # [Tip] 나중에 명단이 많아지면 삭제 기능도 필요하실 텐데, 
        # 우선은 조회 기능에 집중했습니다.
    else:
        st.info("등록된 이메일이 없습니다.")