//
//  ResultFeedReducer.swift
//  AutotradingMac
//

import Foundation

enum ResultFeedEventKind {
    case exit
    case close
    case fill
    case order
    case signal
    case risk
    case position
    case error
    case other
}

struct ResultFeedEventCandidate {
    let id: String
    let timestamp: Date
    let kind: ResultFeedEventKind
    let code: String?
    let side: String?
    let status: String?
    let orderId: Int?
    let sourceOrderId: Int?
    let sourceSignalReference: String?
}

enum ResultFeedReducer {
    static func visibleEventIDs(
        for candidates: [ResultFeedEventCandidate],
        fallbackWindowSeconds: TimeInterval = 90
    ) -> Set<String> {
        guard !candidates.isEmpty else { return [] }

        let orders = candidates.filter { $0.kind == .order }
        let fills = candidates.filter { $0.kind == .fill }
        let exits = candidates.filter { $0.kind == .exit }
        let closes = candidates.filter { $0.kind == .close }

        let ordersByOrderId = Dictionary(grouping: orders.compactMap { event -> (Int, ResultFeedEventCandidate)? in
            guard let orderId = event.orderId else { return nil }
            return (orderId, event)
        }, by: { $0.0 }).mapValues { $0.map(\.1) }

        let fillsByOrderId = Dictionary(grouping: fills.compactMap { event -> (Int, ResultFeedEventCandidate)? in
            guard let orderId = event.orderId else { return nil }
            return (orderId, event)
        }, by: { $0.0 }).mapValues { $0.map(\.1) }
        let ordersBySourceSignalReference = Dictionary(
            grouping: orders.compactMap { event -> (String, ResultFeedEventCandidate)? in
                guard let reference = normalizedReference(event.sourceSignalReference) else { return nil }
                return (reference, event)
            },
            by: { $0.0 }
        ).mapValues { $0.map(\.1) }

        var hidden: Set<String> = []

        // 0) 청산 결정 이벤트가 있으면 같은 흐름(order/fill)은 decision 이벤트로 흡수한다.
        for exit in exits.sorted(by: { $0.timestamp > $1.timestamp }) {
            if let reference = normalizedReference(exit.sourceSignalReference) {
                let relatedOrders = ordersBySourceSignalReference[reference] ?? []
                if !relatedOrders.isEmpty {
                    for order in relatedOrders {
                        hidden.insert(order.id)
                        if let orderId = order.orderId {
                            for fill in fillsByOrderId[orderId] ?? [] {
                                hidden.insert(fill.id)
                            }
                        }
                    }
                    continue
                }
            }

            guard let code = normalizeCode(exit.code) else { continue }
            let exitTime = exit.timestamp

            let relatedSellFills = fills.filter { fill in
                guard normalizeCode(fill.code) == code else { return false }
                guard normalize(fill.side) == "sell" else { return false }
                return isNearby(fill.timestamp, around: exitTime, windowSeconds: fallbackWindowSeconds)
            }
            for fill in relatedSellFills {
                hidden.insert(fill.id)
                if let orderId = fill.orderId {
                    for order in ordersByOrderId[orderId] ?? [] {
                        hidden.insert(order.id)
                    }
                }
            }

            let relatedSellOrders = orders.filter { order in
                guard normalizeCode(order.code) == code else { return false }
                guard normalize(order.side) == "sell" else { return false }
                return isNearby(order.timestamp, around: exitTime, windowSeconds: fallbackWindowSeconds)
            }
            for order in relatedSellOrders {
                hidden.insert(order.id)
            }
        }

        // 1) 청산 완료가 있으면 같은 흐름(order/fill)을 대표 이벤트(청산)로 흡수한다.
        for close in closes.sorted(by: { $0.timestamp > $1.timestamp }) {
            if let sourceOrderId = close.sourceOrderId {
                for fill in fillsByOrderId[sourceOrderId] ?? [] {
                    hidden.insert(fill.id)
                }
                for order in ordersByOrderId[sourceOrderId] ?? [] {
                    hidden.insert(order.id)
                }
                continue
            }

            guard let code = normalizeCode(close.code) else { continue }
            let closeTime = close.timestamp

            let relatedSellFills = fills.filter { fill in
                guard normalizeCode(fill.code) == code else { return false }
                guard normalize(fill.side) == "sell" else { return false }
                return isNearby(fill.timestamp, around: closeTime, windowSeconds: fallbackWindowSeconds)
            }

            if !relatedSellFills.isEmpty {
                for fill in relatedSellFills {
                    hidden.insert(fill.id)
                    if let orderId = fill.orderId {
                        for order in ordersByOrderId[orderId] ?? [] {
                            hidden.insert(order.id)
                        }
                    }
                }
                continue
            }

            let relatedSellOrders = orders.filter { order in
                guard normalizeCode(order.code) == code else { return false }
                guard normalize(order.side) == "sell" else { return false }
                return isNearby(order.timestamp, around: closeTime, windowSeconds: fallbackWindowSeconds)
            }
            for order in relatedSellOrders {
                hidden.insert(order.id)
            }
        }

        // 2) 청산이 없으면 fill을 대표로 선택하고 같은 주문 이벤트는 숨긴다.
        for fill in fills.sorted(by: { $0.timestamp > $1.timestamp }) where !hidden.contains(fill.id) {
            if let orderId = fill.orderId {
                for order in ordersByOrderId[orderId] ?? [] {
                    hidden.insert(order.id)
                }
                continue
            }

            guard let code = normalizeCode(fill.code) else { continue }
            let fillTime = fill.timestamp
            let relatedOrders = orders.filter { order in
                guard normalizeCode(order.code) == code else { return false }
                guard normalize(order.side) == normalize(fill.side) else { return false }
                return isNearby(order.timestamp, around: fillTime, windowSeconds: 45)
            }
            for order in relatedOrders {
                hidden.insert(order.id)
            }
        }

        let allIDs = Set(candidates.map(\.id))
        return allIDs.subtracting(hidden)
    }

    static func isActionableSignalType(_ raw: String) -> Bool {
        let normalized = raw.lowercased()
        if normalized.contains("watch") || normalized.contains("maintained") || normalized.contains("hold") || normalized.contains("wait") || normalized.contains("관망") {
            return false
        }
        if normalized.contains("new_entry") || normalized.contains("entry") || normalized.contains("jump") {
            return true
        }
        if normalized.contains("buy") || normalized.contains("sell") || normalized.contains("exit") {
            return true
        }
        return false
    }

    private static func isNearby(_ timestamp: Date, around target: Date, windowSeconds: TimeInterval) -> Bool {
        let delta = target.timeIntervalSince(timestamp)
        // 동일 흐름은 보통 close보다 앞에서 발생하므로 과거 window를 넉넉히 허용한다.
        return delta >= -5 && delta <= windowSeconds
    }

    private static func normalize(_ raw: String?) -> String {
        (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizeCode(_ raw: String?) -> String? {
        let value = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value != "-" else { return nil }
        return value.uppercased()
    }

    private static func normalizedReference(_ raw: String?) -> String? {
        let value = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value != "-" else { return nil }
        return value
    }
}
