# AutotradingMac (macOS Monitoring Console)

운영 콘솔 앱입니다.  
기본적으로는 read-only 모니터링이며, Strategy 페이지에서 핵심 파라미터만 부분 수정할 수 있습니다.
백엔드(`autotrading-core`)의 REST snapshot + WebSocket delta를 수신해 상태를 표시합니다.

## 현재 범위
- Sidebar 기반 화면
  - Dashboard
  - Scanner
  - Chart
  - Stategy
  - Logs
  - Settings
  - Dev
- Dev 하위 화면
  - Signals / Risk
  - Orders / Fills
  - Positions / PnL
  - Runtime / Workers
- 앱 시작 시 `GET /api/monitoring/snapshot` 1회 로드
- 이후 `ws://.../ws/events` delta 스트림 반영
- 페이지별 SwiftUI `#Preview` 지원
  - Dashboard / Scanner / Chart / Stategy / Logs / Settings / Dev
  - Dev 하위(`Signals / Risk`, `Orders / Fills`, `Positions / PnL`, `Runtime / Workers`) 및 `GlobalTopBarView` 포함
- snapshot/runtime 디코딩은 서버 계약(`order_mode/account_mode`, `engine_*`, `account_summary`)을 기준으로 nullable 필드를 optional 처리
- snapshot 최초 로드 실패 시 5초 주기로 자동 재시도하며, WS 연결 직후에도 snapshot 미로드 상태면 즉시 재시도
- 백엔드 base URL은 `http://host:port`와 `http://host:port/api`를 모두 허용하며 API 경로를 자동 정규화
  - 주소 저장 우선순위는 `AppConfig` 기준 `앱에 저장된 마지막 주소(UserDefaults) -> AUTOTRADING_BACKEND_BASE_URL` 이다.
  - `AUTOTRADING_BACKEND_WS_URL`가 없으면 WebSocket URL은 Base URL에서 `/ws/events`로 자동 계산한다.
- 임시 진단 로그(2026-03-20):
  - 앱 시작/REST 요청/WS 연결 단계별 URL·status·응답 body prefix 로그를 콘솔에 출력
- 코드 연결 맵 문서: `CODE_CONNECT_MAP.md`
- 스타일 토큰 매핑 파일: `AutotradingMac/Core/DesignTokens.swift`
  - 출처: `design_ref/figma_web_export/src/styles/theme.css` (.dark 토큰)
  - 적용 범위: 전역 다크 테마(`preferredColorScheme(.dark)`), accent/tint, panel/surface 공통 스타일, 상태 배지/상태톤 색상, 주요 화면 텍스트/배경 토큰 적용
  - 타이포 기준: macOS 시스템 폰트(SF Pro 계열) + `DesignTokens.Typography` 크기 비율(`title/section/body/caption`) 사용
  - 2026-03-20 시각 폴리시: `DesignTokens.Layout`(page/section/panel/row spacing) + 저대비 surface 톤 재정의
  - 공통 스타일: `AppTheme.appPanelStyle/appSurfaceStyle/appToolbarChrome`로 패널/툴바 소재감을 통일
- 역할 분리
  - 운영 메인: Dashboard/Scanner/Chart/Stategy/Logs/Settings
  - 개발/디버깅: Dev 하위 화면
- 상단 정보 계층 분리
  - Global top bar(운영): 자동매매 상태, 장 상태, 마지막 갱신, `시작/일시정지/긴급 정지`(서버 엔진 제어 연동)
  - 표시 순서: `자동매매 상태 -> 장 상태 -> 새로고침 시각 -> 주문/계좌 모드`
  - 자동매매 상태 텍스트는 간단 상태값(`실행 중`, `일시정지`, `정지`) 중심으로 표기
  - 장 상태는 라벨 없이 값만 표시하며, 1차 규칙은 `장 마감까지 n시간 n분` 또는 `장 종료`
  - 자동매매 상태 컬러: `running=초록`, `paused=노랑`, `emergency_stopped=빨강`
  - `engine started`, `engine paused` 성공 토스트성 문구는 top bar에 노출하지 않음
  - 모드 전환/제어 실패 사유(`409 detail`)는 Dev 화면에서 확인
  - Dev 오류는 `주문 모드 전환 실패`와 `계좌정보 조회 실패`로 분리 표시
  - `emergency_stopped` 상태에서는 `해제` 버튼이 추가 노출되고, 해제 전 `시작`은 비활성 유지
  - toolbar 스타일: 절제된 대비의 단일 크롬 레이어 + pill 리듬 + 저채도 액션 버튼 스타일로 정리
  - 페이지 제목은 top bar에서 노출하지 않고, 사이드바 선택 상태로 현재 페이지를 파악
  - 본문에서도 페이지 제목 헤더를 반복 노출하지 않고, 화면별 콘텐츠 영역에 집중
  - Dev tools(개발): 연결 상태, `Reload Snapshot`, `Reconnect WS`
