# views/todolist.py
import streamlit as st
import database as db

def show():
    st.header("todolist")
    # DB 조회 로직 및 UI 구성
    st.info("현재 등록된 공지가 없습니다.")