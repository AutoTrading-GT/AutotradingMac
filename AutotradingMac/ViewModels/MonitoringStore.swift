//
//  MonitoringStore.swift
//  AutotradingMac
//

import Foundation
import Combine

@MainActor
final class MonitoringStore: ObservableObject {
    @Published private(set) var runtime: RuntimeStatusSnapshot?
    @Published private(set) var strategySettings: StrategySettingsSnapshot?
    @Published private(set) var strategyDefaults: StrategySettingsSnapshot?
    @Published private(set) var strategyDraft: StrategySettingsSnapshot?
    @Published private(set) var strategyApplyPolicy: String?
    @Published private(set) var strategyUpdatedAt: Date?
    @Published private(set) var strategyApplyStatus: StrategyApplyStatusSnapshot?
    @Published private(set) var strategyDirty = false
    @Published private(set) var strategySaveInFlight = false
    @Published private(set) var strategyValidationMessages: [String] = []
    @Published private(set) var marketTopRanks: [MarketRankSnapshotItem] = []
    @Published private(set) var recentSignals: [SignalSnapshotItem] = []
    @Published private(set) var recentRiskDecisions: [RiskDecisionSnapshotItem] = []
    @Published private(set) var recentOrders: [OrderSnapshotItem] = []
    @Published private(set) var recentFills: [FillSnapshotItem] = []
    @Published private(set) var currentPositions: [PositionSnapshotItem] = []
    @Published private(set) var recentClosedPositions: [ClosedPositionSnapshotItem] = []
    @Published private(set) var pnlSummary = PnLSummarySnapshot(
        openPositions: 0,
        unrealizedPnlTotal: nil,
        realizedPnlRecentTotal: nil,
        recentClosedCount: 0
    )

    @Published private(set) var latestTicks: [String: MarketTickPayload] = [:]
    @Published private(set) var isLoadingSnapshot = false
    @Published private(set) var snapshotLoaded = false
    @Published private(set) var connectionState: WebSocketConnectionState = .disconnected
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var lastStrategySettingsErrorMessage: String?
    @Published private(set) var lastOrderModeErrorMessage: String?
    @Published private(set) var lastAccountSummaryErrorMessage: String?
    @Published private(set) var engineActionInFlight: EngineControlAction?
    @Published private(set) var engineActionResultMessage: String?
    @Published private(set) var modeSwitchInFlight: RuntimeModeSwitchTarget?
    @Published private(set) var selectedScannerCode: String?
    @Published private(set) var selectedChartTimeframe: ChartTimeframeOption = .minute1
    @Published private(set) var chartSeriesCache: [String: ChartSeriesResponse] = [:]
    @Published private(set) var chartLoadingKeys: Set<String> = []
    @Published private(set) var chartErrorMessages: [String: String] = [:]
    @Published private(set) var scannerRankRowsByMode: [String: [MarketRankSnapshotItem]] = [:]
    @Published private(set) var scannerLoadedLimitByMode: [String: Int] = [:]
    @Published private(set) var scannerHasMoreByMode: [String: Bool] = [:]
    @Published private(set) var scannerLoadingModes: Set<String> = []

    private let apiClient: MonitoringAPIClientProtocol
    private let webSocketClient: MonitoringWebSocketClient
    private var started = false
    private let maxRecentItems = 100
    private var runtimeRefreshTask: Task<Void, Never>?
    private var snapshotRetryTask: Task<Void, Never>?
    private var chartFetchDebounceTask: Task<Void, Never>?
    private var chartFetchTasks: [String: Task<Void, Never>] = [:]
    private var lastRuntimeRefreshedAt: Date?
    private let runtimeRefreshMinInterval: TimeInterval = 2.0
    private let chartFetchDebounceNanoseconds: UInt64 = 300_000_000
    private let scannerStep = 10
    private let scannerMaxLimit = 30
    private let strategySupportedSignalTypes = ["new_entry", "rank_jump", "rank_maintained"]
    private let strategySelectionModes = ["turnover", "surge"]
    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let iso8601Basic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    init(
        apiClient: MonitoringAPIClientProtocol = MonitoringAPIClient(),
        webSocketClient: MonitoringWebSocketClient = MonitoringWebSocketClient()
    ) {
        self.apiClient = apiClient
        self.webSocketClient = webSocketClient
        bindWebSocketCallbacks()
    }

    func start() async {
        guard !started else { return }
        started = true
        await reloadSnapshot()
        scheduleSnapshotRetryIfNeeded()
        webSocketClient.connect()
    }

    func stop() {
        runtimeRefreshTask?.cancel()
        runtimeRefreshTask = nil
        snapshotRetryTask?.cancel()
        snapshotRetryTask = nil
        chartFetchDebounceTask?.cancel()
        chartFetchDebounceTask = nil
        for task in chartFetchTasks.values {
            task.cancel()
        }
        chartFetchTasks.removeAll()
        webSocketClient.disconnect()
        started = false
    }

    func reloadSnapshot() async {
        isLoadingSnapshot = true
        defer { isLoadingSnapshot = false }

        do {
            let snapshot = try await apiClient.fetchSnapshot()
            apply(snapshot: snapshot)
            snapshotLoaded = true
            lastErrorMessage = nil
            updateAccountSummaryDiagnostics(from: runtime)
            lastUpdatedAt = Date()
            lastRuntimeRefreshedAt = Date()
            snapshotRetryTask?.cancel()
            snapshotRetryTask = nil
        } catch {
            lastErrorMessage = diagnosticsErrorText(
                prefix: "Snapshot load failed",
                error: error
            )
            snapshotLoaded = false
            scheduleSnapshotRetryIfNeeded()
        }
        await reloadStrategySettings()
    }

    func reconnectWebSocket() {
        webSocketClient.disconnect()
        webSocketClient.connect()
    }

    func reloadStrategySettings() async {
        do {
            let envelope = try await apiClient.fetchStrategySettings()
            applyStrategySettingsEnvelope(envelope, preserveDirtyDraft: strategyDirty)
            lastStrategySettingsErrorMessage = nil
        } catch {
            lastStrategySettingsErrorMessage = diagnosticsErrorText(
                prefix: "Strategy settings load failed",
                error: error
            )
        }
    }

    func updateStrategyScannerDefaultMode(_ mode: String) {
        mutateStrategyDraft { draft in
            draft.scanner.defaultMode = mode
        }
    }

    func updateStrategyBasicSelectionMode(_ mode: String) {
        mutateStrategyDraft { draft in
            draft.scanner.defaultMode = mode
            draft.basic.entry.selectionMode = mode
        }
    }

    func updateStrategyScannerTopN(_ value: Int) {
        mutateStrategyDraft { draft in
            let normalized = min(max(value, 1), 30)
            draft.scanner.topN = normalized
            draft.signal.topN = normalized
            draft.basic.entry.topN = normalized
        }
    }

    func updateStrategyBasicTopN(_ value: Int) {
        mutateStrategyDraft { draft in
            let normalized = min(max(value, 1), 30)
            draft.scanner.topN = normalized
            draft.signal.topN = normalized
            draft.basic.entry.topN = normalized
        }
    }

    func updateStrategyScannerMinTurnover(_ value: Double?) {
        mutateStrategyDraft { draft in
            draft.scanner.minTurnover = value
        }
    }

    func updateStrategyScannerMinChangePct(_ value: Double?) {
        mutateStrategyDraft { draft in
            draft.scanner.minChangePct = value
        }
    }

    func updateStrategyScannerWeight(mode: String, key: String, value: Double) {
        mutateStrategyDraft { draft in
            guard var weights = draft.scanner.scoreDefinition.weights[mode] else { return }
            let normalized = max(0, value)
            switch key {
            case "rank":
                weights.rank = normalized
            case "turnover":
                weights.turnover = normalized
            case "change_pct":
                weights.changePct = normalized
            default:
                return
            }
            draft.scanner.scoreDefinition.weights[mode] = weights
        }
    }

    func updateStrategySignalTopN(_ value: Int) {
        mutateStrategyDraft { draft in
            let normalized = min(max(value, 1), 30)
            draft.signal.topN = normalized
            draft.scanner.topN = normalized
        }
    }

    func updateStrategyRankJumpThreshold(_ value: Int) {
        mutateStrategyDraft { draft in
            draft.signal.rankJumpThreshold = min(max(value, 1), 50)
        }
    }

    func updateStrategyRankJumpWindowSeconds(_ value: Int) {
        mutateStrategyDraft { draft in
            draft.signal.rankJumpWindowSeconds = min(max(value, 10), 86_400)
        }
    }

    func updateStrategyRankHoldTolerance(_ value: Int) {
        mutateStrategyDraft { draft in
            draft.signal.rankHoldTolerance = min(max(value, 0), 20)
        }
    }

