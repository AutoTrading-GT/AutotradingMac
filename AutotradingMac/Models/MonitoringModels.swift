//
//  MonitoringModels.swift
//  AutotradingMac
//

import Foundation

struct MonitoringSnapshotResponse: Decodable {
    let runtime: RuntimeStatusSnapshot
    let marketTopRanks: [MarketRankSnapshotItem]
    let recentSignals: [SignalSnapshotItem]
    let recentStrategyEvents: [StrategyEventSnapshotItem]
    let recentExitEvents: [ExitEventSnapshotItem]
    let recentRiskDecisions: [RiskDecisionSnapshotItem]
    let recentOrders: [OrderSnapshotItem]
    let recentFills: [FillSnapshotItem]
    let currentPositions: [PositionSnapshotItem]
    let recentClosedPositions: [ClosedPositionSnapshotItem]
    let recentDailyPerformance: [DailyPerformanceSnapshotItem]
    let pnlSummary: PnLSummarySnapshot
    let limits: [String: Int]

    enum CodingKeys: String, CodingKey {
        case runtime
        case marketTopRanks
        case recentSignals
        case recentStrategyEvents
        case recentExitEvents
        case recentRiskDecisions
        case recentOrders
        case recentFills
        case currentPositions
        case recentClosedPositions
        case recentDailyPerformance
        case pnlSummary
        case limits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        runtime = (try? container.decode(RuntimeStatusSnapshot.self, forKey: .runtime))
            ?? RuntimeStatusSnapshot.fallback
        marketTopRanks = Self.decodeLossyArray(MarketRankSnapshotItem.self, from: container, forKey: .marketTopRanks)
        recentSignals = Self.decodeLossyArray(SignalSnapshotItem.self, from: container, forKey: .recentSignals)
        recentStrategyEvents = Self.decodeLossyArray(StrategyEventSnapshotItem.self, from: container, forKey: .recentStrategyEvents)
        recentExitEvents = Self.decodeLossyArray(ExitEventSnapshotItem.self, from: container, forKey: .recentExitEvents)
        recentRiskDecisions = Self.decodeLossyArray(RiskDecisionSnapshotItem.self, from: container, forKey: .recentRiskDecisions)
        recentOrders = Self.decodeLossyArray(OrderSnapshotItem.self, from: container, forKey: .recentOrders)
        recentFills = Self.decodeLossyArray(FillSnapshotItem.self, from: container, forKey: .recentFills)
        currentPositions = Self.decodeLossyArray(PositionSnapshotItem.self, from: container, forKey: .currentPositions)
        recentClosedPositions = Self.decodeLossyArray(ClosedPositionSnapshotItem.self, from: container, forKey: .recentClosedPositions)
        recentDailyPerformance = Self.decodeLossyArray(DailyPerformanceSnapshotItem.self, from: container, forKey: .recentDailyPerformance)
        pnlSummary = (try? container.decode(PnLSummarySnapshot.self, forKey: .pnlSummary))
            ?? PnLSummarySnapshot(openPositions: 0, unrealizedPnlTotal: nil, realizedPnlRecentTotal: nil, recentClosedCount: 0)
        limits = (try? container.decode([String: Int].self, forKey: .limits)) ?? [:]
    }

    private static func decodeLossyArray<T: Decodable>(
        _ type: T.Type,
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> [T] {
        guard let wrapped = try? container.decode([LossyDecodable<T>].self, forKey: key) else {
            return []
        }
        return wrapped.compactMap(\.value)
    }
}

struct RuntimeStatusSnapshot: Decodable {
    var timestamp: Date
    var appName: String
    var appVersion: String
    var env: String
    var appStatus: String
    var orderMode: String
    var accountMode: String
    var marketTradingActive: Bool?
    var marketClosedIdle: Bool?
    var strategyRunState: String?
    var riskRunState: String?
    var executionMode: String?
    var engineState: String?
    var engineAvailableActions: [String]?
    var engineTransitioningAction: String?
    var engineLastAction: String?
    var engineLastError: String?
    var engineMessage: String?
    var engineEmergencyLatched: Bool?
    var engineUpdatedAt: Date?
    var databaseStatus: String
    var databaseConnected: Bool
    var readinessStatus: String
    var startupOk: Bool
    var startupStatus: String
    var startupError: String?
    var activeWsClients: Int
    var todayPnlDate: String?
    var todayTotalPnl: Double?
    var todayTotalPnlAvailable: Bool?
    var accountSummary: AccountSummarySnapshot?
    var workers: WorkersSnapshot

    init(
        timestamp: Date,
        appName: String,
        appVersion: String,
        env: String,
        appStatus: String,
        orderMode: String,
        accountMode: String,
        marketTradingActive: Bool?,
        marketClosedIdle: Bool?,
        strategyRunState: String?,
        riskRunState: String?,
        executionMode: String?,
        engineState: String?,
        engineAvailableActions: [String]?,
        engineTransitioningAction: String?,
        engineLastAction: String?,
        engineLastError: String?,
        engineMessage: String?,
        engineEmergencyLatched: Bool?,
        engineUpdatedAt: Date?,
        databaseStatus: String,
        databaseConnected: Bool,
        readinessStatus: String,
        startupOk: Bool,
        startupStatus: String,
        startupError: String?,
        activeWsClients: Int,
        todayPnlDate: String?,
        todayTotalPnl: Double?,
        todayTotalPnlAvailable: Bool?,
        accountSummary: AccountSummarySnapshot?,
        workers: WorkersSnapshot
    ) {
        self.timestamp = timestamp
        self.appName = appName
        self.appVersion = appVersion
        self.env = env
        self.appStatus = appStatus
        self.orderMode = orderMode
        self.accountMode = accountMode
        self.marketTradingActive = marketTradingActive
        self.marketClosedIdle = marketClosedIdle
        self.strategyRunState = strategyRunState
        self.riskRunState = riskRunState
        self.executionMode = executionMode
        self.engineState = engineState
        self.engineAvailableActions = engineAvailableActions
        self.engineTransitioningAction = engineTransitioningAction
        self.engineLastAction = engineLastAction
        self.engineLastError = engineLastError
        self.engineMessage = engineMessage
        self.engineEmergencyLatched = engineEmergencyLatched
        self.engineUpdatedAt = engineUpdatedAt
        self.databaseStatus = databaseStatus
        self.databaseConnected = databaseConnected
        self.readinessStatus = readinessStatus
        self.startupOk = startupOk
        self.startupStatus = startupStatus
        self.startupError = startupError
        self.activeWsClients = activeWsClients
        self.todayPnlDate = todayPnlDate
        self.todayTotalPnl = todayTotalPnl
        self.todayTotalPnlAvailable = todayTotalPnlAvailable
        self.accountSummary = accountSummary
        self.workers = workers
    }

    static let fallback = RuntimeStatusSnapshot(
        timestamp: Date(),
        appName: "autotrading-core",
        appVersion: "-",
        env: "unknown",
        appStatus: "degraded",
        orderMode: "paper",
        accountMode: "paper",
        marketTradingActive: nil,
        marketClosedIdle: nil,
        strategyRunState: nil,
        riskRunState: nil,
        executionMode: "paper",
        engineState: nil,
        engineAvailableActions: [],
        engineTransitioningAction: nil,
        engineLastAction: nil,
        engineLastError: nil,
        engineMessage: nil,
        engineEmergencyLatched: nil,
        engineUpdatedAt: nil,
        databaseStatus: "unknown",
        databaseConnected: false,
        readinessStatus: "not_ready",
        startupOk: false,
        startupStatus: "unknown",
        startupError: nil,
        activeWsClients: 0,
        todayPnlDate: nil,
        todayTotalPnl: nil,
        todayTotalPnlAvailable: nil,
        accountSummary: nil,
        workers: WorkersSnapshot.fallback
    )

