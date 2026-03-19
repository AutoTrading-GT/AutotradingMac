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
- 역할 분리
  - 운영 메인: Dashboard/Scanner/Chart/Logs/Settings
  - 개발/디버깅: Dev 하위 화면
- 상단 정보 계층 분리
  - Global top bar(운영): 페이지명, 자동매매 상태, 장 상태, 마지막 갱신, `시작/일시정지/긴급 정지`(placeholder)
  - Dev tools(개발): 연결 상태, `Reload Snapshot`, `Reconnect WS`
- Logs 페이지(운영형 2-pane)
  - 좌측: 최근 이벤트 리스트(시간, 이벤트 타입 배지, 종목/코드, 한 줄 요약)
  - 우측: 선택 이벤트 상세(event type/timestamp/symbol/code/source + payload/meta)
  - 로그 미선택 시 우측 empty state 표시

## Dashboard 레이아웃(현재)
- 상단 KPI 4카드
  - 총 평가금액
  - 예수금(placeholder)
  - 평가손익
  - 승률
- 본문 2컬럼
  - 좌측(넓음): 스캔종목, 보유종목
  - 우측: 매매신호, 미체결주문, 최근로그, 시스템 요약
- 데이터가 비어 있는 경우 각 섹션은 빈 상태 메시지를 표시

## 백엔드 URL 설정
Xcode Scheme 환경변수로 설정 가능합니다.

- `AUTOTRADING_BACKEND_BASE_URL` (기본값: `http://127.0.0.1:8008`)
- `AUTOTRADING_BACKEND_WS_URL` (미설정 시 BASE_URL에서 `/ws/events` 자동 파생)

## 로컬 실행
1. macOS에서 `AutotradingMac.xcodeproj` 오픈
2. Scheme의 Run > Environment Variables 설정(필요 시)
3. `AutotradingMac` 타겟 실행
4. `Logs` 페이지에서 좌측 항목 클릭 시 우측 상세 패널이 즉시 갱신되는지 확인
5. snapshot/WS 데이터 수신 시 좌측 목록과 선택 상세가 함께 갱신되는지 확인

## 주의사항
- 거래 실행/설정 저장/제어 기능은 구현하지 않음 (read-only)
- `시작/일시정지/긴급 정지`는 UI placeholder이며 백엔드 제어 API와 연결되지 않음
- 백엔드 계약(`/api/monitoring/*`, `/ws/events`)을 변경하지 않는 전제