    func updateStrategySignalTypeEnabled(_ type: String, isEnabled: Bool) {
        mutateStrategyDraft { draft in
            var current = Set(draft.signal.enabledSignalTypes)
            if isEnabled {
                current.insert(type)
            } else {
                current.remove(type)
            }
            draft.signal.enabledSignalTypes = strategySupportedSignalTypes.filter(current.contains)
            draft.basic.entry.enabledSignalTypes = draft.signal.enabledSignalTypes
        }
    }

    func updateStrategyBasicSignalTypeEnabled(_ type: String, isEnabled: Bool) {
        updateStrategySignalTypeEnabled(type, isEnabled: isEnabled)
    }

    func updateStrategyRiskTypeAllowed(_ type: String, isAllowed: Bool) {
        mutateStrategyDraft { draft in
            var current = Set(draft.risk.allowedSignalTypes)
            if isAllowed {
                current.insert(type)
            } else {
                current.remove(type)
            }
            draft.risk.allowedSignalTypes = strategySupportedSignalTypes.filter(current.contains)
        }
    }

    func updateStrategyMaxConcurrentCandidates(_ value: Int) {
        mutateStrategyDraft { draft in
            draft.risk.maxConcurrentCandidates = min(max(value, 1), 50)
            draft.basic.risk.maxConcurrentPositions = draft.risk.maxConcurrentCandidates
        }
    }

    func updateStrategyBasicTargetProfitPct(_ value: Double) {
        mutateStrategyDraft { draft in
            draft.basic.exit.targetProfitPct = min(max(value, 0), 100)
        }
    }

    func updateStrategyBasicStopLossPct(_ value: Double) {
        mutateStrategyDraft { draft in
            draft.basic.exit.stopLossPct = min(max(value, 0.1), 100)
        }
    }

    func updateStrategyBasicMaxHoldingMinutes(_ value: Int) {
        mutateStrategyDraft { draft in
            draft.basic.exit.maxHoldingMinutes = min(max(value, 1), 10_080)
        }
    }

    func updateStrategyBasicForceCloseOnMarketClose(_ value: Bool) {
        mutateStrategyDraft { draft in
            draft.basic.exit.forceCloseOnMarketClose = value
        }
    }

    func updateStrategyBasicMaxLossLimitPct(_ value: Double) {
        mutateStrategyDraft { draft in
            draft.basic.risk.maxLossLimitPct = min(max(value, 0), 100)
        }
    }

    func updateStrategyBasicPositionSizePct(_ value: Double) {
        mutateStrategyDraft { draft in
            draft.basic.risk.positionSizePct = min(max(value, 0.1), 100)
        }
    }

    func updateStrategyBasicDailyTradeLimitEnabled(_ enabled: Bool) {
        mutateStrategyDraft { draft in
            draft.basic.risk.dailyTradeLimitEnabled = enabled
            if draft.basic.risk.dailyTradeLimitCount < 1 {
                draft.basic.risk.dailyTradeLimitCount = 1
            }
        }
    }

    func updateStrategyBasicDailyTradeLimitCount(_ value: Int) {
        mutateStrategyDraft { draft in
            draft.basic.risk.dailyTradeLimitCount = min(max(value, 1), 1_000)
        }
    }

    func updateStrategyBasicMaxConcurrentPositions(_ value: Int) {
        mutateStrategyDraft { draft in
            let normalized = min(max(value, 1), 50)
            draft.basic.risk.maxConcurrentPositions = normalized
            draft.risk.maxConcurrentCandidates = normalized
        }
    }

    func updateStrategyCooldownMinutes(_ value: Int) {
        mutateStrategyDraft { draft in
            draft.risk.cooldownMinutes = min(max(value, 1), 1_440)
        }
    }

    func updateStrategySignalWindowMinutes(_ value: Int) {
        mutateStrategyDraft { draft in
            draft.risk.signalWindowMinutes = min(max(value, 1), 1_440)
            if draft.risk.cooldownMinutes < draft.risk.signalWindowMinutes {
                draft.risk.cooldownMinutes = draft.risk.signalWindowMinutes
            }
        }
    }

    func updateStrategyConcurrencyWindowMinutes(_ value: Int) {
        mutateStrategyDraft { draft in
            draft.risk.concurrencyWindowMinutes = min(max(value, 1), 1_440)
        }
    }

    func updateStrategyBlockWhenPositionExists(_ value: Bool) {
        mutateStrategyDraft { draft in
            draft.risk.blockWhenPositionExists = value
        }
    }

    func cancelStrategyDraftChanges() {
        strategyDraft = strategySettings
        strategyValidationMessages = []
        strategyDirty = false
        lastStrategySettingsErrorMessage = nil
    }

    func restoreStrategyDraftDefaults() {
        guard let defaults = strategyDefaults else { return }
        strategyDraft = defaults
        strategyValidationMessages = []
        recalculateStrategyDirty()
    }

    func saveStrategyDraft() async {
        guard strategySaveInFlight == false else { return }
        guard let base = strategySettings, let draft = strategyDraft else { return }
        let validationMessages = validateStrategyDraft(draft)
        strategyValidationMessages = validationMessages
        guard validationMessages.isEmpty else {
            lastStrategySettingsErrorMessage = validationMessages.joined(separator: "\n")
            return
        }
        if draft == base {
            strategyDirty = false
            return
        }

        strategySaveInFlight = true
        defer { strategySaveInFlight = false }

        do {
            let payload = buildStrategyUpdatePayload(base: base, draft: draft)
            let envelope = try await apiClient.updateStrategySettings(payload)
            applyStrategySettingsEnvelope(envelope, preserveDirtyDraft: false)
            strategyValidationMessages = []
            lastStrategySettingsErrorMessage = nil
            lastErrorMessage = nil
            lastUpdatedAt = Date()
        } catch {
            let message = diagnosticsErrorText(
                prefix: "Strategy settings save failed",
                error: error
            )
            lastStrategySettingsErrorMessage = message
        }
    }

    func performEngineAction(_ action: EngineControlAction) async {
        guard engineActionInFlight == nil else { return }
        guard canPerformEngineAction(action) else {
            lastErrorMessage = "현재 상태에서는 \(action.label) 동작을 수행할 수 없습니다."
            return
        }

        engineActionInFlight = action
        defer { engineActionInFlight = nil }

        do {
            let result: EngineControlCommandResponse
            switch action {
            case .start:
                result = try await apiClient.startEngine()
            case .pause:
                result = try await apiClient.pauseEngine()
            case .emergencyStop:
                result = try await apiClient.emergencyStopEngine()
            case .clearEmergencyStop:
                result = try await apiClient.clearEmergencyStop()
            }
            applyEngineControlSnapshot(result.engine)
            engineActionResultMessage = result.message
            lastErrorMessage = nil
            lastUpdatedAt = Date()
            await reloadSnapshot()
        } catch {
            lastErrorMessage = "엔진 제어 실패: \(error.localizedDescription)"
        }
    }

    func updateOrderMode(_ mode: String, confirmLive: Bool) async {
        guard modeSwitchInFlight == nil else { return }
        modeSwitchInFlight = .orderMode
        defer { modeSwitchInFlight = nil }

        do {
            let result = try await apiClient.setOrderMode(mode, confirmLive: confirmLive)
            applyEngineControlSnapshot(result.engine)
            engineActionResultMessage = result.message
            lastErrorMessage = nil
            lastOrderModeErrorMessage = nil
            lastUpdatedAt = Date()
            await reloadSnapshot()
        } catch {
            let detail = modeSwitchErrorMessage(
                prefix: "주문 모드 변경 실패",
                error: error
            )
            lastOrderModeErrorMessage = detail
            lastErrorMessage = detail
        }
    }

    func updateAccountMode(_ mode: String) async {
        guard modeSwitchInFlight == nil else { return }
        modeSwitchInFlight = .accountMode
        defer { modeSwitchInFlight = nil }

        do {
            let result = try await apiClient.setAccountMode(mode)
            applyEngineControlSnapshot(result.engine)
            engineActionResultMessage = result.message
            lastErrorMessage = nil
            lastAccountSummaryErrorMessage = nil
            lastUpdatedAt = Date()
            await reloadSnapshot()
        } catch {
            let detail = modeSwitchErrorMessage(
                prefix: "계좌 모드 변경 실패",
                error: error
            )
            lastAccountSummaryErrorMessage = detail
            lastErrorMessage = detail
        }
    }