    enum CodingKeys: String, CodingKey {
        case timestamp
        case appName
        case appVersion
        case env
        case appStatus
        case orderMode
        case accountMode
        case marketTradingActive
        case marketClosedIdle
        case strategyRunState
        case riskRunState
        case executionMode
        case engineState
        case engineAvailableActions
        case engineTransitioningAction
        case engineLastAction
        case engineLastError
        case engineMessage
        case engineEmergencyLatched
        case engineUpdatedAt
        case databaseStatus
        case databaseConnected
        case readinessStatus
        case startupOk
        case startupStatus
        case startupError
        case activeWsClients
        case todayPnlDate
        case todayTotalPnl
        case todayTotalPnlAvailable
        case accountSummary
        case workers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = (try? container.decode(Date.self, forKey: .timestamp)) ?? Date()
        appName = container.decodeStringFlexible(forKey: .appName) ?? "autotrading-core"
        appVersion = container.decodeStringFlexible(forKey: .appVersion) ?? "-"
        env = container.decodeStringFlexible(forKey: .env) ?? "unknown"
        appStatus = container.decodeStringFlexible(forKey: .appStatus) ?? "degraded"
        executionMode = container.decodeStringFlexible(forKey: .executionMode)
        orderMode = container.decodeStringFlexible(forKey: .orderMode)
            ?? executionMode
            ?? "paper"
        accountMode = container.decodeStringFlexible(forKey: .accountMode)
            ?? "paper"
        marketTradingActive = container.decodeBoolFlexible(forKey: .marketTradingActive)
        marketClosedIdle = container.decodeBoolFlexible(forKey: .marketClosedIdle)
        strategyRunState = container.decodeStringFlexible(forKey: .strategyRunState)
        riskRunState = container.decodeStringFlexible(forKey: .riskRunState)
        engineState = container.decodeStringFlexible(forKey: .engineState)
        engineAvailableActions = try container.decodeIfPresent([String].self, forKey: .engineAvailableActions)
        engineTransitioningAction = container.decodeStringFlexible(forKey: .engineTransitioningAction)
        engineLastAction = container.decodeStringFlexible(forKey: .engineLastAction)
        engineLastError = container.decodeStringFlexible(forKey: .engineLastError)
        engineMessage = container.decodeStringFlexible(forKey: .engineMessage)
        engineEmergencyLatched = container.decodeBoolFlexible(forKey: .engineEmergencyLatched)
        engineUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .engineUpdatedAt)
        databaseStatus = container.decodeStringFlexible(forKey: .databaseStatus) ?? "unknown"
        databaseConnected = container.decodeBoolFlexible(forKey: .databaseConnected) ?? false
        readinessStatus = container.decodeStringFlexible(forKey: .readinessStatus) ?? "not_ready"
        startupOk = container.decodeBoolFlexible(forKey: .startupOk) ?? false
        startupStatus = container.decodeStringFlexible(forKey: .startupStatus) ?? "unknown"
        startupError = container.decodeStringFlexible(forKey: .startupError)
        activeWsClients = container.decodeIntFlexible(forKey: .activeWsClients) ?? 0
        todayPnlDate = container.decodeStringFlexible(forKey: .todayPnlDate)
        todayTotalPnl = container.decodeDoubleFlexible(forKey: .todayTotalPnl)
        todayTotalPnlAvailable = container.decodeBoolFlexible(forKey: .todayTotalPnlAvailable)
        accountSummary = try? container.decodeIfPresent(AccountSummarySnapshot.self, forKey: .accountSummary)
        workers = (try? container.decode(WorkersSnapshot.self, forKey: .workers)) ?? WorkersSnapshot.fallback
    }
}

struct AccountSummarySnapshot: Decodable {
    let mode: String
    let source: String
    let available: Bool
    let unavailableReason: String?
    let accountLabel: String?
    let accountNumber: String?
    let maskedAccount: String?
    let totalAccountValue: Double?
    let cashBalance: Double?
    let unrealizedPnlTotal: Double?
    let previousTotalAccountValue: Double?
    let dailyAssetChange: Double?

    enum CodingKeys: String, CodingKey {
        case mode
        case source
        case available
        case unavailableReason
        case accountLabel
        case accountNumber
        case maskedAccount
        case totalAccountValue
        case cashBalance
        case unrealizedPnlTotal
        case previousTotalAccountValue
        case dailyAssetChange
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = container.decodeStringFlexible(forKey: .mode) ?? "paper"
        source = container.decodeStringFlexible(forKey: .source) ?? "unknown"
        available = container.decodeBoolFlexible(forKey: .available) ?? false
        unavailableReason = container.decodeStringFlexible(forKey: .unavailableReason)
        accountLabel = container.decodeStringFlexible(forKey: .accountLabel)
        accountNumber = container.decodeStringFlexible(forKey: .accountNumber)
        maskedAccount = container.decodeStringFlexible(forKey: .maskedAccount)
        totalAccountValue = container.decodeDoubleFlexible(forKey: .totalAccountValue)
        cashBalance = container.decodeDoubleFlexible(forKey: .cashBalance)
        unrealizedPnlTotal = container.decodeDoubleFlexible(forKey: .unrealizedPnlTotal)
        previousTotalAccountValue = container.decodeDoubleFlexible(forKey: .previousTotalAccountValue)
        dailyAssetChange = container.decodeDoubleFlexible(forKey: .dailyAssetChange)
    }
}

struct RuntimeStatusResponseEnvelope: Decodable {
    let data: RuntimeStatusSnapshot
}

struct WorkerSummarySnapshot: Decodable {
    let count: Int
    let running: Int
    let error: Int
    let stopping: Int
    let starting: Int
    let stopped: Int
}

struct WorkersSnapshot: Decodable {
    var summary: WorkerSummarySnapshot
    var workers: [String: [String: JSONValue]]

    static let fallback = WorkersSnapshot(
        summary: WorkerSummarySnapshot(count: 0, running: 0, error: 0, stopping: 0, starting: 0, stopped: 0),
        workers: [:]
    )

    enum CodingKeys: String, CodingKey {
        case summary
        case workers
    }

    init(summary: WorkerSummarySnapshot, workers: [String: [String: JSONValue]]) {
        self.summary = summary
        self.workers = workers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = (try? container.decode(WorkerSummarySnapshot.self, forKey: .summary))
            ?? WorkersSnapshot.fallback.summary

        guard let rawWorkers = try? container.decode([String: JSONValue].self, forKey: .workers) else {
            workers = [:]
            return
        }
        var parsed: [String: [String: JSONValue]] = [:]
        for (name, value) in rawWorkers {
            if let object = value.objectValue {
                parsed[name] = object
            }
        }
        workers = parsed
    }
}

struct MarketRankSnapshotItem: Decodable, Identifiable {
    var id: String { code }
    let code: String
    let symbol: String?
    let rank: Int?
    let displayRank: Int?
    let metric: Double?
    let price: Double?
    let changePct: Double?
    let rankingMode: String?
    let source: String?
    let capturedAt: Date
}

struct ScannerRanksResponse: Decodable {
    let mode: String
    let limit: Int
    let hasMore: Bool
    let data: [MarketRankSnapshotItem]
    let count: Int
}

struct StrategySettingsResponseEnvelope: Decodable {
    let data: StrategySettingsSnapshot
    let defaults: StrategySettingsSnapshot
    let applyStatus: StrategyApplyStatusSnapshot?
    let applyPolicy: String
    let updatedAt: Date

    init(
        data: StrategySettingsSnapshot,
        defaults: StrategySettingsSnapshot,
        applyStatus: StrategyApplyStatusSnapshot? = nil,
        applyPolicy: String,
        updatedAt: Date
    ) {
        self.data = data
        self.defaults = defaults
        self.applyStatus = applyStatus
        self.applyPolicy = applyPolicy
        self.updatedAt = updatedAt
    }
}

struct AppSettingsResponseEnvelope: Decodable {
    let data: AppSettingsSnapshot
    let defaults: AppSettingsSnapshot
    let updatedAt: Date
}

struct AppSettingsUpdateResponseEnvelope: Decodable {
    let message: String
    let data: AppSettingsSnapshot
    let defaults: AppSettingsSnapshot
    let updatedAt: Date
}

struct AppSettingsSnapshot: Decodable, Equatable {
    var notifications: NotificationSettingsSnapshot
    var dataManagement: DataManagementSettingsSnapshot
}

struct NotificationSettingsSnapshot: Decodable, Equatable {
    var tradeFillNotificationsEnabled: Bool
    var tradeSignalNotificationsEnabled: Bool
    var systemErrorNotificationsEnabled: Bool
}

struct DataManagementSettingsSnapshot: Decodable, Equatable {
    var autoBackupEnabled: Bool
    var logRetentionDays: Int
    var backupRetentionCount: Int
    var storageUsageBytes: Int?
    var storageUsageLabel: String?
    var lastCleanupAt: Date?
    var lastCleanupStatus: String?
    var lastCleanupSummary: String?
    var lastBackupAt: Date?
    var lastBackupStatus: String?
    var lastBackupSummary: String?
    var backupMode: String?
}

struct StrategyApplyStatusSnapshot: Decodable {
    let savedVersion: Int
    let savedAt: Date
    let lastAppliedAt: Date?
    let groups: [String: StrategyApplyGroupStatusSnapshot]
}

struct StrategyApplyGroupStatusSnapshot: Decodable {
    let configuredValue: [String: JSONValue]
    let effectiveValue: [String: JSONValue]
    let effectiveFrom: Date?
    let appliedStatus: String
    let appliedVersion: Int?
    let targetVersion: Int
    let appliedBy: String?
    let wiredFields: [String]
    let notWiredFields: [String]
    let note: String?
}

struct StrategyConfigurableFieldSnapshot: Decodable, Equatable {
    let fieldId: String
    let label: String
    let inputType: String
    let group: String
    let description: String
    let options: [String]?
    let unit: String?
    let wired: Bool
}

struct StrategyTemplateSnapshot: Decodable, Equatable, Identifiable {
    var id: String { strategyId }