- Logs 페이지(운영형 2-pane)
  - 좌측: 결과 중심 로그 피드(`시간 + 아이콘 + 한 줄 핵심 메시지`)
  - 대표 이벤트 선택 규칙:
    - `position.closed`가 있으면 같은 흐름의 주문/체결을 기본 목록에서 숨기고 청산 결과를 대표로 노출
    - 청산이 없고 fill이 있으면 fill을 대표로 노출(주문은 숨김)
    - fill도 없으면 주문 이벤트를 유지
  - 좌측 각 행에 mode 배지(`PAPER`/`LIVE`/`UNKNOWN`) 표시
  - 상단 mode 필터(`전체`/`PAPER`/`LIVE`/`UNKNOWN`) 지원
  - 공통 이벤트 스타일 시스템 적용:
    - 매수 계열: 빨강 아이콘
    - 매도 계열: 파랑 아이콘
    - 관망: 회색 아이콘
    - 보류/차단: 경고색 아이콘
    - 청산: 공통 청산 아이콘 + 손익/사유 기반 색상
  - 손익 숫자 색상 규칙:
    - 이익(+): 빨강
    - 손실(-): 파랑
    - 보합(0): 회색
  - 핵심 메시지: 운영자 친화적 한국어 템플릿(예: `삼성전자 150주 매수 체결 @ 71,200원`, `NAVER 매수 신호 생성 (점수: 94)`)
  - 우측: 선택 이벤트 상세(event type/timestamp/symbol/code/source + payload/meta)
  - 우측 상세는 내부 단계 추적을 유지:
    - `source_order_id`, `source_signal_reference`
    - 연계 주문 상태/수량/가격
    - 연계 체결 수량/가격/시각
  - 즉, 목록은 “최종 결과”, 상세는 “내부 실행 단계” 역할로 분리
  - 우측 상세에 `execution_mode`를 명시해 mode 혼선을 줄임
  - 로그 미선택 시 우측 empty state 표시
  - 리스트 행은 저대비 선택 강조 + 얇은 보더 중심으로 정리해 과한 웹 카드 느낌을 축소
