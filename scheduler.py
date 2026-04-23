import sqlite3
import time
import firebase_admin
import os
from datetime import datetime, timedelta
from apscheduler.schedulers.background import BackgroundScheduler
from firebase_admin import credentials, messaging
from config import DB_PATH, initialize_firebase, FCM_TOPIC_NAME, DATABASE_NAME


# 1. 파이어베이스 초기화
initialize_firebase()

# 2. 공통 알람 발송 함수
def send_fcm_notification(title, body):
    try:        
        message = messaging.Message(
            data={'title': title, 'body': body},
            webpush=messaging.WebpushConfig(
                notification=messaging.WebpushNotification(
                    title=title,
                    body=body,
                    icon="/icons/bow-and-arrow.png",
                    tag="jejuac-event-alarm" # 공지 알림과 구분되는 태그
                ),
            ),
            topic=FCM_TOPIC_NAME
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
    with sqlite3.connect(DATABASE_NAME) as conn:    
        cursor = conn.cursor()        
        # 쿼리: 해당 날짜에 알람 설정(use_alarm=1)이 된 일정 조회
        query = "SELECT title FROM schedules WHERE start_date = ? AND use_alarm = 1"
        cursor.execute(query, (target_date,))
        schedules = cursor.fetchall()        

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