    let strategyId: String
    let displayName: String
    let shortDescription: String
    let category: String
    let status: String
    let wiredToEngine: Bool
    let selectable: Bool
    let implementationNote: String
    let configurableFields: [StrategyConfigurableFieldSnapshot]

    func resolvedStatus(activeStrategyId: String) -> String {
        if strategyId == activeStrategyId, selectable {
            return "active"
        }
        if selectable {
            return "available"
        }
        if wiredToEngine {
            return "not_wired"
        }
        return "preview_only"
    }

    static func normalizedCatalog(
        _ templates: [StrategyTemplateSnapshot],
        activeStrategyId: String
    ) -> [StrategyTemplateSnapshot] {
        let fallback = fallbackCatalog(activeStrategyId: activeStrategyId)
        let base: [StrategyTemplateSnapshot]
        if templates.isEmpty {
            base = fallback
        } else {
            var merged = templates
            for template in fallback where !merged.contains(where: { $0.strategyId == template.strategyId }) {
                merged.append(template)
            }
            base = merged
        }
        return base.map { template in
            StrategyTemplateSnapshot(
                strategyId: template.strategyId,
                displayName: template.displayName,
                shortDescription: template.shortDescription,
                category: template.category,
                status: template.resolvedStatus(activeStrategyId: activeStrategyId),
                wiredToEngine: template.wiredToEngine,
                selectable: template.selectable,
                implementationNote: template.implementationNote,
                configurableFields: template.configurableFields
            )
        }
    }