    func canPerformEngineAction(_ action: EngineControlAction) -> Bool {
        if let inFlight = engineActionInFlight, inFlight != action {
            return false
        }
        guard let runtime else { return false }
        let allowed = Set(runtime.engineAvailableActions ?? [])
        if !allowed.isEmpty {
            return allowed.contains(action.apiAction)
        }

        let state = runtime.engineState?.lowercased() ?? "unknown"
        switch (state, action) {
        case ("running", .pause), ("running", .emergencyStop):
            return true
        case ("paused", .start), ("paused", .emergencyStop):
            return true
        case ("stopped", .start), ("stopped", .emergencyStop):
            return true
        case ("emergency_stopped", .clearEmergencyStop):
            return true
        default:
            return false
        }
    }

    func clearEngineActionResultMessage() {
        engineActionResultMessage = nil
    }

    func setSelectedScannerCode(_ code: String?) {
        guard selectedScannerCode != code else { return }
        selectedScannerCode = code
        scheduleChartFetchForSelectedSymbol(force: true)
    }

    func setSelectedChartTimeframe(_ timeframe: ChartTimeframeOption) {
        guard selectedChartTimeframe != timeframe else { return }
        selectedChartTimeframe = timeframe
        scheduleChartFetchForSelectedSymbol(force: true)
    }

    func chartSeries(
        for symbol: String,
        timeframe: ChartTimeframeOption
    ) -> ChartSeriesResponse? {
        chartSeriesCache[chartCacheKey(symbol: symbol, timeframe: timeframe)]
    }

    func chartErrorMessage(
        for symbol: String,
        timeframe: ChartTimeframeOption
    ) -> String? {
        chartErrorMessages[chartCacheKey(symbol: symbol, timeframe: timeframe)]
    }

    func isChartLoading(
        for symbol: String,
        timeframe: ChartTimeframeOption
    ) -> Bool {
        chartLoadingKeys.contains(chartCacheKey(symbol: symbol, timeframe: timeframe))
    }

    func refreshSelectedChartSeries(force: Bool = true) async {
        guard let symbol = selectedScannerCode else { return }
        await fetchChartSeries(symbol: symbol, timeframe: selectedChartTimeframe, force: force)
    }

    func activateScannerMode(_ mode: String) async {
        let normalized = normalizeScannerMode(mode)
        scannerRankRowsByMode[normalized] = []
        scannerLoadedLimitByMode[normalized] = 0
        scannerHasMoreByMode[normalized] = true
        await loadScannerRanks(mode: normalized, limit: scannerStep)
    }

    func loadMoreScannerRanksIfNeeded(mode: String) async {
        let normalized = normalizeScannerMode(mode)
        guard !scannerLoadingModes.contains(normalized) else { return }
        let currentLimit = scannerLoadedLimitByMode[normalized] ?? 0
        guard currentLimit < scannerMaxLimit else { return }
        if scannerHasMoreByMode[normalized] == false {
            return
        }
        let nextLimit = min(currentLimit + scannerStep, scannerMaxLimit)
        await loadScannerRanks(mode: normalized, limit: nextLimit)
    }

    func scannerRows(for mode: String) -> [MarketRow] {
        let normalized = normalizeScannerMode(mode)
        let baseRows: [MarketRankSnapshotItem]
        if let rows = scannerRankRowsByMode[normalized], !rows.isEmpty {
            baseRows = rows
        } else if normalized == "turnover" {
            baseRows = marketTopRanks
        } else {
            baseRows = []
        }

        return baseRows.map { rankItem in
            let tick = latestTicks[rankItem.code]
            return MarketRow(
                id: rankItem.code,
                code: rankItem.code,
                symbol: rankItem.symbol ?? tick?.symbol ?? "-",
                rank: rankItem.displayRank ?? rankItem.rank,
                rankingMode: rankItem.rankingMode ?? normalized,
                price: tick?.price ?? rankItem.price,
                changePct: rankItem.changePct ?? tick?.changePct,
                metric: rankItem.metric ?? tick?.metric,
                source: tick?.source ?? rankItem.source,
                updatedAt: tick?.timestamp ?? rankItem.capturedAt
            )
        }
    }

    func scannerIsLoading(mode: String) -> Bool {
        scannerLoadingModes.contains(normalizeScannerMode(mode))
    }

    func scannerCanLoadMore(mode: String) -> Bool {
        let normalized = normalizeScannerMode(mode)
        let currentLimit = scannerLoadedLimitByMode[normalized] ?? 0
        if currentLimit >= scannerMaxLimit {
            return false
        }
        return scannerHasMoreByMode[normalized] ?? true
    }

    var workerRows: [WorkerStatusRow] {
        guard let workers = runtime?.workers.workers else { return [] }
        return workers.keys.sorted().map { workerName in
            let entry = workers[workerName] ?? [:]
            return WorkerStatusRow(
                id: workerName,
                worker: workerName,
                status: entry["status"]?.stringValue ?? "unknown",
                error: entry["error"]?.stringValue,
                statusMessage: entry["status_message"]?.stringValue,
                rankSource: entry["rank_source"]?.stringValue,
                tickSource: entry["tick_source"]?.stringValue,
                syncStatus: entry["sync_status"]?.stringValue
            )
        }
    }

    var dashboardCards: [RuntimeMetricCard] {
        guard let runtime else { return [] }
        return [
            RuntimeMetricCard(
                id: "app-status",
                title: "App Status",
                value: runtime.appStatus,
                tone: .fromStatus(runtime.appStatus)
            ),
            RuntimeMetricCard(
                id: "readiness",
                title: "Readiness",
                value: runtime.readinessStatus,
                tone: .fromStatus(runtime.readinessStatus)
            ),
            RuntimeMetricCard(
                id: "database",
                title: "Database",
                value: runtime.databaseStatus,
                tone: .fromStatus(runtime.databaseStatus)
            ),
            RuntimeMetricCard(
                id: "order-mode",
                title: "Order Mode",
                value: runtime.orderMode,
                tone: .info
            ),
            RuntimeMetricCard(
                id: "account-mode",
                title: "Account Mode",
                value: runtime.accountMode,
                tone: .info
            ),
            RuntimeMetricCard(
                id: "ws-clients",
                title: "WS Clients",
                value: "\(runtime.activeWsClients)",
                tone: .neutral
            ),
        ]
    }

    var marketRows: [MarketRow] {
        let rankByCode = Dictionary(uniqueKeysWithValues: marketTopRanks.map { ($0.code, $0) })
        let codes = Set(rankByCode.keys).union(latestTicks.keys)

        let rows = codes.map { code -> MarketRow in
            let rankItem = rankByCode[code]
            let tick = latestTicks[code]
            return MarketRow(
                id: code,
                code: code,
                symbol: rankItem?.symbol ?? tick?.symbol ?? "-",
                rank: rankItem?.rank,
                rankingMode: rankItem?.rankingMode ?? "turnover",
                price: tick?.price ?? rankItem?.price,
                changePct: tick?.changePct ?? rankItem?.changePct,
                metric: tick?.metric ?? rankItem?.metric,
                source: tick?.source ?? rankItem?.source,
                updatedAt: tick?.timestamp ?? rankItem?.capturedAt
            )
        }

        return rows.sorted { lhs, rhs in
            switch (lhs.rank, rhs.rank) {
            case let (l?, r?):
                return l < r
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.code < rhs.code
            }
        }
    }

    var recentErrorItems: [String] {
        var errors: [String] = []
        if let startupError = runtime?.startupError, !startupError.isEmpty {
            errors.append("startup_error: \(startupError)")
        }
        for row in workerRows where row.error?.isEmpty == false {
            errors.append("\(row.worker): \(row.error ?? "")")
        }
        return errors
    }

    var strategyLastAppliedAt: Date? {
        strategyApplyStatus?.lastAppliedAt
    }

    func strategyGroupApplyStatus(_ group: String) -> StrategyApplyGroupStatusSnapshot? {
        strategyApplyStatus?.groups[group]
    }

    private func applyStrategySettingsEnvelope(
        _ envelope: StrategySettingsResponseEnvelope,
        preserveDirtyDraft: Bool
    ) {
        var data = envelope.data
        var defaults = envelope.defaults
        normalizeStrategyDraft(&data)
        normalizeStrategyDraft(&defaults)
        strategySettings = data
        strategyDefaults = defaults
        strategyApplyPolicy = envelope.applyPolicy
        strategyUpdatedAt = envelope.updatedAt
        strategyApplyStatus = envelope.applyStatus
        if !preserveDirtyDraft {
            strategyDraft = data
            strategyValidationMessages = []
            strategyDirty = false
        } else {
            if var draft = strategyDraft {
                normalizeStrategyDraft(&draft)
                strategyDraft = draft
            }
            recalculateStrategyDirty()
        }
    }

    private func mutateStrategyDraft(_ mutate: (inout StrategySettingsSnapshot) -> Void) {
        guard var draft = strategyDraft ?? strategySettings else { return }
        mutate(&draft)
        normalizeStrategyDraft(&draft)
        strategyDraft = draft
        strategyValidationMessages = validateStrategyDraft(draft)
        recalculateStrategyDirty()
    }

