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
- 연결 상태 / 마지막 업데이트 시각 / 오류 상태 표시
- 역할 분리
  - 운영 메인: Dashboard/Scanner/Chart/Logs/Settings
  - 개발/디버깅: Dev 하위 화면

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

## 주의사항
- 거래 실행/설정 저장/제어 기능은 구현하지 않음 (read-only)
- 백엔드 계약(`/api/monitoring/*`, `/ws/events`)을 변경하지 않는 전제