    static func fallbackCatalog(activeStrategyId: String) -> [StrategyTemplateSnapshot] {
        [
            StrategyTemplateSnapshot(
                strategyId: "turnover_surge_momentum",
                displayName: "Turnover / Surge Momentum",
                shortDescription: "거래대금/급등률 상위 후보에서 추세 지속과 순위 점프를 추종하는 현재 운용 전략입니다.",
                category: "momentum",
                status: activeStrategyId == "turnover_surge_momentum" ? "active" : "available",
                wiredToEngine: true,
                selectable: true,
                implementationNote: "현재 strategy/risk/execution worker에 실제 연결된 기본 전략입니다.",
                configurableFields: [
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "selection_mode",
                        label: "후보 선정 방식",
                        inputType: "enum",
                        group: "entry",
                        description: "거래대금 순위와 급등률 순위 중 어떤 후보군을 우선 감시할지 정합니다.",
                        options: ["turnover", "surge"],
                        unit: nil,
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "top_n",
                        label: "관찰 후보 수",
                        inputType: "int",
                        group: "entry",
                        description: "신호를 평가할 상위 후보 수입니다.",
                        options: nil,
                        unit: "symbols",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "enabled_signal_types",
                        label: "진입 신호 유형",
                        inputType: "multiselect",
                        group: "entry",
                        description: "활성 전략이 사용할 진입 신호 유형입니다.",
                        options: ["new_entry", "rank_jump", "rank_maintained"],
                        unit: nil,
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "target_profit_pct",
                        label: "익절 기준",
                        inputType: "float",
                        group: "exit",
                        description: "포지션 청산용 목표 수익률입니다.",
                        options: nil,
                        unit: "%",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "stop_loss_pct",
                        label: "손절 기준",
                        inputType: "float",
                        group: "exit",
                        description: "포지션 청산용 손절 기준입니다.",
                        options: nil,
                        unit: "%",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "max_holding_minutes",
                        label: "최대 보유 시간",
                        inputType: "int",
                        group: "exit",
                        description: "진입 후 강제 청산 전까지의 최대 보유 시간입니다.",
                        options: nil,
                        unit: "minutes",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "min_turnover",
                        label: "최소 거래대금 필터",
                        inputType: "float",
                        group: "scanner",
                        description: "스캐너 후보군을 좁히는 보조 필터입니다.",
                        options: nil,
                        unit: "KRW",
                        wired: false
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "min_change_pct",
                        label: "최소 등락률 필터",
                        inputType: "float",
                        group: "scanner",
                        description: "모멘텀 후보군의 최소 등락률 필터입니다.",
                        options: nil,
                        unit: "%",
                        wired: false
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "turnover_weights",
                        label: "거래대금 모드 가중치",
                        inputType: "weight_set",
                        group: "scanner",
                        description: "거래대금 모드 점수 비중을 조정합니다.",
                        options: nil,
                        unit: nil,
                        wired: false
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "surge_weights",
                        label: "급등률 모드 가중치",
                        inputType: "weight_set",
                        group: "scanner",
                        description: "급등률 모드 점수 비중을 조정합니다.",
                        options: nil,
                        unit: nil,
                        wired: false
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "rank_jump_threshold",
                        label: "순위 점프 임계값",
                        inputType: "int",
                        group: "signal",
                        description: "순위 급변을 진입 신호로 판정하는 임계값입니다.",
                        options: nil,
                        unit: "rank",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "rank_jump_window_seconds",
                        label: "순위 점프 시간창",
                        inputType: "int",
                        group: "signal",
                        description: "순위 점프를 계산하는 시간창입니다.",
                        options: nil,
                        unit: "seconds",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "rank_hold_tolerance",
                        label: "상위권 유지 허용 편차",
                        inputType: "int",
                        group: "signal",
                        description: "상위권 유지 신호 판정에 허용하는 순위 편차입니다.",
                        options: nil,
                        unit: "rank",
                        wired: true
                    ),
                ]
            ),
            StrategyTemplateSnapshot(
                strategyId: "opening_pullback_reentry",
                displayName: "Opening Pullback Re-entry",
                shortDescription: "개장 초 강한 유동성 모멘텀 종목의 눌림 후 재상승 구간만 추려 진입하는 전략입니다.",
                category: "opening_momentum",
                status: activeStrategyId == "opening_pullback_reentry" ? "active" : "available",
                wiredToEngine: true,
                selectable: true,
                implementationNote: "1차 버전은 rank 상위 후보 + 1분봉 + VWAP + 신규상장/단기과열/시장경보/최근 VI 필터 + 1호가 기준 스프레드/호가잔량 필터 + 부분익절/시간청산까지 엔진에 연결되어 있습니다. 2~10호가 깊이 기반 필터는 후속 TODO입니다.",
                configurableFields: [
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "selection_mode",
                        label: "후보 랭킹 기준",
                        inputType: "enum",
                        group: "candidate",
                        description: "거래대금 순위와 급등률 순위 중 어떤 랭킹을 후보 풀로 사용할지 정합니다.",
                        options: ["turnover", "surge"],
                        unit: nil,
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "top_n",
                        label: "후보 관찰 범위",
                        inputType: "int",
                        group: "candidate",
                        description: "개장 초 pullback 패턴을 감시할 rank 상위 종목 수입니다.",
                        options: nil,
                        unit: "symbols",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "observe_start_time",
                        label: "관찰 시작 시각",
                        inputType: "time",
                        group: "time",
                        description: "당일 1분봉 패턴을 읽기 시작할 시각입니다.",
                        options: nil,
                        unit: "KST",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "candidate_end_time",
                        label: "후보 종료 시각",
                        inputType: "time",
                        group: "time",
                        description: "opening impulse 후보를 인정하는 마지막 시각입니다.",
                        options: nil,
                        unit: "KST",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "entry_end_time",
                        label: "진입 종료 시각",
                        inputType: "time",
                        group: "time",
                        description: "re-entry 돌파 진입을 허용하는 마지막 시각입니다.",
                        options: nil,
                        unit: "KST",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "open_impulse_min_return_pct",
                        label: "opening impulse 최소 수익률",
                        inputType: "float",
                        group: "candidate",
                        description: "전일 종가 대비 개장 초 상승폭의 최소 기준입니다.",
                        options: nil,
                        unit: "%",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "pullback_retrace_min_pct",
                        label: "눌림 최소 되돌림",
                        inputType: "float",
                        group: "pullback",
                        description: "첫 상승폭 대비 눌림이 최소 어느 정도 나와야 하는지 정합니다.",
                        options: nil,
                        unit: "%",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "pullback_bars_max",
                        label: "눌림 최대 봉 수",
                        inputType: "int",
                        group: "pullback",
                        description: "패턴이 늘어지기 전에 진입 후보를 정리하기 위한 최대 1분봉 개수입니다.",
                        options: nil,
                        unit: "bars",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "reentry_volume_multiplier",
                        label: "재상승 거래량 배수",
                        inputType: "float",
                        group: "reentry",
                        description: "re-entry 봉의 거래량이 pullback 평균 대비 얼마나 커야 하는지 정합니다.",
                        options: nil,
                        unit: "x",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "use_vwap_filter",
                        label: "VWAP 필터 사용",
                        inputType: "bool",
                        group: "reentry",
                        description: "VWAP 위 유지/회복 여부를 진입 필터로 사용할지 정합니다.",
                        options: nil,
                        unit: nil,
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "exclude_recently_listed_enabled",
                        label: "신규상장 제외",
                        inputType: "bool",
                        group: "market_safety",
                        description: "일봉 이력 기준 상장 초기 종목을 후보에서 제외합니다.",
                        options: nil,
                        unit: nil,
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "exclude_recently_listed_days",
                        label: "신규상장 제외 일수",
                        inputType: "int",
                        group: "market_safety",
                        description: "최근 N거래일 이내 종목을 제외하는 기준입니다.",
                        options: nil,
                        unit: "days",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "exclude_short_term_overheated_enabled",
                        label: "단기과열 제외",
                        inputType: "bool",
                        group: "market_safety",
                        description: "KIS 현재가 payload의 단기과열 플래그가 켜진 종목을 제외합니다.",
                        options: nil,
                        unit: nil,
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "exclude_market_warning_enabled",
                        label: "시장경보 제외",
                        inputType: "bool",
                        group: "market_safety",
                        description: "투자주의/경고/위험 등 시장경보 종목을 제외합니다.",
                        options: nil,
                        unit: nil,
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "exclude_recent_vi_enabled",
                        label: "최근 VI 제외",
                        inputType: "bool",
                        group: "market_safety",
                        description: "최근 N분 내 VI 관련 플래그가 있던 종목을 제외합니다.",
                        options: nil,
                        unit: nil,
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "recent_vi_lookback_minutes",
                        label: "최근 VI 확인 시간",
                        inputType: "int",
                        group: "market_safety",
                        description: "VI 회피를 위해 되돌아볼 시간창입니다.",
                        options: nil,
                        unit: "minutes",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "use_spread_filter",
                        label: "스프레드 필터 사용",
                        inputType: "bool",
                        group: "execution_quality",
                        description: "최우선 매도/매수호가 스프레드가 넓은 종목을 진입 직전 제외합니다.",
                        options: nil,
                        unit: nil,
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "max_spread_pct",
                        label: "최대 스프레드",
                        inputType: "float",
                        group: "execution_quality",
                        description: "mid price 대비 허용 가능한 최대 스프레드 비율입니다.",
                        options: nil,
                        unit: "%",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "use_spread_tick_filter",
                        label: "tick 기준 스프레드 필터",
                        inputType: "bool",
                        group: "execution_quality",
                        description: "가격대별 호가 단위를 반영해 spread를 tick 수 기준으로도 hard reject합니다.",
                        options: nil,
                        unit: nil,
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "max_spread_ticks",
                        label: "최대 spread tick 수",
                        inputType: "int",
                        group: "execution_quality",
                        description: "허용 가능한 최우선 호가 spread의 최대 tick 수입니다.",
                        options: nil,
                        unit: "ticks",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "full_quality_spread_ticks",
                        label: "만점 spread tick 수",
                        inputType: "int",
                        group: "execution_quality",
                        description: "이 tick 수 이하의 spread는 quality score에서 만점으로 취급합니다.",
                        options: nil,
                        unit: "ticks",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "use_orderbook_value_depth_filter",
                        label: "호가금액 depth 필터 사용",
                        inputType: "bool",
                        group: "execution_quality",
                        description: "L1/L5 원화 기준 호가 depth와 주문금액 대비 depth 비율을 진입 필터에 사용합니다.",
                        options: nil,
                        unit: nil,
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "min_l1_bid_value_krw",
                        label: "최소 매수 L1 금액",
                        inputType: "float",
                        group: "execution_quality",
                        description: "매수 1호가 금액의 최소 KRW 기준입니다.",
                        options: nil,
                        unit: "KRW",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "min_l1_ask_value_krw",
                        label: "최소 매도 L1 금액",
                        inputType: "float",
                        group: "execution_quality",
                        description: "매도 1호가 금액의 최소 KRW 기준입니다.",
                        options: nil,
                        unit: "KRW",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "min_l5_bid_value_krw",
                        label: "최소 매수 L5 금액",
                        inputType: "float",
                        group: "execution_quality",
                        description: "매수 1~5호가 누적 금액의 최소 KRW 기준입니다.",
                        options: nil,
                        unit: "KRW",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "min_l5_ask_value_krw",
                        label: "최소 매도 L5 금액",
                        inputType: "float",
                        group: "execution_quality",
                        description: "매도 1~5호가 누적 금액의 최소 KRW 기준입니다.",
                        options: nil,
                        unit: "KRW",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "min_l1_depth_to_order_value_ratio",
                        label: "L1 / 주문금액 비율",
                        inputType: "float",
                        group: "execution_quality",
                        description: "예상 주문금액 대비 L1 양방향 depth 최소 배수입니다.",
                        options: nil,
                        unit: "x",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "min_l5_depth_to_order_value_ratio",
                        label: "L5 / 주문금액 비율",
                        inputType: "float",
                        group: "execution_quality",
                        description: "예상 주문금액 대비 L5 양방향 depth 최소 배수입니다.",
                        options: nil,
                        unit: "x",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "max_orderbook_imbalance_ratio",
                        label: "최대 호가 불균형",
                        inputType: "float",
                        group: "execution_quality",
                        description: "최우선 양방향 호가 잔량 비율이 이 값을 넘으면 진입을 막습니다.",
                        options: nil,
                        unit: "x",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "initial_stop_pct",
                        label: "초기 손절 비율",
                        inputType: "float",
                        group: "exit",
                        description: "진입가 대비 초기 손절 상한입니다.",
                        options: nil,
                        unit: "%",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "first_take_profit_r_multiple",
                        label: "1차 익절 R 배수",
                        inputType: "float",
                        group: "exit",
                        description: "초기 리스크(R) 대비 1차 부분익절 배수입니다.",
                        options: nil,
                        unit: "R",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "time_stop_hard_minutes",
                        label: "하드 시간청산",
                        inputType: "int",
                        group: "exit",
                        description: "잔여 포지션을 강제로 청산하는 최대 보유 시간입니다.",
                        options: nil,
                        unit: "minutes",
                        wired: true
                    ),
                ]
            ),
            StrategyTemplateSnapshot(
                strategyId: "turnover_persistence_breakout",
                displayName: "Turnover Persistence Breakout",
                shortDescription: "거래대금 상위권 지속성과 VWAP/박스 돌파를 함께 확인한 뒤 진입하는 추세 지속 전략입니다.",
                category: "persistence_breakout",
                status: activeStrategyId == "turnover_persistence_breakout" ? "active" : "available",
                wiredToEngine: true,
                selectable: true,
                implementationNote: "v2는 watchlist 편입 -> persistence/quality score breakdown -> VWAP/box breakout 확인 -> 진입 구조가 연결돼 있습니다. 다만 수치 최적화와 고급 execution 모델은 아직 아닙니다.",
                configurableFields: [
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "selection_mode",
                        label: "랭킹 기준",
                        inputType: "enum",
                        group: "watchlist",
                        description: "v1 기본은 거래대금이지만 랭킹 소스를 유지할 수 있습니다.",
                        options: ["turnover", "surge"],
                        unit: nil,
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "top_n_watch",
                        label: "Watchlist 관찰 범위",
                        inputType: "int",
                        group: "watchlist",
                        description: "watchlist 편입과 persistence 추적에 사용할 상위 범위입니다.",
                        options: nil,
                        unit: "symbols",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "top_n_trade",
                        label: "최종 진입 허용 순위",
                        inputType: "int",
                        group: "watchlist",
                        description: "최종 돌파 진입 시 허용할 rank 상한입니다.",
                        options: nil,
                        unit: "rank",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "persistence_lookback_minutes",
                        label: "Persistence 확인 시간",
                        inputType: "int",
                        group: "persistence",
                        description: "최근 몇 분의 랭킹 이력을 지속성 판단에 사용할지 정합니다.",
                        options: nil,
                        unit: "minutes",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "min_presence_ratio",
                        label: "최소 잔류 비율",
                        inputType: "float",
                        group: "persistence",
                        description: "lookback 구간에서 상위권에 남아 있어야 하는 최소 비율입니다.",
                        options: nil,
                        unit: "ratio",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "use_vwap_filter",
                        label: "VWAP 필터 사용",
                        inputType: "bool",
                        group: "breakout",
                        description: "VWAP 위 유지 또는 회복 여부를 최종 진입 전에 확인합니다.",
                        options: nil,
                        unit: nil,
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "box_bars_max",
                        label: "박스 최대 봉 수",
                        inputType: "int",
                        group: "breakout",
                        description: "박스 정의에 사용할 최대 1분봉 개수입니다.",
                        options: nil,
                        unit: "bars",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "breakout_volume_multiplier",
                        label: "돌파 거래량 배수",
                        inputType: "float",
                        group: "breakout",
                        description: "현재 1분봉 거래량이 최근 평균 대비 얼마나 커야 하는지 정합니다.",
                        options: nil,
                        unit: "x",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "target_profit_pct",
                        label: "익절 기준",
                        inputType: "float",
                        group: "exit",
                        description: "v1 기본 익절 비율입니다.",
                        options: nil,
                        unit: "%",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "stop_loss_pct",
                        label: "손절 상한",
                        inputType: "float",
                        group: "exit",
                        description: "box low가 멀어질 때 사용할 보수적 손절 상한입니다.",
                        options: nil,
                        unit: "%",
                        wired: true
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "max_holding_minutes",
                        label: "최대 보유 시간",
                        inputType: "int",
                        group: "exit",
                        description: "v1 hard time stop 기준입니다.",
                        options: nil,
                        unit: "minutes",
                        wired: true
                    ),
                ]
            ),
            StrategyTemplateSnapshot(
                strategyId: "intraday_breakout",
                displayName: "Intraday Breakout",
                shortDescription: "장중 박스 상단 돌파와 거래량 확인 후 진입하는 돌파형 전략 초안입니다.",
                category: "breakout",
                status: "preview_only",
                wiredToEngine: false,
                selectable: false,
                implementationNote: "현재는 템플릿 메타/설정 프리뷰만 제공하며 엔진에는 연결되어 있지 않습니다.",
                configurableFields: [
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "breakout_window_minutes",
                        label: "돌파 관찰 시간",
                        inputType: "int",
                        group: "entry",
                        description: "고점 돌파 여부를 관찰할 기준 시간입니다.",
                        options: nil,
                        unit: "minutes",
                        wired: false
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "breakout_threshold_pct",
                        label: "돌파 임계값",
                        inputType: "float",
                        group: "entry",
                        description: "기준 고점 대비 필요한 돌파 폭입니다.",
                        options: nil,
                        unit: "%",
                        wired: false
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "confirmation_volume_ratio",
                        label: "거래량 확인 배수",
                        inputType: "float",
                        group: "entry",
                        description: "돌파 확인에 필요한 거래량 배수입니다.",
                        options: nil,
                        unit: "x",
                        wired: false
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "pullback_tolerance_pct",
                        label: "리테스트 허용폭",
                        inputType: "float",
                        group: "entry",
                        description: "돌파 후 되돌림 허용 범위입니다.",
                        options: nil,
                        unit: "%",
                        wired: false
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "target_profit_pct",
                        label: "익절 기준",
                        inputType: "float",
                        group: "exit",
                        description: "돌파 전략용 익절 기준 초안입니다.",
                        options: nil,
                        unit: "%",
                        wired: false
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "stop_loss_pct",
                        label: "손절 기준",
                        inputType: "float",
                        group: "exit",
                        description: "돌파 전략용 손절 기준 초안입니다.",
                        options: nil,
                        unit: "%",
                        wired: false
                    ),
                    StrategyConfigurableFieldSnapshot(
                        fieldId: "max_holding_minutes",
                        label: "최대 보유 시간",
                        inputType: "int",
                        group: "exit",
                        description: "장중 돌파 전략용 최대 보유 시간 초안입니다.",
                        options: nil,
                        unit: "minutes",
                        wired: false
                    ),
                ]
            ),
        ]
    }
}

