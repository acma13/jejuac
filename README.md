# 제주양궁클럽 관리 시스템

제주양궁클럽 운영을 위한 관리 앱입니다. Python FastAPI 백엔드와 Flutter 프론트엔드로 구성되어 있으며, 회원, 일정, 공지, 할 일, 장비, 결제, Q&A, 클럽 일지, 댓글, 데이터 마이그레이션, Firebase 푸시 알림 기능을 제공합니다.

## 전체 구조

- `app.py`: FastAPI 서버의 중심 파일입니다. API 라우트, CORS 설정, Firebase 푸시 발송, Flutter Web 정적 파일 서빙을 담당합니다.
- `database.py`: SQLite 테이블 생성과 CRUD 함수가 모여 있습니다. 사용자, 일정, 회원, 공지, Todo, 장비, 결제, Q&A, 일지, 댓글 데이터 처리를 담당합니다.
- `auth.py`: 로그인 검증과 비밀번호 해시 처리를 담당합니다.
- `config.py`: 환경 변수 로딩, DB 경로, Firebase Admin SDK 경로, Flutter Web 빌드 경로를 관리합니다.
- `scheduler.py`: APScheduler를 사용해 일정 알림을 정해진 시간에 발송합니다.
- `run.py`: Uvicorn으로 FastAPI 서버를 실행합니다.
- `requirements.txt`: Python 백엔드 의존성 목록입니다.
- `frontend/`: Flutter 앱입니다.
- `frontend/lib/main.dart`: Flutter 앱 진입점, 로그인 흐름, 대시보드, Firebase Messaging 초기화를 담당합니다.
- `frontend/lib/screens/`: 기능별 화면 파일들이 들어 있습니다.
- `frontend/lib/constants.dart`: 백엔드 API 주소 상수를 관리합니다.
- `frontend/lib/config/app_config.dart`: Firebase 클라이언트 설정과 메시징 관련 상수를 관리합니다.
- `frontend/web/firebase-messaging-sw.js`: 웹 푸시 알림용 서비스 워커입니다.

## 사용 기술 스택

- 백엔드: Python, FastAPI, Uvicorn, Pydantic
- 데이터베이스: SQLite
- 프론트엔드: Flutter, Dart, Material 3
- 알림: Firebase Cloud Messaging, Firebase Admin SDK
- 스케줄링: APScheduler
- 데이터 처리: pandas
- 주요 Flutter 패키지: `http`, `flutter_svg`, `table_calendar`, `syncfusion_flutter_calendar`, `firebase_core`, `firebase_messaging`, `shared_preferences`, `flutter_local_notifications`

## 주요 기능

- 로그인, 회원가입, 초대 이메일 기반 가입
- 사용자 프로필 및 권한 관리
- 클럽 일정 캘린더와 일정 알림
- 회원 관리
- 공지사항 등록 및 푸시 알림
- Todo 관리
- 장비 재고 및 입출고 내역 관리
- 결제 내역 관리
- 외부 데이터 마이그레이션
- Q&A 작성, 답변, 알림
- 클럽 일지, 월별 마커, 댓글
- Flutter Web/PWA 및 Firebase 웹 푸시 알림

## 이번 수정 내용

- 프론트엔드 API 기본 주소 문제를 수정했습니다.
  - `Config.baseUrl`을 `https://jejuac.duckdns.org`로 변경했습니다.
  - 각 API 상수는 계속 `/api/...`를 붙이도록 유지했습니다.
  - 따라서 `/api/api/...` 형태로 호출되는 문제가 사라집니다.
- `app.py`의 중복 루트 경로 선언을 정리했습니다.
  - `/` 경로는 Flutter Web의 `index.html`을 반환하는 역할만 유지합니다.
- 장비 수정 API 경로를 수정했습니다.
  - 기존 `/api/update_equipment/equipmentId}`를 `/api/update_equipment`로 변경했습니다.
  - Flutter의 `Config.updateEquipment` 호출 경로와 맞췄습니다.
- 장비 DB 처리 결과 반환을 보완했습니다.
  - 장비 등록 후 `True`를 반환하도록 수정했습니다.
  - 장비 수정은 실제로 수정된 행이 있는지 확인해 결과를 반환합니다.

## 개선이 필요한 부분

- `app.py`와 `database.py`가 너무 커져 있어 기능별 모듈로 분리하는 것이 좋습니다.
- API 응답 형태가 `status`, `success`, 문자열 success 등으로 섞여 있습니다. 공통 응답 규격을 정리하는 것이 좋습니다.
- 일부 주석과 로그 문자열의 인코딩이 깨져 보이는 부분이 있습니다. 파일 인코딩을 UTF-8로 통일하고 정리하는 것이 좋습니다.
- 로그인, 일정 등록, 장비 수정, 결제 수정 같은 핵심 흐름에 자동 테스트를 추가하는 것이 좋습니다.
- DB 스키마 변경이 `init_db()` 안에서 직접 처리되고 있습니다. Alembic 같은 마이그레이션 도구 도입을 검토할 수 있습니다.
- 개발/운영 환경별 프론트엔드 설정을 분리하면 배포 실수를 줄일 수 있습니다.

## CORS 설정 제안

현재 백엔드는 모든 출처를 허용합니다.

```python
allow_origins=["*"]
```

운영 환경에서는 실제로 API를 호출해야 하는 도메인만 허용하는 것이 좋습니다. 예시는 아래와 같습니다.

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://jejuac.duckdns.org",
        "http://localhost:5000",
        "http://localhost:3000",
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)
```

`localhost` 주소는 개발 중 필요할 때만 유지하면 됩니다. 나중에 쿠키, 인증 헤더, 관리자 기능이 더 강하게 붙을수록 `*` 대신 명시적 도메인 목록을 쓰는 편이 안전합니다.

## 의존성 문제

- `fastapi`와 `starlette`가 둘 다 직접 고정되어 있습니다. FastAPI는 Starlette와 버전 궁합이 중요하므로 수동 고정은 주의가 필요합니다.
- Python 패키지 버전이 매우 촘촘하게 고정되어 있습니다. 직접 의존성과 잠금 파일을 분리하는 방식을 검토할 수 있습니다.
- Flutter SDK가 `^3.11.4`로 설정되어 있어 최신 Flutter/Dart 환경이 필요합니다.
- Firebase, Syncfusion, `intl`, 알림 관련 패키지는 버전 충돌 가능성이 있으므로 의존성 변경 후 `flutter pub get`, `flutter analyze` 확인이 필요합니다.

## 실행 참고

백엔드 실행:

```powershell
python run.py
```

Flutter 프론트엔드 실행:

```powershell
cd frontend
flutter pub get
flutter run -d chrome
```

FastAPI에서 Flutter Web을 서빙하려면 먼저 Web 빌드가 필요합니다.

```powershell
cd frontend
flutter build web
```