- Settings 페이지(운영형 2x2 패널)
  - `API 연결`, `알림 설정`, `데이터 관리`, `정보` 패널로 구성
  - `API 연결` 패널에 마스킹 계좌 식별자 표시(`runtime.account_summary.masked_account` 우선)
  - `API 연결` 패널에서 현재 Backend Base URL을 편집/적용할 수 있다.
  - `WebSocket URL`은 현재 Base URL 기준의 실제 접속값을 표시한다.
  - 연결 상태는 공통 모델로 해석한다.
    - `정상 연결`
    - `서버 연결 확인 중`
    - `서버 연결 실패`
    - `실시간 연결 끊김`
    - `재연결 중`
    - `인증 확인 필요`
    - `서버 초기화 확인 필요`
  - 비정상 상태는 전역 top bar pill + 상단 inline banner + `API 연결` 패널 상세 문구로 노출한다.
  - `design_ref/figma_web_export/src/app/pages/SettingsPage.tsx` 정보구조를 SwiftUI로 반영
  - 데이터 소스:
    - `GET /api/monitoring/runtime`: 연결/계좌/모드/환경 상태
    - `GET /api/monitoring/app-settings`: 알림/데이터관리 현재값
    - `PATCH /api/monitoring/app-settings`: 토글/보관기간 즉시 저장
  - 알림 토글은 macOS 알림 권한과 함께 동작한다.
    - 권한이 없으면 토글 ON 시 권한을 요청하고, 거부 상태면 저장을 롤백한다.
    - 체결/신호/시스템 오류 알림은 각 토글이 켜져 있을 때만 local notification을 보낸다.
  - 데이터 관리 패널은 `자동 백업`, `로그 보관 기간`, `실사용 저장공간`을 실제 서버 응답 기준으로 표시한다.
  - backup directory는 Settings에서 편집하지 않고 서버 config `APP_BACKUP_DIRECTORY`를 따른다.
  - Settings 진입 시 `app-settings`를 다시 조회해 저장공간/maintenance 상태를 갱신한다.
  - 데이터 관리 패널은 아래 운영 메타를 함께 표시한다.
    - `백업 보관 개수`
    - `최근 로그 정리`
    - `최근 자동 백업`
  - 저장 직후에는 지연 재조회로 background maintenance 결과를 다시 반영한다.
  - 서버 정책 의미:
    - `로그 보관 기간`은 현재 `engine_events`, `risk_events`, `strategy_signals` cleanup에 적용된다.
    - `자동 백업`은 SQLite 파일 복사 또는 PostgreSQL `pg_dump` 실행 on/off에 직접 연결된다.
    - backup rotation은 새 backup 생성 후 최신 N개만 유지하는 방식으로 동작한다(기본 7개).
    - rotation 실패 시 최신 backup은 유지되고 상태는 warning 성격으로 표시된다.
  - WebSocket 끊김 시 앱이 자동 재연결을 시도하고, 반복 실패 시 `재연결 중`/`실시간 연결 끊김` 상태를 유지해 사용자가 인지할 수 있게 한다.