struct StrategySettingsSnapshot: Decodable, Equatable {
    var activeStrategyId: String
    var strategyTemplates: [StrategyTemplateSnapshot]
    var strategyParams: [String: [String: JSONValue]]
    var commonRiskParams: [String: JSONValue]
    var basic: BasicStrategySettingsSnapshot
    var advanced: AdvancedStrategySettingsSnapshot
    var scanner: ScannerSettingsSnapshot
    var signal: SignalSettingsSnapshot
    var risk: RiskSettingsSnapshot

    init(
        activeStrategyId: String = "turnover_surge_momentum",
        strategyTemplates: [StrategyTemplateSnapshot] = [],
        strategyParams: [String: [String: JSONValue]] = [:],
        commonRiskParams: [String: JSONValue] = [:],
        basic: BasicStrategySettingsSnapshot,
        advanced: AdvancedStrategySettingsSnapshot,
        scanner: ScannerSettingsSnapshot,
        signal: SignalSettingsSnapshot,
        risk: RiskSettingsSnapshot
    ) {
        self.activeStrategyId = activeStrategyId
        self.strategyTemplates = StrategyTemplateSnapshot.normalizedCatalog(
            strategyTemplates,
            activeStrategyId: activeStrategyId
        )
        self.strategyParams = strategyParams
        self.commonRiskParams = commonRiskParams
        self.basic = basic
        self.advanced = advanced
        self.scanner = scanner
        self.signal = signal
        self.risk = risk
    }

    init(
        scanner: ScannerSettingsSnapshot,
        signal: SignalSettingsSnapshot,
        risk: RiskSettingsSnapshot
    ) {
        let basic = BasicStrategySettingsSnapshot.derived(scanner: scanner, signal: signal, risk: risk)
        let advanced = AdvancedStrategySettingsSnapshot(scanner: scanner, signal: signal, risk: risk)
        self.init(
            activeStrategyId: "turnover_surge_momentum",
            strategyTemplates: StrategyTemplateSnapshot.fallbackCatalog(activeStrategyId: "turnover_surge_momentum"),
            strategyParams: StrategySettingsSnapshot.derivedStrategyParams(
                activeStrategyId: "turnover_surge_momentum",
                basic: basic,
                advanced: advanced
            ),
            commonRiskParams: StrategySettingsSnapshot.derivedCommonRiskParams(
                basic: basic,
                risk: risk
            ),
            basic: basic,
            advanced: advanced,
            scanner: scanner,
            signal: signal,
            risk: risk
        )
    }

    enum CodingKeys: String, CodingKey {
        case activeStrategyId
        case strategyTemplates
        case strategyParams
        case commonRiskParams
        case basic
        case advanced
        case scanner
        case signal
        case risk
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scanner = try container.decode(ScannerSettingsSnapshot.self, forKey: .scanner)
        signal = try container.decode(SignalSettingsSnapshot.self, forKey: .signal)
        risk = try container.decode(RiskSettingsSnapshot.self, forKey: .risk)
        basic = (try? container.decode(BasicStrategySettingsSnapshot.self, forKey: .basic))
            ?? .derived(scanner: scanner, signal: signal, risk: risk)
        advanced = (try? container.decode(AdvancedStrategySettingsSnapshot.self, forKey: .advanced))
            ?? AdvancedStrategySettingsSnapshot(scanner: scanner, signal: signal, risk: risk)
        activeStrategyId = container.decodeStringFlexible(forKey: .activeStrategyId)
            ?? "turnover_surge_momentum"
        strategyParams = (try? container.decode([String: [String: JSONValue]].self, forKey: .strategyParams))
            ?? StrategySettingsSnapshot.derivedStrategyParams(
                activeStrategyId: activeStrategyId,
                basic: basic,
                advanced: advanced
            )
        commonRiskParams = (try? container.decode([String: JSONValue].self, forKey: .commonRiskParams))
            ?? StrategySettingsSnapshot.derivedCommonRiskParams(
                basic: basic,
                risk: risk
            )
        strategyTemplates = StrategyTemplateSnapshot.normalizedCatalog(
            (try? container.decode([StrategyTemplateSnapshot].self, forKey: .strategyTemplates)) ?? [],
            activeStrategyId: activeStrategyId
        )
    }

    func template(id: String) -> StrategyTemplateSnapshot? {
        strategyTemplates.first { $0.strategyId == id }
    }

    var activeTemplate: StrategyTemplateSnapshot? {
        template(id: activeStrategyId)
    }

