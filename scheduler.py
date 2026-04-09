import sqlite3
import time
import firebase_admin
import os
from dotenv import load_dotenv
from datetime import datetime, timedelta
from apscheduler.schedulers.background import BackgroundScheduler
from firebase_admin import credentials, messaging

load_dotenv() #.env 파일 읽어오기
# 1. 파이어베이스 초기화
cred = credentials.Certificate(os.getenv("FIREBASE_JSON")) # 파일명 확인!
firebase_admin.initialize_app(cred)

# 2. 공통 알람 발송 함수
def send_fcm_notification(title, body):
    token = os.getenv("FIREBASE_TOKEN")

    try:        
        message = messaging.Message(
            # notification=messaging.Notification(title=title, body=body),
            # #topic="club_all", # 모든 가입자가 구독할 토픽 이름
            # token=token, 
            data={'title': title, 'body': body,},
            token=token,
        )
        response = messaging.send(message)
        print(f"Successfully sent message: {response}")
    except Exception as e:
        print(f"Error sending message: {e}")
        

# 3. DB 조회 및 알람 로직 (SQLite 사용)
def check_and_send_alarms(target_date, alarm_type):
    """
    target_date: 'YYYY-MM-DD' 형식의 날짜
    alarm_type: '오늘' 또는 '내일' (메시지 문구용)
    """
    conn = sqlite3.connect("database.db") # 영님의 DB 파일명으로 수정
    cursor = conn.cursor()
    
    # 쿼리: 해당 날짜에 알람 설정(use_alarm=1)이 된 일정 조회
    query = "SELECT title FROM schedules WHERE start_date = ? AND use_alarm = 1"
    cursor.execute(query, (target_date,))
    schedules = cursor.fetchall()
    conn.close()

    if schedules:
        # 일정이 여러 개일 경우 하나로 묶어서 발송
        titles = ", ".join([s[0] for s in schedules])
        msg_title = f"[제주양궁클럽] {alarm_type} 일정 알림"
        msg_body = f"{alarm_type}은 '{titles}' 일정이 있습니다. 잊지 마세요! 🏹"
        
        send_fcm_notification(msg_title, msg_body)

# 4. 스케줄러 작업 정의
def morning_job():
    today = datetime.now().strftime('%Y-%m-%d')
    check_and_send_alarms(today, "오늘")

def evening_job():
    tomorrow = (datetime.now() + timedelta(days=1)).strftime('%Y-%m-%d')
    check_and_send_alarms(tomorrow, "내일")

# 테스트용
# send_fcm_notification("[제주양궁클럽] 테스트", "지금 알람 가나요?")

# 5. 스케줄러 시작
scheduler = BackgroundScheduler()
# 아침 8시: 당일 알람
scheduler.add_job(morning_job, 'cron', hour=8, minute=0)
# 저녁 8시: 전날 리마인드
scheduler.add_job(evening_job, 'cron', hour=20, minute=0)

scheduler.start()

print("알람 스케줄러가 가동되었습니다! 🚀")

try:
    while True:
        time.sleep(1)
except (KeyboardInterrupt, SystemExit):
    scheduler.shutdown()
    print("알람 스케줄러가 종료되었습니다! 🚀")