    private func normalizeStrategyDraft(_ draft: inout StrategySettingsSnapshot) {
        // Keep linked fields consistent across legacy(top-level), basic, and advanced sections.
        draft.advanced.scanner = draft.scanner
        draft.advanced.signal = draft.signal
        draft.advanced.risk = draft.risk

        draft.basic.entry.selectionMode = draft.scanner.defaultMode
        draft.basic.entry.topN = draft.signal.topN
        draft.basic.entry.enabledSignalTypes = draft.signal.enabledSignalTypes
        draft.basic.risk.maxConcurrentPositions = draft.risk.maxConcurrentCandidates
    }

    private func recalculateStrategyDirty() {
        guard let server = strategySettings, let draft = strategyDraft else {
            strategyDirty = false
            return
        }
        strategyDirty = draft != server
    }

    private func validateStrategyDraft(_ draft: StrategySettingsSnapshot) -> [String] {
        var errors: [String] = []
        let scanner = draft.scanner
        let signal = draft.signal
        let risk = draft.risk
        let basic = draft.basic

        if !strategySelectionModes.contains(scanner.defaultMode) {
            errors.append("기본 스캔 기준은 거래대금 순위/급등률 순위 중 하나여야 합니다.")
        }
        if !(1...30).contains(scanner.topN) {
            errors.append("상위 후보 평가 범위(Top-N)는 1~30 사이여야 합니다.")
        }
        if let minTurnover = scanner.minTurnover, minTurnover < 0 {
            errors.append("최소 거래대금 필터는 0 이상이어야 합니다.")
        }
        if let minChange = scanner.minChangePct, minChange < 0 || minChange > 100 {
            errors.append("최소 등락률 필터는 0~100 범위여야 합니다.")
        }
        for mode in ["turnover", "surge"] {
            guard let weights = scanner.scoreDefinition.weights[mode] else { continue }
            let total = weights.rank + weights.turnover + weights.changePct
            if weights.rank < 0 || weights.turnover < 0 || weights.changePct < 0 {
                errors.append("스캔 점수 가중치는 음수일 수 없습니다.")
            }
            if total <= 0 {
                errors.append("\(mode == "turnover" ? "거래대금" : "급등률") 기준 가중치 합계는 0보다 커야 합니다.")
            }
        }

        if !(1...30).contains(signal.topN) {
            errors.append("Signal Top-N은 1~30 사이여야 합니다.")
        }
        if !(1...50).contains(signal.rankJumpThreshold) {
            errors.append("급상승 임계값은 1~50 범위여야 합니다.")
        }
        if !(10...86_400).contains(signal.rankJumpWindowSeconds) {
            errors.append("급상승 윈도우는 10~86400초 범위여야 합니다.")
        }
        if !(0...20).contains(signal.rankHoldTolerance) {
            errors.append("상위권 유지 편차는 0~20 범위여야 합니다.")
        }
        if signal.enabledSignalTypes.isEmpty {
            errors.append("활성 신호 유형은 최소 1개 이상 선택해야 합니다.")
        }
        let unsupportedSignalTypes = signal.enabledSignalTypes.filter { !strategySupportedSignalTypes.contains($0) }
        if !unsupportedSignalTypes.isEmpty {
            errors.append("활성 신호 유형에 지원되지 않는 값이 포함되어 있습니다.")
        }

        if risk.allowedSignalTypes.isEmpty {
            errors.append("리스크 허용 신호 유형은 최소 1개 이상 선택해야 합니다.")
        }
        let unsupportedRiskTypes = risk.allowedSignalTypes.filter { !strategySupportedSignalTypes.contains($0) }
        if !unsupportedRiskTypes.isEmpty {
            errors.append("리스크 허용 신호 유형에 지원되지 않는 값이 포함되어 있습니다.")
        }
        if !(1...50).contains(risk.maxConcurrentCandidates) {
            errors.append("최대 동시 후보 수는 1~50 범위여야 합니다.")
        }
        if !(1...1_440).contains(risk.cooldownMinutes) {
            errors.append("재진입 대기 시간은 1~1440분 범위여야 합니다.")
        }
        if !(1...1_440).contains(risk.signalWindowMinutes) {
            errors.append("신호 유효 시간은 1~1440분 범위여야 합니다.")
        }
        if !(1...1_440).contains(risk.concurrencyWindowMinutes) {
            errors.append("동시성 계산 시간창은 1~1440분 범위여야 합니다.")
        }

        if !strategySelectionModes.contains(basic.entry.selectionMode) {
            errors.append("진입 전략의 후보 선정 방식이 올바르지 않습니다.")
        }
        if !(1...30).contains(basic.entry.topN) {
            errors.append("진입 전략의 관찰 후보 수는 1~30 범위여야 합니다.")
        }
        if basic.entry.enabledSignalTypes.isEmpty {
            errors.append("진입 전략의 주요 진입 신호는 최소 1개 이상 선택해야 합니다.")
        }
        if basic.entry.enabledSignalTypes.contains(where: { !strategySupportedSignalTypes.contains($0) }) {
            errors.append("진입 전략의 주요 진입 신호에 지원되지 않는 값이 포함되어 있습니다.")
        }

        if basic.exit.targetProfitPct < 0 || basic.exit.targetProfitPct > 100 {
            errors.append("목표 수익률은 0~100% 범위여야 합니다.")
        }
        if basic.exit.stopLossPct <= 0 || basic.exit.stopLossPct > 100 {
            errors.append("손절 기준은 0% 초과 ~ 100% 이하 범위여야 합니다.")
        }
        if !(1...10_080).contains(basic.exit.maxHoldingMinutes) {
            errors.append("보유 시간 제한은 1~10080분 범위여야 합니다.")
        }

        if basic.risk.maxLossLimitPct < 0 || basic.risk.maxLossLimitPct > 100 {
            errors.append("최대 손실 한도는 0~100% 범위여야 합니다.")
        }
        if basic.risk.positionSizePct <= 0 || basic.risk.positionSizePct > 100 {
            errors.append("포지션 크기 비율은 0% 초과 ~ 100% 이하 범위여야 합니다.")
        }
        if !(1...1_000).contains(basic.risk.dailyTradeLimitCount) {
            errors.append("최대 거래 횟수는 1~1000 범위여야 합니다.")
        }
        if !(1...50).contains(basic.risk.maxConcurrentPositions) {
            errors.append("동시 보유 종목 수 제한은 1~50 범위여야 합니다.")
        }

        if basic.entry.selectionMode != scanner.defaultMode {
            errors.append("진입 전략의 후보 선정 방식과 고급 스캐너 기본 기준이 일치해야 합니다.")
        }
        if basic.entry.topN != signal.topN {
            errors.append("진입 전략 후보 수와 Signal Top-N이 일치해야 합니다.")
        }
        if Set(basic.entry.enabledSignalTypes) != Set(signal.enabledSignalTypes) {
            errors.append("진입 신호 유형과 Signal 활성 신호 유형이 일치해야 합니다.")
        }
        if basic.risk.maxConcurrentPositions != risk.maxConcurrentCandidates {
            errors.append("리스크 동시 보유 제한과 고급 Risk 동시 후보 수가 일치해야 합니다.")
        }

        return errors
    }