    private static func derivedStrategyParams(
        activeStrategyId: String,
        basic: BasicStrategySettingsSnapshot,
        advanced: AdvancedStrategySettingsSnapshot
    ) -> [String: [String: JSONValue]] {
        [
            "turnover_surge_momentum": [
                "selection_mode": .string(basic.entry.selectionMode),
                "top_n": .number(Double(basic.entry.topN)),
                "enabled_signal_types": .array(basic.entry.enabledSignalTypes.map(JSONValue.string)),
                "target_profit_pct": .number(basic.exit.targetProfitPct),
                "stop_loss_pct": .number(basic.exit.stopLossPct),
                "max_holding_minutes": .number(Double(basic.exit.maxHoldingMinutes)),
                "min_turnover": advanced.scanner.minTurnover.map(JSONValue.number) ?? .null,
                "min_change_pct": advanced.scanner.minChangePct.map(JSONValue.number) ?? .null,
                "turnover_weights": .object(
                    StrategySettingsSnapshot.weightObject(
                        advanced.scanner.scoreDefinition.weights["turnover"]
                            ?? ScannerScoreWeightsSnapshot(rank: 40, turnover: 45, changePct: 15)
                    )
                ),
                "surge_weights": .object(
                    StrategySettingsSnapshot.weightObject(
                        advanced.scanner.scoreDefinition.weights["surge"]
                            ?? ScannerScoreWeightsSnapshot(rank: 40, turnover: 15, changePct: 45)
                    )
                ),
                "rank_jump_threshold": .number(Double(advanced.signal.rankJumpThreshold)),
                "rank_jump_window_seconds": .number(Double(advanced.signal.rankJumpWindowSeconds)),
                "rank_hold_tolerance": .number(Double(advanced.signal.rankHoldTolerance)),
            ],
            "opening_pullback_reentry": [
                "selection_mode": .string("turnover"),
                "top_n": .number(8),
                "enabled_signal_types": .array([.string("opening_pullback_reentry")]),
                "observe_start_time": .string("09:00"),
                "candidate_start_time": .string("09:03"),
                "candidate_end_time": .string("09:20"),
                "entry_end_time": .string("09:50"),
                "open_impulse_min_return_pct": .number(2.0),
                "open_impulse_max_return_pct": .number(8.0),
                "pullback_retrace_min_pct": .number(25.0),
                "pullback_retrace_max_pct": .number(45.0),
                "pullback_bars_min": .number(2),
                "pullback_bars_max": .number(5),
                "reentry_volume_multiplier": .number(1.7),
                "use_vwap_filter": .bool(true),
                "require_vwap_reclaim": .bool(false),
                "exclude_recently_listed_enabled": .bool(true),
                "exclude_recently_listed_days": .number(5),
                "exclude_short_term_overheated_enabled": .bool(true),
                "exclude_market_warning_enabled": .bool(true),
                "exclude_recent_vi_enabled": .bool(true),
                "recent_vi_lookback_minutes": .number(15),
                "use_spread_filter": .bool(true),
                "max_spread_pct": .number(0.30),
                "use_orderbook_value_depth_filter": .bool(true),
                "min_l1_bid_value_krw": .number(15_000_000.0),
                "min_l1_ask_value_krw": .number(15_000_000.0),
                "min_l5_bid_value_krw": .number(80_000_000.0),
                "min_l5_ask_value_krw": .number(80_000_000.0),
                "min_l1_depth_to_order_value_ratio": .number(1.0),
                "min_l5_depth_to_order_value_ratio": .number(3.0),
                "max_orderbook_imbalance_ratio": .number(3.0),
                "use_risk_per_trade_sizing": .bool(true),
                "risk_per_trade_pct": .number(0.30),
                "max_position_size_pct_cap": .number(7.0),
                "sizing_slippage_buffer_pct": .number(0.20),
                "initial_stop_pct": .number(1.0),
                "first_take_profit_r_multiple": .number(1.5),
                "first_take_profit_partial_ratio": .number(0.5),
                "time_stop_soft_minutes": .number(15),
                "time_stop_hard_minutes": .number(30),
            ],
            "turnover_persistence_breakout": [
                "selection_mode": .string("turnover"),
                "top_n": .number(15),
                "top_n_watch": .number(15),
                "top_n_trade": .number(10),
                "enabled_signal_types": .array([.string("turnover_persistence_breakout")]),
                "candidate_start_time": .string("09:28"),
                "entry_end_time": .string("11:10"),
                "persistence_lookback_minutes": .number(10),
                "min_presence_ratio": .number(0.80),
                "rank_persistence_weight": .number(18.0),
                "turnover_persistence_weight": .number(22.0),
                "price_structure_weight": .number(18.0),
                "vwap_weight": .number(22.0),
                "quality_weight": .number(20.0),
                "min_score_to_trade": .number(78.0),
                "use_vwap_filter": .bool(true),
                "min_above_vwap_ratio": .number(0.80),
                "allow_reclaim": .bool(false),
                "box_bars_min": .number(4),
                "box_bars_max": .number(8),
                "max_box_retrace_pct": .number(2.2),
                "min_box_ready_ratio": .number(0.75),
                "breakout_volume_multiplier": .number(1.6),
                "use_spread_filter": .bool(true),
                "max_spread_pct": .number(0.25),
                "use_spread_tick_filter": .bool(true),
                "max_spread_ticks": .number(2),
                "full_quality_spread_ticks": .number(1),
                "use_orderbook_value_depth_filter": .bool(true),
                "min_l1_bid_value_krw": .number(15_000_000.0),
                "min_l1_ask_value_krw": .number(15_000_000.0),
                "min_l5_bid_value_krw": .number(80_000_000.0),
                "min_l5_ask_value_krw": .number(80_000_000.0),
                "min_l1_depth_to_order_value_ratio": .number(1.0),
                "min_l5_depth_to_order_value_ratio": .number(3.0),
                "max_orderbook_imbalance_ratio": .number(3.0),
                "target_profit_pct": .number(4.5),
                "stop_loss_pct": .number(2.2),
                "max_holding_minutes": .number(25),
                "use_trailing_exit": .bool(true),
                "trailing_exit_mode": .string("combined"),
                "vwap_trailing_enabled": .bool(true),
                "recent_low_trailing_enabled": .bool(true),
                "use_risk_per_trade_sizing": .bool(true),
                "risk_per_trade_pct": .number(0.20),
                "max_position_size_pct_cap": .number(5.0),
                "sizing_slippage_buffer_pct": .number(0.30),
            ],
            "intraday_breakout": [
                "breakout_window_minutes": .number(15),
                "breakout_threshold_pct": .number(2.2),
                "confirmation_volume_ratio": .number(1.8),
                "pullback_tolerance_pct": .number(0.8),
                "target_profit_pct": .number(2.7),
                "stop_loss_pct": .number(1.4),
                "max_holding_minutes": .number(45),
            ],
        ]
    }

    private static func derivedCommonRiskParams(
        basic: BasicStrategySettingsSnapshot,
        risk: RiskSettingsSnapshot
    ) -> [String: JSONValue] {
        let allowedSignalTypes: [String] = {
            var values = risk.allowedSignalTypes
            if !values.contains("opening_pullback_reentry") {
                values.append("opening_pullback_reentry")
            }
            if !values.contains("turnover_persistence_breakout") {
                values.append("turnover_persistence_breakout")
            }
            return values
        }()
        let allowedSignalTypeValues: [JSONValue] = allowedSignalTypes.map { .string($0) }
        let positionSizePct = JSONValue.number(basic.risk.positionSizePct)
        let maxLossLimitPct = JSONValue.number(basic.risk.maxLossLimitPct)
        let dailyTradeLimitEnabled = JSONValue.bool(basic.risk.dailyTradeLimitEnabled)
        let dailyTradeLimitCount = JSONValue.number(Double(basic.risk.dailyTradeLimitCount))
        let maxConcurrentPositions = JSONValue.number(Double(basic.risk.maxConcurrentPositions))
        let maxEntryAttemptsInWindow = JSONValue.number(Double(basic.risk.maxEntryAttemptsInWindow))
        let forceCloseOnMarketClose = JSONValue.bool(basic.exit.forceCloseOnMarketClose)
        let allowedSignalTypesValue = JSONValue.array(allowedSignalTypeValues)
        let cooldownMinutes = JSONValue.number(Double(risk.cooldownMinutes))
        let signalWindowMinutes = JSONValue.number(Double(risk.signalWindowMinutes))
        let entryAttemptWindowMinutes = JSONValue.number(Double(risk.entryAttemptWindowMinutes))
        let blockWhenPositionExists = JSONValue.bool(risk.blockWhenPositionExists)

        return [
            "position_size_pct": positionSizePct,
            "max_loss_limit_pct": maxLossLimitPct,
            "daily_trade_limit_enabled": dailyTradeLimitEnabled,
            "daily_trade_limit_count": dailyTradeLimitCount,
            "max_concurrent_positions": maxConcurrentPositions,
            "max_entry_attempts_in_window": maxEntryAttemptsInWindow,
            "force_close_on_market_close": forceCloseOnMarketClose,
            "allowed_signal_types": allowedSignalTypesValue,
            "cooldown_minutes": cooldownMinutes,
            "signal_window_minutes": signalWindowMinutes,
            "entry_attempt_window_minutes": entryAttemptWindowMinutes,
            "block_when_position_exists": blockWhenPositionExists,
        ]
    }

    private static func weightObject(_ snapshot: ScannerScoreWeightsSnapshot) -> [String: JSONValue] {
        [
            "rank": .number(snapshot.rank),
            "turnover": .number(snapshot.turnover),
            "change_pct": .number(snapshot.changePct),
        ]
    }
}

struct BasicStrategySettingsSnapshot: Decodable, Equatable {
    var entry: BasicEntrySettingsSnapshot
    var exit: BasicExitSettingsSnapshot
    var risk: BasicRiskSettingsSnapshot

    static func derived(
        scanner: ScannerSettingsSnapshot,
        signal: SignalSettingsSnapshot,
        risk: RiskSettingsSnapshot
    ) -> BasicStrategySettingsSnapshot {
        BasicStrategySettingsSnapshot(
            entry: BasicEntrySettingsSnapshot(
                selectionMode: scanner.defaultMode,
                topN: signal.topN,
                enabledSignalTypes: signal.enabledSignalTypes
            ),
            exit: BasicExitSettingsSnapshot(
                targetProfitPct: 3.0,
                stopLossPct: 2.0,
                maxHoldingMinutes: 60,
                forceCloseOnMarketClose: false
            ),
            risk: BasicRiskSettingsSnapshot(
                maxLossLimitPct: 5.0,
                positionSizePct: 10.0,
                dailyTradeLimitEnabled: true,
                dailyTradeLimitCount: 10,
                maxConcurrentPositions: risk.maxConcurrentPositions,
                maxEntryAttemptsInWindow: risk.maxEntryAttemptsInWindow,
                entryAttemptWindowMinutes: risk.entryAttemptWindowMinutes
            )
        )
    }
}

