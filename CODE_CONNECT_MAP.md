# Code Connect Map (AutotradingMac)

`AutotradingMac` 앱의 화면-상태-네트워크-이벤트 연결 구조를 빠르게 파악하기 위한 문서입니다.

## 1) 앱 진입/DI
- `AutotradingMac/AutotradingMacApp.swift`
  - `@StateObject private var store = MonitoringStore()`
  - `ContentView().environmentObject(store)`로 전역 주입
- `AutotradingMac/ContentView.swift`
  - `AppShellView()` 렌더링
  - `.task { await store.start() }`로 초기 로드/WS 시작

## 2) 셸/내비게이션
- `AutotradingMac/Views/AppShellView.swift`
  - Sidebar 섹션: `Dashboard / Scanner / Chart / Logs / Settings / Dev`
  - 공통 상단: `GlobalTopBarView`
  - 상세 화면 라우팅:
    - `DashboardView`
    - `MarketView` (Scanner)
    - `ChartView`
    - `LogsView`
    - `SettingsView`
    - `DevWorkspaceView`

## 3) 설정/엔드포인트
- `AutotradingMac/Core/AppConfig.swift`
  - `AUTOTRADING_BACKEND_BASE_URL` (default: `http://127.0.0.1:8008`)
  - `AUTOTRADING_BACKEND_WS_URL` (optional)
  - `snapshotURL = <base>/api/monitoring/snapshot`
  - `webSocketURL = <ws or wss>/ws/events` (미설정 시 자동 파생)

## 4) 네트워크 레이어
- REST: `AutotradingMac/Network/MonitoringAPIClient.swift`
  - `fetchSnapshot()` -> `MonitoringSnapshotResponse`
- WS: `AutotradingMac/Network/MonitoringWebSocketClient.swift`
  - `connect() / disconnect() / receiveLoop()`
  - 콜백:
    - `onStateChange`
    - `onEvent` (`EventEnvelope`)
    - `onError`

## 5) 단일 상태 허브
- `AutotradingMac/ViewModels/MonitoringStore.swift`
  - ObservableObject 단일 스토어
  - 시작 흐름:
    1. `reloadSnapshot()`
    2. `webSocketClient.connect()`
  - 주요 상태:
    - `runtime`
    - `marketTopRanks`, `latestTicks`
    - `recentSignals`, `recentRiskDecisions`
    - `recentOrders`, `recentFills`
    - `currentPositions`, `recentClosedPositions`, `pnlSummary`
    - `connectionState`, `lastUpdatedAt`, `lastErrorMessage`
    - `selectedScannerCode`

## 6) 이벤트 -> 상태 적용 맵
- `connection.ack`
  - 연결 확인, `connectionState = .connected`
- `worker.status`
  - `runtime.workers.workers[...]` 갱신
- `engine.health`
  - `runtime.appStatus`, `runtime.executionMode` 갱신
- `market.rank_snapshot`
  - `marketTopRanks` upsert/sort
- `market.tick`
  - `latestTicks[code]` 갱신
- `signal.generated`
  - `recentSignals` prepend
- `risk.approved` / `risk.blocked`
  - `recentRiskDecisions` prepend
- `order.created` / `order.updated`
  - `recentOrders` upsert
- `fill.received`
  - `recentFills` prepend
- `position.updated`
  - `currentPositions` upsert
- `position.pnl_updated`
  - 포지션 mark/unrealized PnL 업데이트
- `position.closed`
  - 오픈 포지션 제거 + `recentClosedPositions` 추가

## 7) 화면별 주 데이터 소스
- `Views/GlobalTopBarView.swift`
  - `runtime`, `lastUpdatedAt`
  - 버튼은 placeholder(제어 API 미연결)
- `Views/DashboardView.swift`
  - 런타임/KPI + signals/orders/positions 요약
- `Views/MarketView.swift` (Scanner)
  - `marketRows`(rank+tick 합성) 기반 후보/상세
  - `selectedScannerCode`로 선택 상태 유지
- `Views/LogsView.swift`
  - signals/risk/orders/fills/positions를 운영자용 로그 피드로 재구성
- `Views/DevWorkspaceView.swift`
  - `reloadSnapshot()`, `reconnectWebSocket()` 수동 진단 액션

## 8) Scanner 전용 연결 포인트
- 레이아웃 상수: `Views/MarketView.swift` `ScannerLayout`
  - 좌/우 pane: `660:440` (6:4)
  - pane 높이: `660`
  - 좌측 리스트 viewport: 10행 고정 + 내부 스크롤
- 표시 포맷:
  - `Core/DisplayFormatters.swift`
  - 거래대금: `metricKorean()` (`0000.0억`, `0조 0000억`)

## 9) 백엔드 계약 의존점
- Snapshot:
  - `GET /api/monitoring/snapshot`
- WS:
  - `/ws/events`
- 이벤트 envelope:
  - `{ "type": "...", "ts": "...", "source": "...", "data": {...} }`

