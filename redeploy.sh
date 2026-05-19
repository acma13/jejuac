#!/bin/bash

# 색상 지정 (터미널 가독성용)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

WEB_PATH="$HOME/jejuac/frontend/build/web"

echo -e "${BLUE}============ 🐧 JEJUAC 우분투 서버 배포 스크립트 ============${NC}"
echo "1) Frontend 배포 (web.zip 외 삭제 후 압축 해제)"
echo "2) Backend 배포 (Git Pull + PM2 Reload)"
echo "3) [종합] 전 과정 연속 배포 (Git Pull -> PM2 -> Web 압축해제)"
echo "4) 종료"
echo -e "${BLUE}==============================================================${NC}"
echo -n "👉 실행할 작업 번호를 선택하세요 (1~4): "
read choice

# ----------------------------------------------------
# 기능 1: 프론트엔드 빌드 파일 교체
# ----------------------------------------------------
deploy_frontend() {
    echo -e "\n${BLUE}🌐 프론트엔드 배포를 시작합니다...${NC}"
    
    if [ -d "$WEB_PATH" ]; then
        cd "$WEB_PATH"
        
        # 1. web.zip 파일이 진짜 올라와 있는지 확인
        if [ ! -f "web.zip" ]; then
            echo -e "${RED}❌ 에러: $WEB_PATH 경로에 web.zip 파일이 없습니다!${NC}"
            echo "먼저 FTP로 web.zip 파일을 올린 후 실행해주세요."
            cd ~
            return
        fi

        echo "🧹 web.zip을 제외한 기존 구버전 파일들을 깔끔하게 삭제합니다..."
        # web.zip만 남기고 나머지 파일/폴더 싹 제거
        find . -maxdepth 1 ! -name 'web.zip' ! -name '.' -exec rm -rf {} +

        echo "📦 최신 web.zip 압축을 해제합니다..."
        unzip web.zip > /dev/null
        
        echo "🧹 작업이 끝난 web.zip 파일을 서버에서 삭제합니다..."
        rm -f web.zip

        cd ~
        echo -e "${GREEN}========== 🎉 프론트엔드 웹 배포 완료! ==========${NC}"
    else
        echo -e "${RED}❌ 에러: 배포 경로($WEB_PATH)가 존재하지 않습니다.${NC}"
    fi
}

# ----------------------------------------------------
# 기능 2: 백엔드 Git Pull 및 PM2 재시작
# ----------------------------------------------------
deploy_backend() {
    echo -e "\n${BLUE}🐍 백엔드 배포를 시작합니다 (Git Pull & PM2)...${NC}"
    
    cd ~/jejuac
    echo "📥 GitHub에서 최신 코드를 당겨옵니다..."
    git pull origin main

    # 🎯 [자동 패키지 설치 기능 추가]
    if [ -f "requirements.txt" ]; then
        echo "📦 requirements.txt를 확인하여 누락된 패키지를 자동 설치합니다..."
        pip install -r requirements.txt --break-system-packages
    fi

    echo "🔄 PM2를 통해 jejuac 백엔드 서버를 재가동합니다..."
    pm2 reload jejuac

    cd ~
    echo -e "${GREEN}========== 🎉 백엔드 배포 및 서버 재시작 완료! ==========${NC}"
}

# ----------------------------------------------------
# 조건문 실행
# ----------------------------------------------------
case $choice in
    1)
        deploy_frontend
        ;;
    2)
        deploy_backend
        ;;
    3)
        # 종합 모드는 안전하게 백엔드(Git)부터 땡기고 프론트엔드를 교체합니다.
        deploy_backend
        deploy_frontend
        ;;
    4)
        echo -e "${BLUE}Goodbye!${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}❌ 잘못된 번호입니다.${NC}"
        exit 1
        ;;
esac