struct BasicEntrySettingsSnapshot: Decodable, Equatable {
    var selectionMode: String
    var topN: Int
    var enabledSignalTypes: [String]
}

struct BasicExitSettingsSnapshot: Decodable, Equatable {
    var targetProfitPct: Double
    var stopLossPct: Double
    var maxHoldingMinutes: Int
    var forceCloseOnMarketClose: Bool
}

struct BasicRiskSettingsSnapshot: Decodable, Equatable {
    var maxLossLimitPct: Double
    var positionSizePct: Double
    var dailyTradeLimitEnabled: Bool
    var dailyTradeLimitCount: Int
    var maxConcurrentPositions: Int
    var maxEntryAttemptsInWindow: Int
    var entryAttemptWindowMinutes: Int

    enum CodingKeys: String, CodingKey {
        case maxLossLimitPct
        case positionSizePct
        case dailyTradeLimitEnabled
        case dailyTradeLimitCount
        case maxConcurrentPositions
        case maxEntryAttemptsInWindow
        case entryAttemptWindowMinutes
        // Legacy compatibility keys.
        case positionSizeValue
        case dailyTradeLimit
    }

    init(
        maxLossLimitPct: Double,
        positionSizePct: Double,
        dailyTradeLimitEnabled: Bool,
        dailyTradeLimitCount: Int,
        maxConcurrentPositions: Int,
        maxEntryAttemptsInWindow: Int,
        entryAttemptWindowMinutes: Int
    ) {
        self.maxLossLimitPct = maxLossLimitPct
        self.positionSizePct = positionSizePct
        self.dailyTradeLimitEnabled = dailyTradeLimitEnabled
        self.dailyTradeLimitCount = dailyTradeLimitCount
        self.maxConcurrentPositions = maxConcurrentPositions
        self.maxEntryAttemptsInWindow = maxEntryAttemptsInWindow
        self.entryAttemptWindowMinutes = entryAttemptWindowMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        maxLossLimitPct = container.decodeDoubleFlexible(forKey: .maxLossLimitPct) ?? 5.0
        let legacyPositionSize = container.decodeDoubleFlexible(forKey: .positionSizeValue)
        let normalizedLegacyPositionSize: Double? = {
            guard let legacyPositionSize else { return nil }
            return (legacyPositionSize > 0 && legacyPositionSize <= 100) ? legacyPositionSize : nil
        }()
        positionSizePct = container.decodeDoubleFlexible(forKey: .positionSizePct)
            ?? normalizedLegacyPositionSize
            ?? 10.0

        if let enabled = container.decodeBoolFlexible(forKey: .dailyTradeLimitEnabled) {
            dailyTradeLimitEnabled = enabled
        } else if let legacyLimit = container.decodeIntFlexible(forKey: .dailyTradeLimit) {
            dailyTradeLimitEnabled = legacyLimit >= 0
        } else {
            dailyTradeLimitEnabled = true
        }

        dailyTradeLimitCount = container.decodeIntFlexible(forKey: .dailyTradeLimitCount)
            ?? {
                let legacy = container.decodeIntFlexible(forKey: .dailyTradeLimit) ?? 10
                return max(1, legacy)
            }()
        maxConcurrentPositions = container.decodeIntFlexible(forKey: .maxConcurrentPositions) ?? 3
        maxEntryAttemptsInWindow = container.decodeIntFlexible(forKey: .maxEntryAttemptsInWindow) ?? maxConcurrentPositions
        entryAttemptWindowMinutes = container.decodeIntFlexible(forKey: .entryAttemptWindowMinutes) ?? 15
    }
}

struct AdvancedStrategySettingsSnapshot: Decodable, Equatable {
    var scanner: ScannerSettingsSnapshot
    var signal: SignalSettingsSnapshot
    var risk: RiskSettingsSnapshot
}

struct ScannerSettingsSnapshot: Decodable, Equatable {
    var modes: [String]
    var defaultMode: String
    var topN: Int
    var pageStep: Int
    var maxLimit: Int
    var candidateLimit: Int
    var rankingSource: String
    var minTurnover: Double?
    var minChangePct: Double?
    var scoreDefinition: ScannerScoreDefinitionSnapshot
}

struct ScannerScoreDefinitionSnapshot: Decodable, Equatable {
    var name: String
    var summary: String
    var formulaBasis: String
    var weights: [String: ScannerScoreWeightsSnapshot]
    var notes: [String]
}

struct ScannerScoreWeightsSnapshot: Decodable, Equatable {
    var rank: Double
    var turnover: Double
    var changePct: Double
}

struct SignalSettingsSnapshot: Decodable, Equatable {
    var topN: Int
    var rankJumpThreshold: Int
    var rankJumpWindowSeconds: Int
    var rankHoldTolerance: Int
    var enabledSignalTypes: [String]
}

struct RiskSettingsSnapshot: Decodable, Equatable {
    var allowedSignalTypes: [String]
    var maxConcurrentPositions: Int
    var maxEntryAttemptsInWindow: Int
    var cooldownMinutes: Int
    var signalWindowMinutes: Int
    var entryAttemptWindowMinutes: Int
    var blockWhenPositionExists: Bool

    var maxConcurrentCandidates: Int { maxEntryAttemptsInWindow }
    var concurrencyWindowMinutes: Int { entryAttemptWindowMinutes }
}

extension Dictionary where Key == String, Value == JSONValue {
    func stringValue(for key: String) -> String? {
        self[key]?.stringValue
    }

    func doubleValue(for key: String) -> Double? {
        self[key]?.doubleValue
    }

    func intValue(for key: String) -> Int? {
        self[key]?.intValue
    }

    func boolValue(for key: String) -> Bool? {
        self[key]?.boolValue
    }

    func arrayStringValues(for key: String) -> [String]? {
        self[key]?.arrayStringValues
    }

    func objectValue(for key: String) -> [String: JSONValue]? {
        self[key]?.objectValue
    }
}

struct StrategySettingsUpdatePayload: Encodable {
    let activeStrategyId: String?
    let strategyParams: [String: [String: JSONValue]]?
    let commonRiskParams: [String: JSONValue]?
    let basic: BasicStrategySettingsUpdatePayload?
    let advanced: AdvancedStrategySettingsUpdatePayload?
    let scanner: ScannerSettingsUpdatePayload?
    let signal: SignalSettingsUpdatePayload?
    let risk: RiskSettingsUpdatePayload?

    init(
        activeStrategyId: String? = nil,
        strategyParams: [String: [String: JSONValue]]? = nil,
        commonRiskParams: [String: JSONValue]? = nil,
        basic: BasicStrategySettingsUpdatePayload?,
        advanced: AdvancedStrategySettingsUpdatePayload?,
        scanner: ScannerSettingsUpdatePayload?,
        signal: SignalSettingsUpdatePayload?,
        risk: RiskSettingsUpdatePayload?
    ) {
        self.activeStrategyId = activeStrategyId
        self.strategyParams = strategyParams
        self.commonRiskParams = commonRiskParams
        self.basic = basic
        self.advanced = advanced
        self.scanner = scanner
        self.signal = signal
        self.risk = risk
    }
}

struct AppSettingsUpdatePayload: Encodable {
    let notifications: NotificationSettingsUpdatePayload?
    let dataManagement: DataManagementSettingsUpdatePayload?
}

struct NotificationSettingsUpdatePayload: Encodable {
    let tradeFillNotificationsEnabled: Bool?
    let tradeSignalNotificationsEnabled: Bool?
    let systemErrorNotificationsEnabled: Bool?
}

struct DataManagementSettingsUpdatePayload: Encodable {
    let autoBackupEnabled: Bool?
    let logRetentionDays: Int?
}

struct BasicStrategySettingsUpdatePayload: Encodable {
    let entry: BasicEntrySettingsUpdatePayload?
    let exit: BasicExitSettingsUpdatePayload?
    let risk: BasicRiskSettingsUpdatePayload?
}

struct BasicEntrySettingsUpdatePayload: Encodable {
    let selectionMode: String?
    let topN: Int?
    let enabledSignalTypes: [String]?
}

struct BasicExitSettingsUpdatePayload: Encodable {
    let targetProfitPct: Double?
    let stopLossPct: Double?
    let maxHoldingMinutes: Int?
    let forceCloseOnMarketClose: Bool?
}

struct BasicRiskSettingsUpdatePayload: Encodable {
    let maxLossLimitPct: Double?
    let positionSizePct: Double?
    let dailyTradeLimitEnabled: Bool?
    let dailyTradeLimitCount: Int?
    let maxConcurrentPositions: Int?
    let maxEntryAttemptsInWindow: Int?
    let entryAttemptWindowMinutes: Int?
}

