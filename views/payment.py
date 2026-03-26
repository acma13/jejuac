# views/payment.py
import streamlit as st
import database as db

def show():
    st.header("결제관리")
    # DB 조회 로직 및 UI 구성
    st.info("현재 등록된 공지가 없습니다.")