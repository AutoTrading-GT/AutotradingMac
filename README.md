# AutotradingMac (macOS Monitoring Console)

읽기 전용 운영 콘솔입니다.  
백엔드(`autotrading-core`)의 REST snapshot + WebSocket delta를 수신해 상태를 표시합니다.

## 현재 범위
- Sidebar 기반 화면
  - Dashboard
  - Scanner
  - Chart
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
- 코드 연결 맵 문서: `CODE_CONNECT_MAP.md`
- 스타일 토큰 매핑 파일: `AutotradingMac/Core/DesignTokens.swift`
  - 출처: `design_ref/figma_web_export/src/styles/theme.css` (.dark 토큰)
  - 현재 단계: 토큰 정의만 추가(화면 일괄 적용은 후속)
- 역할 분리
  - 운영 메인: Dashboard/Scanner/Chart/Logs/Settings
  - 개발/디버깅: Dev 하위 화면
- 상단 정보 계층 분리
  - Global top bar(운영): 자동매매 상태, 장 상태, 마지막 갱신, `시작/일시정지/긴급 정지`(placeholder)
  - 페이지 제목은 top bar에서 노출하지 않고, 사이드바 선택 상태로 현재 페이지를 파악
  - 본문에서도 페이지 제목 헤더를 반복 노출하지 않고, 화면별 콘텐츠 영역에 집중
  - Dev tools(개발): 연결 상태, `Reload Snapshot`, `Reconnect WS`
- Logs 페이지(운영형 2-pane)
  - 좌측: 로그 피드(`시간 + 아이콘 + 한 줄 핵심 메시지`)
  - 핵심 메시지: 운영자 친화적 한국어 템플릿(예: `삼성전자 150주 매수 체결 @ 71,200원`, `NAVER 매수 신호 생성 (점수: 94)`)
  - 우측: 선택 이벤트 상세(event type/timestamp/symbol/code/source + payload/meta)
  - 로그 미선택 시 우측 empty state 표시
- Settings 페이지(운영형 2x2 패널)
  - `API 연결`, `알림 설정`, `데이터 관리`, `정보` 패널로 구성
  - `design_ref/figma_web_export/src/app/pages/SettingsPage.tsx` 정보구조를 SwiftUI로 반영
  - 토글/설정값은 현재 읽기 전용 표시이며 저장/제어 기능은 미연결
- Strategy Settings 페이지(설정 탭 내부)
  - `Settings` 화면 내 `전략 설정` 탭으로 제공
  - `design_ref/figma_web_export/src/app/pages/StrategySettings.tsx` 정보구조를 SwiftUI로 반영
  - 패널: `현재 전략`, `매수 조건`, `매도 조건`, `전략 선택`, `위험 관리`
  - 표시값은 `StrategyRuntimeConfig`가 읽는 실제 실행 환경값(`PAPER_*`, `RISK_*`, `EXECUTION_MODE`)과 코드 기본값을 사용
  - `임시 저장`/`적용` 버튼은 현재 placeholder(비활성) 상태
- Scanner 페이지(운영형 2-pane)
  - 상단 헤더: `종목 스캔` + `자동 갱신` + `최근 스캔` 상태, 우측에 스캔 기준 토글 배치
  - 좌측: 후보 리스트(순위/종목명/현재가/등락률/거래대금) 테이블형 정렬
  - 좌측 리스트 상단 토글: `거래대금 순위` / `급등률 순위`
  - 좌측 순위는 선택 기준 정렬 결과를 숫자만 표시하며, 1~3위는 파란 계열 박스로 강조
  - 거래대금 표기: 억 단위 `0000.0억`(소수 1자리 반올림), 조 단위 `0조 0000억`
  - 종목명 셀은 1줄 우선 표시로 유지하고, 수치 컬럼 폭을 줄여 종목명 노출량을 확보
  - 좌/우 pane은 세로 폴백 없이 항상 분할 레이아웃 유지(데스크톱 콘솔 고정형)
  - pane 비율: 좌/우 가로폭 `6:4`(좌 `660`, 우 `440`)
  - 리스트 높이: 좌측 목록은 10개 종목 높이로 고정하고 초과분만 내부 스크롤
  - Scanner 프레임: `1148x752`(컨텐츠), 앱 윈도우는 content-size 고정(`1360x830`)
  - 우측: 선택 종목 요약(가격/등락/변동값/스캔점수) + 차트(`1분/5분/일/주`) + 시가/고가/저가/전일종가/변동성
  - 우측 상세는 단일 패널에서 요약/상태배지/차트/보조지표를 연속된 흐름으로 표시
  - 차트 하단 보조정보는 배경 박스 없이 구분선으로 표시하며 고가(빨간색), 저가(파란색) 색상 적용
  - 우측 상단은 기준/순위 텍스트를 제거해 핵심 관찰 정보 위주로 간소화
  - 선택 종목은 앱 상태(`selectedScannerCode`)로 유지되어 향후 Chart 연동 기반으로 사용

## Dashboard 레이아웃(현재)
- 상단 KPI 4카드
  - 총 평가금액
  - 예수금(placeholder)
  - 평가손익
  - 승률
- 본문 2컬럼
  - 좌측: 스캔종목, 보유종목
  - 우측: 매매신호, 미체결주문, 최근로그
- 스타일: `design_ref/figma_web_export/src/app/pages/Dashboard.tsx` 정보구조를 SwiftUI 패널/행 컴포지션으로 반영
- 데이터가 비어 있는 경우 각 섹션은 빈 상태 메시지를 표시

## 백엔드 URL 설정
Xcode Scheme 환경변수로 설정 가능합니다.

- `AUTOTRADING_BACKEND_BASE_URL` (기본값: `http://127.0.0.1:8008`)
- `AUTOTRADING_BACKEND_WS_URL` (미설정 시 BASE_URL에서 `/ws/events` 자동 파생)

## 로컬 실행
1. macOS에서 `AutotradingMac.xcodeproj` 오픈
2. Scheme의 Run > Environment Variables 설정(필요 시)
3. `AutotradingMac` 타겟 실행
4. `Scanner` 페이지에서 좌측 후보 선택 시 우측 요약/차트/보조지표가 즉시 갱신되는지 확인
5. `Scanner`에서 스캔 기준 토글(`거래대금 순위`/`급등률 순위`) 전환 시 순위/점수가 재정렬되는지 확인
6. 창 폭을 줄여도 Scanner가 세로 스택으로 바뀌지 않고 좌/우 분할을 유지하는지 확인
7. 좌측 리스트가 정확히 10개 행 높이로 유지되고 초과분만 스크롤되는지 확인
8. 좌측/우측 pane 하단 라인이 맞고, 우측 차트 영역만 유연하게 늘어나는지 확인
9. 차트 하단 보조정보가 네모 박스 없이 구분선 형태이며 고가/저가 색상이 각각 빨강/파랑인지 확인
10. 좌측 리스트에서 종목명이 세로로 꺾이지 않고 1줄 기준으로 자연스럽게 truncation 되는지 확인
11. `Logs` 페이지에서 좌측 항목 클릭 시 우측 상세 패널이 즉시 갱신되는지 확인
12. snapshot/WS 데이터 수신 시 좌측 목록과 선택 상세가 함께 갱신되는지 확인

## 주의사항
- 거래 실행/설정 저장/제어 기능은 구현하지 않음 (read-only)
- `시작/일시정지/긴급 정지`는 UI placeholder이며 백엔드 제어 API와 연결되지 않음
- 백엔드 계약(`/api/monitoring/*`, `/ws/events`)을 변경하지 않는 전제