struct AdvancedStrategySettingsUpdatePayload: Encodable {
    let scanner: ScannerSettingsUpdatePayload?
    let signal: SignalSettingsUpdatePayload?
    let risk: RiskSettingsUpdatePayload?
}

struct ScannerSettingsUpdatePayload: Encodable {
    let defaultMode: String?
    let topN: Int?
    let minTurnover: Double?
    let minChangePct: Double?
    let weights: ScannerWeightsUpdatePayload?
}

struct ScannerWeightsUpdatePayload: Encodable {
    let turnover: ScannerScoreWeightsUpdatePayload?
    let surge: ScannerScoreWeightsUpdatePayload?
}

struct ScannerScoreWeightsUpdatePayload: Encodable {
    let rank: Double?
    let turnover: Double?
    let changePct: Double?
}

struct SignalSettingsUpdatePayload: Encodable {
    let topN: Int?
    let rankJumpThreshold: Int?
    let rankJumpWindowSeconds: Int?
    let rankHoldTolerance: Int?
    let enabledSignalTypes: [String]?
}

struct RiskSettingsUpdatePayload: Encodable {
    let allowedSignalTypes: [String]?
    let maxConcurrentPositions: Int?
    let maxEntryAttemptsInWindow: Int?
    let cooldownMinutes: Int?
    let signalWindowMinutes: Int?
    let entryAttemptWindowMinutes: Int?
    let blockWhenPositionExists: Bool?
}

struct SignalSnapshotItem: Decodable, Identifiable {
    var id: String { "signal-\(signalId?.description ?? "none")-\(code)-\(createdAt.timeIntervalSince1970)" }
    let signalId: Int?
    let code: String
    let symbol: String?
    let signalType: String
    let strategyId: String?
    let strategyDisplayName: String?
    let summary: String?
    let confidence: Double?
    let selectionMode: String?
    let rankCurrent: Int?
    let rankPrevious: Int?
    let payload: [String: JSONValue]?
    let orderMode: String?
    let executionMode: String?
    let sourceSnapshotId: Int?
    let previousSnapshotId: Int?
    let createdAt: Date
}

struct StrategyEventSnapshotItem: Decodable, Identifiable {
    var id: String {
        "strategy-event-\(eventId)-\(code ?? "unknown")-\(createdAt.timeIntervalSince1970)"
    }

    let eventId: Int
    let eventType: String
    let code: String?
    let symbol: String?
    let strategyId: String?
    let strategyDisplayName: String?
    let signalType: String?
    let stage: String?
    let reason: String?
    let reasonCode: String?
    let summary: String?
    let selectionMode: String?
    let rankCurrent: Int?
    let sourceSnapshotId: Int?
    let candidateMetric: Double?
    let details: [String: JSONValue]?
    let orderMode: String?
    let executionMode: String?
    let createdAt: Date
}

struct ExitEventSnapshotItem: Decodable, Identifiable {
    var id: String {
        let eventToken = eventId?.description ?? "none"
        let positionToken = positionId?.description ?? "none"
        let reasonToken = reasonCode ?? reason ?? "unknown"
        return "exit-\(eventToken)-\(positionToken)-\(reasonToken)-\(createdAt.timeIntervalSince1970)"
    }

    let eventId: Int?
    let eventType: String?
    let positionId: Int?
    let code: String?
    let symbol: String?
    let signalType: String?
    let sourceSignalType: String?
    let reason: String?
    let reasonCode: String?
    let summary: String?
    let strategyId: String?
    let strategyDisplayName: String?
    let partial: Bool?
    let partialRatio: Double?
    let qty: Double?
    let currentPositionQty: Double?
    let expectedRemainingQty: Double?
    let markPrice: Double?
    let unrealizedPnl: Double?
    let unrealizedPnlPct: Double?
    let holdingSeconds: Double?
    let sourcePositionReference: String?
    let sourceSignalReference: String?
    let triggeredAt: Date?
    let orderMode: String?
    let executionMode: String?
    let createdAt: Date
}

struct RiskDecisionSnapshotItem: Decodable, Identifiable {
    var id: String {
        "risk-\(riskEventId?.description ?? "none")-\(code ?? "unknown")-\(createdAt.timeIntervalSince1970)"
    }

    let riskEventId: Int?
    let code: String?
    let symbol: String?
    let decision: String
    let blocked: Bool?
    let reason: String
    let reasonCode: String?
    let summary: String?
    let strategyId: String?
    let strategyDisplayName: String?
    let context: [String: JSONValue]?
    let orderMode: String?
    let executionMode: String?
    let signalId: Int?
    let signalType: String?
    let relatedSignalReference: String?
    let createdAt: Date
}

struct OrderSnapshotItem: Decodable, Identifiable {
    var id: Int { orderId }
    let orderId: Int
    let code: String
    let symbol: String?
    let side: String
    let orderQty: Double
    let orderPrice: Double?
    let status: String
    let executionReason: String?
    let signalType: String?
    let strategyId: String?
    let strategyDisplayName: String?
    let orderMode: String?
    let executionMode: String?
    let sourceSignalReference: String?
    let brokerOrderId: String?
    let createdAt: Date
    let updatedAt: Date
}

struct FillSnapshotItem: Decodable, Identifiable {
    var id: Int { fillId }
    let fillId: Int
    let orderId: Int
    let code: String
    let symbol: String?
    let side: String
    let filledQty: Double
    let filledPrice: Double
    let orderMode: String?
    let executionMode: String?
    let filledAt: Date
}

struct PositionSnapshotItem: Decodable, Identifiable {
    var id: String { "position-\(positionId?.description ?? "none")-\(code)" }
    var positionId: Int?
    var code: String
    var symbol: String?
    var side: String
    var qty: Double
    var avgPrice: Double?
    var markPrice: Double?
    var markPriceSource: String?
    var unrealizedPnl: Double?
    var unrealizedPnlPct: Double?
    var updatedAt: Date
}

struct ClosedPositionSnapshotItem: Decodable, Identifiable {
    var id: String {
        "closed-\(eventId?.description ?? "none")-\(positionId?.description ?? "none")-\(createdAt.timeIntervalSince1970)"
    }

    let eventId: Int?
    let positionId: Int?
    let code: String?
    let symbol: String?
    let closedQty: Double?
    let avgEntryPrice: Double?
    let exitPrice: Double?
    let realizedPnl: Double?
    let realizedPnlPct: Double?
    let reason: String?
    let reasonCode: String?
    let summary: String?
    let signalType: String?
    let strategyId: String?
    let strategyDisplayName: String?
    let sourceOrderId: Int?
    let sourceSignalReference: String?
    let holdingSeconds: Double?
    let orderMode: String?
    let executionMode: String?
    let createdAt: Date
}

struct PnLSummarySnapshot: Decodable {
    var openPositions: Int
    var unrealizedPnlTotal: Double?
    var realizedPnlRecentTotal: Double?
    var recentClosedCount: Int
}

struct DailyPerformanceSnapshotItem: Decodable, Identifiable {
    let date: String
    let pnl: Double?
    let winRate: Double?
    let tradeCount: Int
    let wins: Int
    let losses: Int

    var id: String { date }
}

struct RuntimeMetricCard: Identifiable {
    let id: String
    let title: String
    let value: String
    let tone: StatusTone
}

struct WorkerStatusRow: Identifiable {
    let id: String
    let worker: String
    let status: String
    let error: String?
    let statusMessage: String?
    let rankSource: String?
    let tickSource: String?
    let syncStatus: String?
}

struct MarketRow: Identifiable {
    let id: String
    let code: String
    let symbol: String
    let rank: Int?
    let rankingMode: String?
    let price: Double?
    let changePct: Double?
    let metric: Double?
    let source: String?
    let updatedAt: Date?
}

struct EngineControlSnapshot: Decodable {
    let state: String
    let orderMode: String
    let accountMode: String
    let orderModeLiveAllowed: Bool
    let transitioningAction: String?
    let lastAction: String?
    let lastError: String?
    let message: String?
    let emergencyLatched: Bool
    let availableActions: [String]
    let updatedAt: Date
}

struct EngineControlCommandResponse: Decodable {
    let ok: Bool
    let action: String
    let message: String
    let engine: EngineControlSnapshot
}

struct EngineModeCommandResponse: Decodable {
    let ok: Bool
    let target: String
    let mode: String
    let message: String
    let engine: EngineControlSnapshot
}

private struct LossyDecodable<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

private extension KeyedDecodingContainer {
    func decodeStringFlexible(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return String(value)
        }
        return nil
    }

    func decodeDoubleFlexible(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value.replacingOccurrences(of: ",", with: ""))
        }
        return nil
    }

    func decodeIntFlexible(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            if let intValue = Int(value) {
                return intValue
            }
            if let doubleValue = Double(value) {
                return Int(doubleValue)
            }
        }
        return nil
    }

    func decodeBoolFlexible(forKey key: Key) -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value != 0
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes", "y":
                return true
            case "false", "0", "no", "n":
                return false
            default:
                return nil
            }
        }
        return nil
    }
}