- Stategy 페이지(사이드바 독립 화면)
  - 사이드바 메뉴명/페이지 제목은 `Stategy`
  - 현재 구조는 `선택 가능한 전략 템플릿 + 전략별 파라미터 + 공통 리스크/실행 설정`
  - 레이아웃:
    - 상단: 현재 활성 전략 요약
    - 본문 1: 전략 선택 카드 영역
    - 본문 2: 선택한 전략의 설정 영역
    - 본문 3: 공통 리스크 / 실행 설정 영역
    - 하단: `Advanced Settings`(현재 활성 전략의 Scanner/Signal 상세 튜닝, 기본 접힘)
    - 하단 고정 action bar: 변경 상태 + 반영 정책 + `취소/기본값 복원/저장`
  - 데이터 소스: `GET /api/monitoring/strategy-settings`
  - 저장 API: `PATCH /api/monitoring/strategy-settings`
  - 응답 메타(`defaults`, `apply_status`, `apply_policy`, `updated_at`)를 함께 사용
  - 편집 흐름: `server snapshot`과 `local draft` 분리, `취소`/`기본값 복원`/`저장` 제공
  - 저장 전 로컬 검증 + 서버 검증(`422 detail`) 메시지 표시
  - 멀티 전략 템플릿 모델:
    - `active_strategy_id`
    - `strategy_templates`
    - `strategy_params`
    - `common_risk_params`
  - 현재 템플릿:
    - `turnover_surge_momentum`: 실제 엔진 연결 전략, 선택 가능
    - `intraday_breakout`: `preview_only`, 메타/파라미터 프리뷰만 가능
  - 정보 구조/정렬 원칙:
    - 카드 전체 폭 양 끝에 라벨/값을 두는 긴 폼 구조를 줄이고, 내부 읽기 폭을 좁힌 그룹형 패널로 정리
    - `현재 전략 요약`은 `전략 핵심 요약` + `적용 상태` 2블록으로 나눠 핵심 기준과 현재 상태를 분리 표시
    - `전략 선택`은 segmented control 대신 카드형 목록으로 유지해 향후 전략 추가에 대비한다
    - 활성 전략 편집 패널과 공통 리스크/실행 패널은 시각적으로 분리한다
    - 현재 `turnover_surge_momentum`만 전략별 편집 UI를 제공하고, preview 템플릿은 값 미리보기만 제공한다
    - 공통 설정은 전략을 바꿔도 유지되며, 전략 전환과 별도의 패널에서 조정한다
    - `Basic Strategy`는 현재 활성 전략의 편집 패널로서 작은 카드 여러 개 대신 하나의 긴 가로 패널로 정리한다
      - 진입: `후보 선정 방식` / `관찰 후보 수` / `진입 신호`
      - 청산: `익절·손절` / `보유 시간 제한` / `공통 실행 가드 안내`
      - 공통 리스크/실행: `최대 손실 한도` / `포지션 크기` / `거래 제한`
    - 구획 사이는 subtle divider로만 나누고, 각 구획 안은 `제목 -> 값/입력 -> 필요 시 보조 정보` 순서로 읽힌다
    - 긴 설명은 줄이고, 헷갈릴 수 있는 항목만 `?` tooltip으로 이동한다
    - 값 하나만 보는 항목은 한 줄, 여러 조건을 함께 보는 항목은 두 줄 중심으로 정리한다
    - `Advanced Settings`는 disclosure + 저대비 컨테이너로 Basic보다 한 단계 가볍게 표시하되, 내부는 전문가용 튜닝 패널처럼 정리한다
    - Advanced `Scanner/Signal/Risk` 카드는 같은 row에서 높이를 맞추고, 적은 내용의 카드는 spacer로 vertical rhythm을 보정한다
    - Advanced Scanner는 Basic과 겹치는 `기본 스캔 기준`/`Top-N` 직접 편집을 제거하고 `최소 거래 필터 + mode별 가중치`만 남긴다
    - scanner 가중치는 `2개 핸들 + 3개 구간` control로 조정하며, `순위 / 거래대금 / 등락률` 총합 100%를 자동 유지한다
    - 하단 별도 도움말 카드는 제거하고, 필요한 설명만 각 카드 제목 옆 `?` tooltip으로 이동한다
  - visual polish 원칙:
    - panel hierarchy를 분명히 해 상위 패널 / 하위 그룹 / 입력 표면 / 상태 badge가 같은 카드처럼 보이지 않게 한다
    - surface layering은 opacity 차이, 얇은 inner border, soft shadow, radius hierarchy로 만든다
    - spacing은 크게 비우기보다 계산된 리듬을 유지해 desktop utility/settings panel 느낌을 만든다
    - 입력 요소와 상태 요소는 서로 다른 재질감으로 구분한다
  - 폭/가독성 보정 원칙:
    - Strategy 페이지는 데스크톱 창 안에서 메인 패널이 작게 떠 보이지 않도록 일반 화면보다 더 넓은 읽기 폭을 사용한다
    - 상위 패널과 내부 카드의 비율을 키워 “모바일 카드가 가운데 모인 느낌”을 줄인다
    - 라벨/보조 설명/숫자/요약 값은 Dashboard/Logs보다 한 단계 큰 타입 스케일로 조정해 읽기 피로를 낮춘다
    - 하단 action bar는 본문과 같은 중심축에 정렬하되, visual weight는 더 낮게 유지한다
  - Basic 편집 항목:
    - 진입: 후보 선정 방식, 관찰 Top-N, 주요 진입 신호 유형
    - 청산: 목표 수익률, 손절 기준, 최대 보유시간
    - 공통 리스크/실행: 최대 손실 한도, 포지션 크기(전체 자산 대비 %), 일일 거래 제한 사용/최대 횟수, 동시 보유 제한, 장 마감 5분 전 전체 청산
  - 입력 컨트롤 규칙:
    - 정수 범위/단계값(`Top-N`, 보유시간, 최대 거래 횟수, 동시 보유 수)은 stepper형
    - 퍼센트/직접 입력값(`목표 수익률`, `손절`, `최대 손실`, `포지션 크기`, 고급 필터값)은 compact numeric field형
    - 토글은 별도 상태 pill 없이 스위치 자체로 상태를 표현
  - Basic Risk UX:
    - 포지션 크기는 단일 입력 `전체 자산 대비 비율(%)`로 고정
    - 일일 거래 제한은 `제한 사용(toggle) + 최대 거래 횟수(number)`로 분리
    - 제한 미사용 상태는 `무제한` 의미이며 sentinel 값(-1)은 UI에 노출하지 않음
    - 엔진 반영은 `max_concurrent_positions`, `daily_trade_limit_enabled`, `daily_trade_limit_count`, `position_size_pct`, `max_loss_limit_pct`를 적용
  - 반영 상태 표시:
    - `현재 전략 요약 > 적용 상태`에서 전체 반영 상태 badge를 우선 표기
    - `마지막 적용`, `일일 거래 제한 상태`, `일일 손실 한도 상태`를 함께 표시
    - 저장 성공과 실제 엔진 반영 완료를 구분해 표시
    - 리스크 요약에 `일일 거래 제한 상태`(오늘 사용/남은 횟수)와 `일일 손실 한도 상태`(오늘 손익/손실률/한도 도달 여부)를 함께 표시
    - group 구분은 `strategy / execution / risk`
  - Advanced 섹션:
    - `Scanner`: 최소 거래 필터 + mode별 가중치
    - `Signal`: 세부 신호 임계값 + 활성 유형
    - `Risk`: 공통 허용 신호 + 동시 후보 제한 + 재진입/시간창
  - 설명 문구 노출 정책:
    - 기본 화면은 한 줄 요약 중심
    - 장문 설명 대신 compact note를 유지
  - Scanner 섹션은 “스캔 점수 = 관찰용 후보 우선순위”를 중심으로 설명하며, 실전 매수 확률 점수로 오해되지 않게 안내
  - 내부 구현 용어는 사용자 문구로 번역해 노출
    - `turnover/surge` -> `거래대금 순위/급등률 순위`
    - `new_entry/rank_jump/rank_maintained` -> `신규 진입 후보/순위 급상승/상위권 유지`
  - 전략 이해에 직접 필요 없는 구현 항목(`페이지 증가 단위`, `스캔 최대 노출`, `후보군 상한`, `내부 소스명`)은 화면에서 숨김
  - 완성형 전략 빌더가 아니라 핵심 파라미터만 안전하게 조정 가능(템플릿/조건 블록 편집은 미지원)