    private func buildStrategyUpdatePayload(
        base: StrategySettingsSnapshot,
        draft: StrategySettingsSnapshot
    ) -> StrategySettingsUpdatePayload {
        let basicPatch: BasicStrategySettingsUpdatePayload? = {
            var hasChange = false
            let entryPatch: BasicEntrySettingsUpdatePayload? = {
                var entryChanged = false
                let selectionMode: String? = {
                    guard draft.basic.entry.selectionMode != base.basic.entry.selectionMode else { return nil }
                    entryChanged = true
                    hasChange = true
                    return draft.basic.entry.selectionMode
                }()
                let topN: Int? = {
                    guard draft.basic.entry.topN != base.basic.entry.topN else { return nil }
                    entryChanged = true
                    hasChange = true
                    return draft.basic.entry.topN
                }()
                let enabledTypes: [String]? = {
                    guard Set(draft.basic.entry.enabledSignalTypes) != Set(base.basic.entry.enabledSignalTypes) else { return nil }
                    entryChanged = true
                    hasChange = true
                    return draft.basic.entry.enabledSignalTypes
                }()
                guard entryChanged else { return nil }
                return BasicEntrySettingsUpdatePayload(
                    selectionMode: selectionMode,
                    topN: topN,
                    enabledSignalTypes: enabledTypes
                )
            }()

            let exitPatch: BasicExitSettingsUpdatePayload? = {
                var exitChanged = false
                let targetProfitPct: Double? = {
                    guard draft.basic.exit.targetProfitPct != base.basic.exit.targetProfitPct else { return nil }
                    exitChanged = true
                    hasChange = true
                    return draft.basic.exit.targetProfitPct
                }()
                let stopLossPct: Double? = {
                    guard draft.basic.exit.stopLossPct != base.basic.exit.stopLossPct else { return nil }
                    exitChanged = true
                    hasChange = true
                    return draft.basic.exit.stopLossPct
                }()
                let maxHoldingMinutes: Int? = {
                    guard draft.basic.exit.maxHoldingMinutes != base.basic.exit.maxHoldingMinutes else { return nil }
                    exitChanged = true
                    hasChange = true
                    return draft.basic.exit.maxHoldingMinutes
                }()
                let forceCloseOnMarketClose: Bool? = {
                    guard draft.basic.exit.forceCloseOnMarketClose != base.basic.exit.forceCloseOnMarketClose else { return nil }
                    exitChanged = true
                    hasChange = true
                    return draft.basic.exit.forceCloseOnMarketClose
                }()
                guard exitChanged else { return nil }
                return BasicExitSettingsUpdatePayload(
                    targetProfitPct: targetProfitPct,
                    stopLossPct: stopLossPct,
                    maxHoldingMinutes: maxHoldingMinutes,
                    forceCloseOnMarketClose: forceCloseOnMarketClose
                )
            }()

            let riskPatch: BasicRiskSettingsUpdatePayload? = {
                var riskChanged = false
                let maxLossLimitPct: Double? = {
                    guard draft.basic.risk.maxLossLimitPct != base.basic.risk.maxLossLimitPct else { return nil }
                    riskChanged = true
                    hasChange = true
                    return draft.basic.risk.maxLossLimitPct
                }()
                let positionSizePct: Double? = {
                    guard draft.basic.risk.positionSizePct != base.basic.risk.positionSizePct else { return nil }
                    riskChanged = true
                    hasChange = true
                    return draft.basic.risk.positionSizePct
                }()
                let dailyTradeLimitEnabled: Bool? = {
                    guard draft.basic.risk.dailyTradeLimitEnabled != base.basic.risk.dailyTradeLimitEnabled else { return nil }
                    riskChanged = true
                    hasChange = true
                    return draft.basic.risk.dailyTradeLimitEnabled
                }()
                let dailyTradeLimitCount: Int? = {
                    guard draft.basic.risk.dailyTradeLimitCount != base.basic.risk.dailyTradeLimitCount else { return nil }
                    riskChanged = true
                    hasChange = true
                    return draft.basic.risk.dailyTradeLimitCount
                }()
                let maxConcurrentPositions: Int? = {
                    guard draft.basic.risk.maxConcurrentPositions != base.basic.risk.maxConcurrentPositions else { return nil }
                    riskChanged = true
                    hasChange = true
                    return draft.basic.risk.maxConcurrentPositions
                }()
                guard riskChanged else { return nil }
                return BasicRiskSettingsUpdatePayload(
                    maxLossLimitPct: maxLossLimitPct,
                    positionSizePct: positionSizePct,
                    dailyTradeLimitEnabled: dailyTradeLimitEnabled,
                    dailyTradeLimitCount: dailyTradeLimitCount,
                    maxConcurrentPositions: maxConcurrentPositions
                )
            }()

            guard hasChange else { return nil }
            return BasicStrategySettingsUpdatePayload(
                entry: entryPatch,
                exit: exitPatch,
                risk: riskPatch
            )
        }()

        let scannerPatch: ScannerSettingsUpdatePayload? = {
            var hasChange = false
            let defaultMode: String? = {
                guard draft.scanner.defaultMode != base.scanner.defaultMode else { return nil }
                hasChange = true
                return draft.scanner.defaultMode
            }()
            let topN: Int? = {
                guard draft.scanner.topN != base.scanner.topN else { return nil }
                hasChange = true
                return draft.scanner.topN
            }()
            let minTurnover: Double? = {
                guard draft.scanner.minTurnover != base.scanner.minTurnover else { return nil }
                hasChange = true
                return draft.scanner.minTurnover
            }()
            let minChangePct: Double? = {
                guard draft.scanner.minChangePct != base.scanner.minChangePct else { return nil }
                hasChange = true
                return draft.scanner.minChangePct
            }()

            let weightsPatch: ScannerWeightsUpdatePayload? = {
                let turnover = buildWeightPatch(
                    base: base.scanner.scoreDefinition.weights["turnover"],
                    draft: draft.scanner.scoreDefinition.weights["turnover"]
                )
                let surge = buildWeightPatch(
                    base: base.scanner.scoreDefinition.weights["surge"],
                    draft: draft.scanner.scoreDefinition.weights["surge"]
                )
                if turnover != nil || surge != nil {
                    hasChange = true
                    return ScannerWeightsUpdatePayload(turnover: turnover, surge: surge)
                }
                return nil
            }()

            guard hasChange else { return nil }
            return ScannerSettingsUpdatePayload(
                defaultMode: defaultMode,
                topN: topN,
                minTurnover: minTurnover,
                minChangePct: minChangePct,
                weights: weightsPatch
            )
        }()

        let signalPatch: SignalSettingsUpdatePayload? = {
            var hasChange = false
            let topN: Int? = {
                guard draft.signal.topN != base.signal.topN else { return nil }
                hasChange = true
                return draft.signal.topN
            }()
            let jumpThreshold: Int? = {
                guard draft.signal.rankJumpThreshold != base.signal.rankJumpThreshold else { return nil }
                hasChange = true
                return draft.signal.rankJumpThreshold
            }()
            let jumpWindow: Int? = {
                guard draft.signal.rankJumpWindowSeconds != base.signal.rankJumpWindowSeconds else { return nil }
                hasChange = true
                return draft.signal.rankJumpWindowSeconds
            }()
            let holdTolerance: Int? = {
                guard draft.signal.rankHoldTolerance != base.signal.rankHoldTolerance else { return nil }
                hasChange = true
                return draft.signal.rankHoldTolerance
            }()
            let enabledTypes: [String]? = {
                guard Set(draft.signal.enabledSignalTypes) != Set(base.signal.enabledSignalTypes) else { return nil }
                hasChange = true
                return draft.signal.enabledSignalTypes
            }()

            guard hasChange else { return nil }
            return SignalSettingsUpdatePayload(
                topN: topN,
                rankJumpThreshold: jumpThreshold,
                rankJumpWindowSeconds: jumpWindow,
                rankHoldTolerance: holdTolerance,
                enabledSignalTypes: enabledTypes
            )
        }()

        let riskPatch: RiskSettingsUpdatePayload? = {
            var hasChange = false
            let allowed: [String]? = {
                guard Set(draft.risk.allowedSignalTypes) != Set(base.risk.allowedSignalTypes) else { return nil }
                hasChange = true
                return draft.risk.allowedSignalTypes
            }()
            let maxConcurrent: Int? = {
                guard draft.risk.maxConcurrentCandidates != base.risk.maxConcurrentCandidates else { return nil }
                hasChange = true
                return draft.risk.maxConcurrentCandidates
            }()
            let cooldown: Int? = {
                guard draft.risk.cooldownMinutes != base.risk.cooldownMinutes else { return nil }
                hasChange = true
                return draft.risk.cooldownMinutes
            }()
            let signalWindow: Int? = {
                guard draft.risk.signalWindowMinutes != base.risk.signalWindowMinutes else { return nil }
                hasChange = true
                return draft.risk.signalWindowMinutes
            }()
            let concurrencyWindow: Int? = {
                guard draft.risk.concurrencyWindowMinutes != base.risk.concurrencyWindowMinutes else { return nil }
                hasChange = true
                return draft.risk.concurrencyWindowMinutes
            }()
            let blockWhenHolding: Bool? = {
                guard draft.risk.blockWhenPositionExists != base.risk.blockWhenPositionExists else { return nil }
                hasChange = true
                return draft.risk.blockWhenPositionExists
            }()

            guard hasChange else { return nil }
            return RiskSettingsUpdatePayload(
                allowedSignalTypes: allowed,
                maxConcurrentCandidates: maxConcurrent,
                cooldownMinutes: cooldown,
                signalWindowMinutes: signalWindow,
                concurrencyWindowMinutes: concurrencyWindow,
                blockWhenPositionExists: blockWhenHolding
            )
        }()

        let advancedPatch = AdvancedStrategySettingsUpdatePayload(
            scanner: scannerPatch,
            signal: signalPatch,
            risk: riskPatch
        )

        return StrategySettingsUpdatePayload(
            basic: basicPatch,
            advanced: (scannerPatch != nil || signalPatch != nil || riskPatch != nil) ? advancedPatch : nil,
            scanner: nil,
            signal: nil,
            risk: nil
        )
    }

