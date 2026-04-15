import uvicorn
import os
import sys

# 현재 폴더를 파이썬 경로에 추가 (import 에러 방지)
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

if __name__ == "__main__":
    print("🏹 제주양궁클럽 서버를 시작합니다...")
    uvicorn.run("app:app", host="0.0.0.0", port=5000, reload=False)