- Scanner 페이지(운영형 2-pane)
  - 상단 헤더: `종목 스캔` + `자동 갱신` + `최근 스캔` 상태, 우측에 스캔 기준 토글 배치
  - 좌측: 후보 리스트(순위/종목명/현재가/등락률/거래대금) 테이블형 정렬
  - 좌측 리스트 상단 토글: `거래대금 순위` / `급등률 순위`
  - 데이터 소스: `GET /api/monitoring/scanner/ranks?mode=turnover|surge&limit=...`
  - 정렬 기준:
    - `turnover`: `metric desc`
    - `surge`: `change_pct desc`
  - 좌측 순위 박스 숫자는 서버 `display_rank`(mode 정렬 결과 `index+1`)를 기준으로 표시
  - mode 전환 시 10건부터 재조회하고, 하단 스크롤 도달 시 10건씩 추가 로드(최대 30)
  - 추가 로딩은 리스트 마지막 행이 화면에 도달할 때(`onAppear`) 다음 limit 재요청을 수행
  - limit 증가 시 앱은 기존 배열 append가 아니라 "증가된 limit의 전체 응답"으로 교체
  - 앱은 scanner endpoint 응답 순서를 그대로 사용하며, 로컬 재정렬을 수행하지 않음
  - WS market delta는 scanner 목록을 직접 섞지 않고 scanner endpoint 결과를 우선함
  - `거래대금`/`급등률`은 동일 pool 재정렬이 아니라 서버 mode별 독립 랭킹 결과를 사용
  - 좌측 순위는 선택 기준 정렬 결과를 숫자만 표시하며, 1~3위는 파란 계열 박스로 강조
  - 거래대금 표기: 억 단위 `79.2억` 형태(소수 1자리 반올림), 조 단위 `0조 0000억`
  - 종목명 셀은 1줄 우선 표시로 유지하고, 수치 컬럼 폭을 줄여 종목명 노출량을 확보
  - 헤더/좌우 pane은 미세 그라데이션 + 얇은 이중 보더 + 상단 하이라이트 + 부드러운 그림자로 재정리(고대비 과잉 억제)
  - 좌/우 pane은 세로 폴백 없이 항상 분할 레이아웃 유지(데스크톱 콘솔 고정형)
  - pane 비율: 좌/우 가로폭 `6:4`(좌 `660`, 우 `440`)
  - 리스트 높이: 좌측 목록은 10개 종목 높이로 고정하고 초과분만 내부 스크롤
  - Scanner 프레임: `1148x612`(컨텐츠), 앱 윈도우는 content-size 고정(`1360x760`)
  - 우측: 선택 종목 요약(가격/등락/변동값/스캔점수) + 차트(`1분/5분/일/주`) + 시가/고가/저가/전일종가/변동성
  - 우측 상단 등락률/변화값 배지는 선택 timeframe의 차트 points 기준으로 계산
    - 기준값: `points.first.open`(없으면 `points.first.close`)
    - 현재값: `points.last.close`
    - 변화값: `현재값 - 기준값`
    - 변화율: `(변화값 / 기준값) * 100`
  - points가 없거나 기준값이 0이면 기존 서버 변화값(`price/change_pct`)으로 fallback
  - 차트는 `/api/chart/{symbol}` 실데이터를 사용하며 KIS 원본 응답은 앱에서 직접 해석하지 않음
  - 서버 차트 소스 정책(현재):
    - `1m`: 당일 intraday 저장본 우선
    - `5m`: 저장된 `1m` 파생 집계
    - `1d/1w`: 저장 재사용(부족 시 서버가 보충)
  - `5분`은 서버 집계 봉을 그대로 사용
  - 우측 상세는 단일 패널에서 요약/상태배지/차트/보조지표를 연속된 흐름으로 표시
  - 차트 1단계 표시:
    - x축 시간축(`1m/5m=HH:mm`, `1d=MM-dd`, `1w=yy-MM`)
    - y축 가격축(KRW 주요 눈금)
    - 현재가 라벨(마지막 close)
    - 구간 고가/저가 라벨
  - 차트 하단 보조정보는 배경 박스 없이 구분선으로 표시하며 고가(빨간색), 저가(파란색) 색상 적용
  - 우측 상단은 기준/순위 텍스트를 제거해 핵심 관찰 정보 위주로 간소화
  - 선택 종목은 앱 상태(`selectedScannerCode`)로 유지되어 향후 Chart 연동 기반으로 사용