    private func buildWeightPatch(
        base: ScannerScoreWeightsSnapshot?,
        draft: ScannerScoreWeightsSnapshot?
    ) -> ScannerScoreWeightsUpdatePayload? {
        guard let base, let draft else { return nil }
        let rank = draft.rank != base.rank ? draft.rank : nil
        let turnover = draft.turnover != base.turnover ? draft.turnover : nil
        let changePct = draft.changePct != base.changePct ? draft.changePct : nil
        if rank == nil && turnover == nil && changePct == nil {
            return nil
        }
        return ScannerScoreWeightsUpdatePayload(rank: rank, turnover: turnover, changePct: changePct)
    }

    private func bindWebSocketCallbacks() {
        webSocketClient.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.connectionState = state
                if state == .connected, self?.snapshotLoaded == false {
                    await self?.reloadSnapshot()
                }
            }
        }

        webSocketClient.onError = { [weak self] message in
            Task { @MainActor in
                self?.lastErrorMessage = message
            }
        }

        webSocketClient.onEvent = { [weak self] envelope in
            Task { @MainActor in
                self?.handle(event: envelope)
            }
        }
    }

    private func apply(snapshot: MonitoringSnapshotResponse) {
        runtime = snapshot.runtime
        updateAccountSummaryDiagnostics(from: runtime)
        marketTopRanks = snapshot.marketTopRanks
        scannerRankRowsByMode["turnover"] = snapshot.marketTopRanks
        scannerLoadedLimitByMode["turnover"] = min(scannerStep, snapshot.marketTopRanks.count)
        scannerHasMoreByMode["turnover"] = snapshot.marketTopRanks.count >= scannerStep
        recentSignals = snapshot.recentSignals
        recentRiskDecisions = snapshot.recentRiskDecisions
        recentOrders = snapshot.recentOrders
        recentFills = snapshot.recentFills
        currentPositions = snapshot.currentPositions
        recentClosedPositions = snapshot.recentClosedPositions
        pnlSummary = snapshot.pnlSummary
        ensureSelectedScannerCode()
        scheduleChartFetchForSelectedSymbol(force: false)
    }

    private func normalizeScannerMode(_ mode: String) -> String {
        let normalized = mode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "surge" ? "surge" : "turnover"
    }

    private func loadScannerRanks(mode: String, limit: Int) async {
        let normalizedMode = normalizeScannerMode(mode)
        let normalizedLimit = min(max(limit, scannerStep), scannerMaxLimit)
        guard !scannerLoadingModes.contains(normalizedMode) else { return }

        scannerLoadingModes.insert(normalizedMode)
        defer { scannerLoadingModes.remove(normalizedMode) }

        do {
            let response = try await apiClient.fetchScannerRanks(
                mode: normalizedMode,
                limit: normalizedLimit
            )
            // Scanner endpoint는 이미 mode별 정렬/순위를 계산한다.
            // 앱은 응답 순서를 그대로 유지한다(재정렬 금지).
            scannerRankRowsByMode[normalizedMode] = response.data
            scannerLoadedLimitByMode[normalizedMode] = response.limit
            let inferredHasMore = response.data.count >= normalizedLimit && normalizedLimit < scannerMaxLimit
            scannerHasMoreByMode[normalizedMode] = response.hasMore || inferredHasMore
            if normalizedMode == "turnover" {
                marketTopRanks = response.data
            }
            lastErrorMessage = nil
        } catch {
            let detail = diagnosticsErrorText(
                prefix: "Scanner(\(normalizedMode)) load failed",
                error: error
            )
            lastErrorMessage = detail
        }
    }

    private func handle(event: EventEnvelope) {
        lastUpdatedAt = event.ts

        switch event.type {
        case "connection.ack":
            _ = decodePayload(ConnectionAckPayload.self, from: event.data)
            connectionState = .connected
        case "worker.status":
            if let payload = decodePayload(WorkerStatusPayload.self, from: event.data) {
                applyWorkerStatus(payload: payload)
            }
        case "engine.health":
            if let payload = decodePayload(EngineHealthPayload.self, from: event.data) {
                applyEngineHealth(payload: payload)
            }
        case "market.rank_snapshot":
            if let payload = decodePayload(MarketRankSnapshotPayload.self, from: event.data) {
                applyMarketRank(payload: payload)
            }
        case "market.tick":
            if let payload = decodePayload(MarketTickPayload.self, from: event.data) {
                latestTicks[payload.code] = payload
                ensureSelectedScannerCode()
            }
        case "signal.generated":
            if let payload = decodePayload(SignalGeneratedPayload.self, from: event.data) {
                appendSignal(payload: payload)
            }
        case "risk.blocked", "risk.approved":
            if let payload = decodePayload(RiskDecisionPayload.self, from: event.data) {
                appendRiskDecision(payload: payload)
            }
        case "order.created":
            if let payload = decodePayload(OrderCreatedPayload.self, from: event.data) {
                appendOrUpdateOrderCreated(payload: payload)
            }
        case "order.updated":
            if let payload = decodePayload(OrderUpdatedPayload.self, from: event.data) {
                appendOrUpdateOrderUpdated(payload: payload)
                scheduleRuntimeRefresh()
            }
        case "fill.received":
            if let payload = decodePayload(FillReceivedPayload.self, from: event.data) {
                appendFill(payload: payload)
                scheduleRuntimeRefresh()
            }
        case "position.updated":
            if let payload = decodePayload(PositionUpdatedPayload.self, from: event.data) {
                appendOrUpdatePosition(payload: payload)
                scheduleRuntimeRefresh()
            }
        case "position.pnl_updated":
            if let payload = decodePayload(PositionPnlUpdatedPayload.self, from: event.data) {
                applyPositionPnL(payload: payload)
                scheduleRuntimeRefresh()
            }
        case "position.closed":
            if let payload = decodePayload(PositionClosedPayload.self, from: event.data) {
                applyPositionClosed(payload: payload)
                scheduleRuntimeRefresh()
            }
        default:
            break
        }
    }

    private func applyWorkerStatus(payload: WorkerStatusPayload) {
        guard var runtime else { return }
        var workers = runtime.workers.workers
        var workerEntry = workers[payload.worker] ?? [:]
        workerEntry["status"] = .string(payload.status)
        if let message = payload.statusMessage {
            workerEntry["status_message"] = .string(message)
        }
        if let error = payload.error {
            workerEntry["error"] = .string(error)
        } else {
            workerEntry["error"] = .null
        }
        workers[payload.worker] = workerEntry
        runtime.workers.workers = workers
        self.runtime = runtime
    }

    private func applyEngineHealth(payload: EngineHealthPayload) {
        guard var runtime else { return }
        runtime.appStatus = payload.healthy ? "ready" : "degraded"
        if let orderMode = payload.details?["order_mode"]?.stringValue {
            runtime.orderMode = orderMode
            runtime.executionMode = orderMode
        }
        if let accountMode = payload.details?["account_mode"]?.stringValue {
            runtime.accountMode = accountMode
        }
        if let executionMode = payload.details?["execution_mode"]?.stringValue {
            runtime.executionMode = executionMode
        }
        if let engineState = payload.details?["engine_state"]?.stringValue {
            runtime.engineState = engineState
        }
        if let transition = payload.details?["engine_transitioning_action"]?.stringValue {
            runtime.engineTransitioningAction = transition
        }
        if let lastAction = payload.details?["engine_last_action"]?.stringValue {
            runtime.engineLastAction = lastAction
        }
        if let lastError = payload.details?["engine_last_error"]?.stringValue {
            runtime.engineLastError = lastError
        }
        if let message = payload.details?["engine_message"]?.stringValue {
            runtime.engineMessage = message
        }
        if let emergencyLatched = payload.details?["engine_emergency_latched"]?.boolValue {
            runtime.engineEmergencyLatched = emergencyLatched
        }
        if let actionValues = payload.details?["engine_available_actions"]?.arrayStringValues {
            runtime.engineAvailableActions = actionValues
        }
        if let updatedAtText = payload.details?["engine_updated_at"]?.stringValue {
            runtime.engineUpdatedAt = parseISODate(updatedAtText)
        }
        self.runtime = runtime
    }

    private func applyEngineControlSnapshot(_ snapshot: EngineControlSnapshot) {
        guard var runtime else { return }
        runtime.engineState = snapshot.state
        runtime.engineTransitioningAction = snapshot.transitioningAction
        runtime.engineLastAction = snapshot.lastAction
        runtime.engineLastError = snapshot.lastError
        runtime.engineMessage = snapshot.message
        runtime.engineEmergencyLatched = snapshot.emergencyLatched
        runtime.engineAvailableActions = snapshot.availableActions
        runtime.engineUpdatedAt = snapshot.updatedAt
        runtime.orderMode = snapshot.orderMode
        runtime.accountMode = snapshot.accountMode
        runtime.executionMode = snapshot.orderMode
        runtime.appStatus = snapshot.state == "emergency_stopped" ? "degraded" : runtime.appStatus
        self.runtime = runtime
    }

    private func applyMarketRank(payload: MarketRankSnapshotPayload) {
        let incoming = MarketRankSnapshotItem(
            code: payload.code,
            symbol: payload.symbol,
            rank: payload.rank,
            displayRank: nil,
            metric: payload.metric,
            price: payload.payload?["price"]?.doubleValue,
            changePct: payload.payload?["change_pct"]?.doubleValue,
            rankingMode: normalizeScannerMode(payload.rankingMode ?? "turnover"),
            source: payload.source,
            capturedAt: payload.timestamp
        )
        if let index = marketTopRanks.firstIndex(where: { $0.code == incoming.code }) {
            marketTopRanks[index] = incoming
        } else {
            marketTopRanks.insert(incoming, at: 0)
        }
        marketTopRanks = Array(marketTopRanks.prefix(maxRecentItems)).sorted { lhs, rhs in
            switch (lhs.rank, rhs.rank) {
            case let (l?, r?):
                return l < r
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.code < rhs.code
            }
        }
        // Scanner 리스트는 `/api/monitoring/scanner/ranks` 응답을 단일 truth source로 사용한다.
        // WS market.rank_snapshot(delta)로 scanner rows를 직접 갱신하면 limit 단계 로딩 순서가 깨질 수 있어
        // scannerRankRowsByMode는 여기서 갱신하지 않는다.
        ensureSelectedScannerCode()
    }

    private func appendSignal(payload: SignalGeneratedPayload) {
        let row = SignalSnapshotItem(
            signalId: nil,
            code: payload.code,
            symbol: payload.symbol,
            signalType: payload.signalType,
            confidence: payload.confidence,
            sourceSnapshotId: payload.sourceSnapshotId,
            previousSnapshotId: payload.previousSnapshotId,
            createdAt: payload.timestamp
        )
        recentSignals.insert(row, at: 0)
        recentSignals = Array(recentSignals.prefix(maxRecentItems))
    }

    private func appendRiskDecision(payload: RiskDecisionPayload) {
        let row = RiskDecisionSnapshotItem(
            riskEventId: nil,
            code: payload.code,
            symbol: payload.symbol,
            decision: payload.decision,
            blocked: payload.decision.lowercased() == "blocked",
            reason: payload.reason,
            signalId: payload.signalId,
            signalType: payload.signalType,
            relatedSignalReference: payload.relatedSignalReference,
            createdAt: payload.timestamp
        )
        recentRiskDecisions.insert(row, at: 0)
        recentRiskDecisions = Array(recentRiskDecisions.prefix(maxRecentItems))
    }

    private func appendOrUpdateOrderCreated(payload: OrderCreatedPayload) {
        let row = OrderSnapshotItem(
            orderId: payload.orderId,
            code: payload.code,
            symbol: payload.symbol,
            side: payload.side,
            orderQty: payload.qty,
            orderPrice: payload.orderPrice,
            status: payload.status,
            orderMode: runtime?.orderMode,
            executionMode: runtime?.executionMode ?? runtime?.orderMode,
            sourceSignalReference: payload.sourceSignalReference,
            brokerOrderId: nil,
            createdAt: payload.timestamp,
            updatedAt: payload.timestamp
        )
        upsertOrder(row)
    }

    private func appendOrUpdateOrderUpdated(payload: OrderUpdatedPayload) {
        if let index = recentOrders.firstIndex(where: { $0.orderId == payload.orderId }) {
            let previous = recentOrders[index]
            recentOrders[index] = OrderSnapshotItem(
                orderId: previous.orderId,
                code: payload.code,
                symbol: payload.symbol,
                side: payload.side,
                orderQty: payload.qty,
                orderPrice: payload.orderPrice,
                status: payload.status,
                orderMode: previous.orderMode ?? runtime?.orderMode,
                executionMode: previous.executionMode ?? runtime?.executionMode ?? runtime?.orderMode,
                sourceSignalReference: payload.sourceSignalReference,
                brokerOrderId: previous.brokerOrderId,
                createdAt: previous.createdAt,
                updatedAt: payload.timestamp
            )
        } else {
            let created = OrderSnapshotItem(
                orderId: payload.orderId,
                code: payload.code,
                symbol: payload.symbol,
                side: payload.side,
                orderQty: payload.qty,
                orderPrice: payload.orderPrice,
                status: payload.status,
                orderMode: runtime?.orderMode,
                executionMode: runtime?.executionMode ?? runtime?.orderMode,
                sourceSignalReference: payload.sourceSignalReference,
                brokerOrderId: nil,
                createdAt: payload.timestamp,
                updatedAt: payload.timestamp
            )
            upsertOrder(created)
        }
    }

    private func appendFill(payload: FillReceivedPayload) {
        guard let fillID = payload.fillId else { return }
        let row = FillSnapshotItem(
            fillId: fillID,
            orderId: payload.orderId,
            code: payload.code,
            symbol: payload.symbol,
            side: payload.side ?? "-",
            filledQty: payload.filledQty,
            filledPrice: payload.filledPrice,
            orderMode: runtime?.orderMode,
            executionMode: runtime?.executionMode ?? runtime?.orderMode,
            filledAt: payload.timestamp
        )
        if recentFills.contains(where: { $0.fillId == row.fillId }) {
            return
        }
        recentFills.insert(row, at: 0)
        recentFills = Array(recentFills.prefix(maxRecentItems))
    }

    private func appendOrUpdatePosition(payload: PositionUpdatedPayload) {
        if let index = currentPositions.firstIndex(where: { $0.code == payload.code }) {
            currentPositions[index].symbol = payload.symbol
            currentPositions[index].side = payload.side
            currentPositions[index].qty = payload.qty
            currentPositions[index].avgPrice = payload.avgPrice
            currentPositions[index].updatedAt = payload.timestamp
        } else {
            currentPositions.insert(
                PositionSnapshotItem(
                    positionId: nil,
                    code: payload.code,
                    symbol: payload.symbol,
                    side: payload.side,
                    qty: payload.qty,
                    avgPrice: payload.avgPrice,
                    markPrice: nil,
                    markPriceSource: nil,
                    unrealizedPnl: nil,
                    unrealizedPnlPct: nil,
                    updatedAt: payload.timestamp
                ),
                at: 0
            )
        }
        currentPositions = currentPositions.filter { $0.qty > 0 }
        recalculatePnLSummary()
    }

    private func applyPositionPnL(payload: PositionPnlUpdatedPayload) {
        if let index = currentPositions.firstIndex(where: { $0.code == payload.code }) {
            currentPositions[index].positionId = payload.positionId
            currentPositions[index].symbol = payload.symbol
            currentPositions[index].side = payload.side
            currentPositions[index].qty = payload.qty
            currentPositions[index].avgPrice = payload.avgPrice
            currentPositions[index].markPrice = payload.markPrice
            currentPositions[index].markPriceSource = payload.markPriceSource
            currentPositions[index].unrealizedPnl = payload.unrealizedPnl
            currentPositions[index].unrealizedPnlPct = payload.unrealizedPnlPct
            currentPositions[index].updatedAt = payload.timestamp
        } else {
            currentPositions.insert(
                PositionSnapshotItem(
                    positionId: payload.positionId,
                    code: payload.code,
                    symbol: payload.symbol,
                    side: payload.side,
                    qty: payload.qty,
                    avgPrice: payload.avgPrice,
                    markPrice: payload.markPrice,
                    markPriceSource: payload.markPriceSource,
                    unrealizedPnl: payload.unrealizedPnl,
                    unrealizedPnlPct: payload.unrealizedPnlPct,
                    updatedAt: payload.timestamp
                ),
                at: 0
            )
        }
        recalculatePnLSummary()
    }

    private func applyPositionClosed(payload: PositionClosedPayload) {
        currentPositions.removeAll { $0.positionId == payload.positionId || $0.code == payload.code }
        recentClosedPositions.insert(
            ClosedPositionSnapshotItem(
                eventId: nil,
                positionId: payload.positionId,
                code: payload.code,
                symbol: payload.symbol,
                closedQty: payload.closedQty,
                avgEntryPrice: payload.avgEntryPrice,
                exitPrice: payload.exitPrice,
                realizedPnl: payload.realizedPnl,
                realizedPnlPct: payload.realizedPnlPct,
                reason: payload.reason,
                orderMode: payload.orderMode,
                executionMode: payload.executionMode,
                createdAt: payload.timestamp
            ),
            at: 0
        )
        recentClosedPositions = Array(recentClosedPositions.prefix(maxRecentItems))
        recalculatePnLSummary()
    }

    private func upsertOrder(_ row: OrderSnapshotItem) {
        if let index = recentOrders.firstIndex(where: { $0.orderId == row.orderId }) {
            recentOrders[index] = row
        } else {
            recentOrders.insert(row, at: 0)
            recentOrders = Array(recentOrders.prefix(maxRecentItems))
        }
    }

    private func recalculatePnLSummary() {
        let openPositions = currentPositions.count
        let unrealizedTotal = currentPositions.compactMap(\.unrealizedPnl).reduce(0, +)
        let realizedTotal = recentClosedPositions.compactMap(\.realizedPnl).reduce(0, +)
        pnlSummary = PnLSummarySnapshot(
            openPositions: openPositions,
            unrealizedPnlTotal: openPositions > 0 ? unrealizedTotal : nil,
            realizedPnlRecentTotal: recentClosedPositions.isEmpty ? nil : realizedTotal,
            recentClosedCount: recentClosedPositions.count
        )
    }

    private func decodePayload<T: Decodable>(_ type: T.Type, from data: [String: JSONValue]) -> T? {
        let payload = data.mapValues(\.anyValue)
        guard JSONSerialization.isValidJSONObject(payload) else {
            return nil
        }
        do {
            let json = try JSONSerialization.data(withJSONObject: payload, options: [])
            return try MonitoringCoding.decoder().decode(type, from: json)
        } catch {
            lastErrorMessage = "Event decode failed (\(type)): \(error.localizedDescription)"
            return nil
        }
    }

    private func ensureSelectedScannerCode() {
        let rows = marketRows
        guard !rows.isEmpty else {
            selectedScannerCode = nil
            return
        }
        if let selectedScannerCode, rows.contains(where: { $0.code == selectedScannerCode }) {
            return
        }
        selectedScannerCode = rows.first?.code
        scheduleChartFetchForSelectedSymbol(force: false)
    }

    private func modeSwitchErrorMessage(prefix: String, error: Error) -> String {
        if let apiError = error as? MonitoringAPIError,
           case .httpStatus(_, let detail) = apiError,
           let detail,
           !detail.isEmpty {
            return detail
        }
        return "\(prefix): \(error.localizedDescription)"
    }

    private func updateAccountSummaryDiagnostics(from runtime: RuntimeStatusSnapshot?) {
        guard let summary = runtime?.accountSummary else {
            lastAccountSummaryErrorMessage = nil
            return
        }
        if let reason = summary.unavailableReason, !reason.isEmpty {
            lastAccountSummaryErrorMessage = reason
            return
        }
        lastAccountSummaryErrorMessage = nil
    }

    private func chartCacheKey(symbol: String, timeframe: ChartTimeframeOption) -> String {
        "\(symbol.uppercased())|\(timeframe.rawValue)"
    }

    private func scheduleChartFetchForSelectedSymbol(force: Bool) {
        guard let symbol = selectedScannerCode else { return }
        let timeframe = selectedChartTimeframe
        let key = chartCacheKey(symbol: symbol, timeframe: timeframe)
        chartFetchDebounceTask?.cancel()
        cancelStaleChartFetchTasks(except: key)

        chartFetchDebounceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if self.chartFetchDebounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: self.chartFetchDebounceNanoseconds)
            }
            guard !Task.isCancelled else { return }
            guard self.selectedScannerCode == symbol, self.selectedChartTimeframe == timeframe else { return }
            if self.chartFetchTasks[key] != nil {
                return
            }
            let task = Task { @MainActor [weak self] in
                guard let self else { return }
                await self.fetchChartSeries(symbol: symbol, timeframe: timeframe, force: force)
            }
            self.chartFetchTasks[key] = task
        }
    }

    private func fetchChartSeries(
        symbol: String,
        timeframe: ChartTimeframeOption,
        force: Bool
    ) async {
        let key = chartCacheKey(symbol: symbol, timeframe: timeframe)
        defer {
            chartFetchTasks[key] = nil
        }
        if !force, chartSeriesCache[key] != nil {
            return
        }

        chartLoadingKeys.insert(key)
        chartErrorMessages[key] = nil
        do {
            let response = try await apiClient.fetchChartSeries(symbol: symbol, timeframe: timeframe, limit: 240)
            if !Task.isCancelled {
                chartSeriesCache[key] = response
                chartErrorMessages[key] = nil
                lastUpdatedAt = Date()
            }
        } catch is CancellationError {
            chartErrorMessages[key] = nil
        } catch {
            let detail: String
            if let apiError = error as? MonitoringAPIError,
               case let .httpStatus(_, bodyDetail) = apiError,
               let bodyDetail,
               !bodyDetail.isEmpty {
                detail = bodyDetail
            } else {
                detail = error.localizedDescription
            }
            chartErrorMessages[key] = chartUserErrorMessage(from: detail)
        }
        chartLoadingKeys.remove(key)
    }

    private func cancelStaleChartFetchTasks(except keepKey: String) {
        let staleKeys = chartFetchTasks.keys.filter { $0 != keepKey }
        for staleKey in staleKeys {
            chartFetchTasks[staleKey]?.cancel()
            chartFetchTasks[staleKey] = nil
            chartLoadingKeys.remove(staleKey)
        }
    }

    private func chartUserErrorMessage(from detail: String) -> String {
        let normalized = detail.lowercased()
        if normalized.contains("chart token error") || normalized.contains("token fetch") || normalized.contains("oauth2/tokenp") {
            return "KIS 토큰 획득 실패: \(detail)"
        }
        return "차트 데이터 조회 실패: \(detail)"
    }

    private func parseISODate(_ raw: String) -> Date? {
        Self.iso8601WithFractional.date(from: raw) ?? Self.iso8601Basic.date(from: raw)
    }

    private func scheduleRuntimeRefresh() {
        guard runtimeRefreshTask == nil else { return }
        runtimeRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let self else { return }
            await self.refreshRuntimeStatusIfNeeded()
            self.runtimeRefreshTask = nil
        }
    }

    private func refreshRuntimeStatusIfNeeded() async {
        let now = Date()
        if let lastRuntimeRefreshedAt,
           now.timeIntervalSince(lastRuntimeRefreshedAt) < runtimeRefreshMinInterval {
            return
        }
        do {
            let latestRuntime = try await apiClient.fetchRuntime()
            runtime = latestRuntime
            lastRuntimeRefreshedAt = now
            lastUpdatedAt = now
        } catch {
            lastErrorMessage = diagnosticsErrorText(
                prefix: "Runtime refresh failed",
                error: error
            )
        }
    }

    private func scheduleSnapshotRetryIfNeeded() {
        guard started else { return }
        guard snapshotLoaded == false else { return }
        guard snapshotRetryTask == nil else { return }

        snapshotRetryTask = Task { @MainActor [weak self] in
            while let self, self.started, self.snapshotLoaded == false, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled, self.started, self.snapshotLoaded == false else {
                    break
                }
                await self.reloadSnapshot()
            }
            self?.snapshotRetryTask = nil
        }
    }
}