- Chart 페이지
  - Scanner와 동일한 `selectedScannerCode`/`selectedChartTimeframe` 상태를 공유
  - 동일 `/api/chart/{symbol}` 응답으로 라인 차트 + 시가/고가/저가/전일종가/변동성 표시
  - 상단 가격/등락 배지는 Scanner와 동일한 timeframe 기준 공통 계산 로직을 사용
  - 차트 1단계 표시(Scanner와 동일):
    - x축 시간축, y축 가격축
    - 현재가 라벨
    - 구간 고가/저가 라벨
  - 로딩/빈데이터/에러 상태를 별도 표현
  - 차트 요청 안정화:
    - 선택/타임프레임 변경 시 debounce(300ms) 적용
    - 이전 선택의 stale request는 cancel
    - 동일 key in-flight 요청은 중복 생성하지 않음
  - 에러 문구 분리:
    - `KIS 토큰 획득 실패`
    - `차트 데이터 조회 실패`
  - Scanner/Chart/Dev 공통 컨트롤 스타일 적용:
    - 스캔 기준/타임프레임 선택은 동일 커스텀 segmented control 사용
    - Chart 종목 선택은 공통 menu selector 스타일 사용
    - Dev `Reload Snapshot`/`Reconnect WS`는 보조 도구 버튼 스타일로 통일
  - Chart 하단 요약 영역은 Scanner와 동일한 공통 컴포넌트(`ChartMetricSummaryRow`)로 렌더링

## Dashboard 레이아웃(현재)
- 상단 KPI 4카드
  - 총 평가금액
  - 예수금
  - 평가손익
  - 최근 7일 승률
- 본문 2컬럼
  - 좌측: 스캔종목, 보유종목
  - 우측: 매매신호, 미체결주문, 최근 로그
- Dashboard 요약 정책(결과 중심)
  - `최근 로그`는 Logs와 동일 대표 이벤트 규칙을 사용한 최신 feed 축약본이다
  - `매매신호`는 종목별 현재 액션 상태 요약 카드로 표시
    - 각 행: 종목명, 짧은 근거 요약, 액션 배지(`매수`/`매도`), 상태 배지(`실행됨`/`대기중`/`모니터링`/`차단됨`)
    - 포함: 실제 매수/매도/진입/청산 신호, 실행/대기 상태, 중요한 리스크 차단 상태
    - 제외: 관망(`watch`/`rank_maintained`) 및 일반 보류(`already_holding`/`cooldown`) 계열
  - `최근 로그`는 Logs 페이지 최신 feed 축약본 역할을 유지
    - 관망 신호를 다시 포함하며, 시간순 사건 기록을 담당
- 스캔 종목 리스트는 고정 컬럼 정렬을 사용
  - 종목명/코드(가변 폭) + 점수 칩(`42`) + 현재가·등락률(`112`) + 거래대금(`80`)
  - 종목명이 길어도 점수 칩/우측 숫자 컬럼 x/y 정렬이 흔들리지 않도록 `rowMinHeight` 적용
- 스타일: `design_ref/figma_web_export/src/app/pages/Dashboard.tsx` 정보구조를 SwiftUI 패널/행 컴포지션으로 반영
- 데이터가 비어 있는 경우 각 섹션은 빈 상태 메시지를 표시
- `최근 로그`/`미체결 주문`은 Logs 페이지와 동일한 공통 이벤트 스타일 매핑(아이콘/색상)을 사용
- 계좌 KPI 데이터 소스:
  - `runtime.account_summary.total_account_value`
  - `runtime.account_summary.cash_balance`
  - `runtime.account_summary.unrealized_pnl_total`
  - `승률`: `recent_closed_positions`에서 최근 7일 + 현재 `order_mode` 기준으로 계산
  - 값 미가용 시 `-` 표시, 계좌 식별은 `masked_account` 우선(`account_label` fallback)

## 백엔드 URL 설정
Xcode Scheme 환경변수로 설정 가능합니다.

- `AUTOTRADING_BACKEND_BASE_URL` (필수 권장)
- `AUTOTRADING_BACKEND_WS_URL` (선택, 미설정 시 BASE_URL에서 `/ws/events` 자동 파생)

URL 결정 우선순위:
1. 환경변수
2. 앱 명시 설정값(코드 상수)
3. unresolved fallback(`backend-url-not-configured.invalid`)

주의:
- macOS 앱이 로컬에서 실행되고 백엔드가 원격 Linux 서버에서 실행되는 경우 `127.0.0.1`을 사용하면 안 됩니다.
- `127.0.0.1`은 Mac 자기 자신을 가리키므로, 반드시 원격 서버 IP 또는 도메인으로 설정해야 합니다.
- URL 환경변수가 비어 있으면 앱은 `backend-url-not-configured.invalid` placeholder로 실패하도록 동작하며, 시작 로그에서 최종 URL을 확인할 수 있습니다.
- ATS(App Transport Security) 개발 설정:
  - 현재 개발 편의를 위해 `NSAllowsArbitraryLoads = YES`가 적용되어 HTTP/WS(`http://`, `ws://`) 접속을 허용합니다.
  - 운영 배포에서는 반드시 HTTPS/WSS로 전환하거나 도메인 단위 예외(`NSExceptionDomains`)로 축소해야 합니다.