private func diagnosticsErrorText(prefix: String, error: Error) -> String {
    if let decodingError = error as? DecodingError {
        return "\(prefix): \(decodingErrorDescription(decodingError))"
    }
    return "\(prefix): \(error.localizedDescription)"
}

private func decodingErrorDescription(_ error: DecodingError) -> String {
    switch error {
    case .typeMismatch(let type, let context):
        return "typeMismatch(\(type)) at \(codingPath(context.codingPath)): \(context.debugDescription)"
    case .valueNotFound(let type, let context):
        return "valueNotFound(\(type)) at \(codingPath(context.codingPath)): \(context.debugDescription)"
    case .keyNotFound(let key, let context):
        return "keyNotFound(\(key.stringValue)) at \(codingPath(context.codingPath)): \(context.debugDescription)"
    case .dataCorrupted(let context):
        return "dataCorrupted at \(codingPath(context.codingPath)): \(context.debugDescription)"
    @unknown default:
        return "unknown decoding error"
    }
}

private func codingPath(_ path: [CodingKey]) -> String {
    if path.isEmpty {
        return "<root>"
    }
    return path.map(\.stringValue).joined(separator: ".")
}

enum EngineControlAction: Equatable {
    case start
    case pause
    case emergencyStop
    case clearEmergencyStop

    var apiAction: String {
        switch self {
        case .start:
            return "start"
        case .pause:
            return "pause"
        case .emergencyStop:
            return "emergency_stop"
        case .clearEmergencyStop:
            return "clear_emergency_stop"
        }
    }

    var label: String {
        switch self {
        case .start:
            return "시작"
        case .pause:
            return "일시정지"
        case .emergencyStop:
            return "긴급 정지"
        case .clearEmergencyStop:
            return "해제"
        }
    }
}

enum RuntimeModeSwitchTarget: Equatable {
    case orderMode
    case accountMode
}