## 로컬 실행
1. macOS에서 `AutotradingMac.xcodeproj` 오픈
2. Scheme의 Run > Environment Variables 설정(필요 시)
3. `AutotradingMac` 타겟 실행
4. `Scanner` 페이지에서 좌측 후보 선택 시 우측 요약/차트/보조지표가 즉시 갱신되는지 확인
5. Scanner에서 타임프레임(`1분/5분/일/주`) 변경 시 차트가 실데이터 기준으로 재조회되는지 확인
6. `Chart` 페이지로 이동해 Scanner에서 선택한 종목/타임프레임이 동일하게 유지되는지 확인
6-1. 같은 종목/같은 타임프레임에서 Scanner 우측 상단 등락률/변화값과 Chart 상단 등락률/변화값이 동일한지 확인
7. `Chart` 페이지에서 종목/타임프레임 변경 시 로딩/빈데이터/에러 상태가 올바르게 표시되는지 확인
7-1. `Chart` 차트에서 x축 시간 라벨과 y축 가격 라벨이 함께 표시되는지 확인
7-2. `Chart` 차트에서 현재가 라벨과 `고/저` 라벨이 현재 points 기준으로 표시되는지 확인
8. `Scanner`에서 스캔 기준 토글(`거래대금 순위`/`급등률 순위`) 전환 시 순위/점수가 재정렬되는지 확인
8-1. `Scanner` 리스트 하단까지 스크롤 시 10개씩 추가 로드되고, 최대 30개에서 멈추는지 확인
9. 창 폭을 줄여도 Scanner가 세로 스택으로 바뀌지 않고 좌/우 분할을 유지하는지 확인
10. 좌측 리스트가 정확히 10개 행 높이로 유지되고 초과분만 스크롤되는지 확인
11. 좌측/우측 pane 하단 라인이 맞고, 우측 차트 영역만 유연하게 늘어나는지 확인
11-1. Scanner 우측 차트에서 x축/y축/현재가/고저가 오버레이가 겹치지 않고 읽히는지 확인
12. Scanner 헤더/좌우 pane의 그림자·보더·하이라이트 레이어가 과하지 않게 균형 있게 보이는지 확인
13. 차트 하단 보조정보가 네모 박스 없이 구분선 형태이며 고가/저가 색상이 각각 빨강/파랑인지 확인
14. 좌측 리스트에서 종목명이 세로로 꺾이지 않고 1줄 기준으로 자연스럽게 truncation 되는지 확인
15. `Logs` 페이지에서 좌측 항목 클릭 시 우측 상세 패널이 즉시 갱신되는지 확인
16. snapshot/WS 데이터 수신 시 좌측 목록과 선택 상세가 함께 갱신되는지 확인
17. top bar에서 `일시정지` 클릭 시 엔진 상태가 `paused`로 바뀌고 버튼 활성 규칙이 즉시 갱신되는지 확인
17-1. 장 종료 시간대에는 top bar가 `실행 중(장종료 대기)`와 `장 종료`를 표시하고, Dev/runtime에서 `market_closed_idle=true`가 보이는지 확인
18. top bar에서 `시작` 클릭 시 엔진 상태가 `running`으로 복귀하는지 확인
19. top bar에서 `긴급 정지` 클릭 시 확인 다이얼로그가 먼저 노출되고, 실행 후 `긴급 정지 상태`가 표시되는지 확인
20. `긴급 정지 상태`에서 `해제` 클릭 시 상태가 `stopped`로 바뀌고, 이후 `시작`이 다시 활성화되는지 확인
21. Dashboard KPI(총 평가금액/예수금/평가손익)가 `runtime.account_summary` 값과 일치하는지 확인
22. Dashboard `최근 7일 승률`이 현재 `order_mode` 기준으로 계산되어 mode 전환 시 값이 달라지는지 확인
23. `order_mode=live` 전환 실패 시 Dev에 `주문 모드 전환 실패`가 표시되고, top bar에는 오류 문구가 표시되지 않는지 확인
24. `account_mode=live`에서 계좌 조회 실패 시 Dev에 `계좌정보 조회 실패`가 표시되고, Dashboard KPI가 즉시 비워지지 않는지 확인
25. `Stategy` 페이지에서 `Scanner/Signal/Risk` 섹션이 서버값을 로드하고 draft 변경 시 `변경 사항 있음` 상태가 표시되는지 확인
26. `취소` 클릭 시 마지막 저장값으로 되돌아가는지 확인
27. `기본값 복원` 클릭 시 시스템 기본 전략값이 draft로 반영되는지 확인(즉시 저장 아님)
28. `저장` 클릭 시 `PATCH /api/monitoring/strategy-settings` 호출 후 `updated_at`이 갱신되는지 확인
29. 잘못된 값 입력 시 저장 전 검증 메시지 또는 서버 `422 detail` 메시지가 표시되는지 확인
26. Strategy 페이지에서 내부 구현 필드 대신 사용자 설명 문구(후보 선정 기준, 신호 생성 기준, 리스크 게이트 기준)가 우선 노출되는지 확인

## 주의사항
- 거래 실행 기능은 구현하지 않음(read-only monitoring 유지)
- `시작/일시정지/긴급 정지/해제`는 백엔드 `/api/engine/*` 제어 API와 연결된다.
- 긴급 정지는 확인 다이얼로그 후 실행되며, 복구는 반드시 `해제 -> 시작` 순서로 수행된다.
- 백엔드 계약(`/api/monitoring/*`, `/ws/events`)을 변경하지 않는 전제
