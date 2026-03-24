//
//  JSONValue.swift
//  AutotradingMac
//

import Foundation

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSONValue content"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var anyValue: Any {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .object(let value):
            return value.mapValues(\.anyValue)
        case .array(let value):
            return value.map(\.anyValue)
        case .null:
            return NSNull()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    var doubleValue: Double? {
        if case .number(let value) = self {
            return value
        }
        if case .string(let value) = self {
            return Double(value)
        }
        return nil
    }

    var intValue: Int? {
        if let doubleValue {
            return Int(doubleValue)
        }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        if case .string(let value) = self {
            return Bool(value)
        }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self {
            return value
        }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let value) = self {
            return value
        }
        return nil
    }

    var arrayStringValues: [String]? {
        guard let arrayValue else { return nil }
        return arrayValue.compactMap(\.stringValue)
    }

    var displayText: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            if abs(value.rounded() - value) < 0.000001 {
                return String(Int(value.rounded()))
            }
            return String(format: "%.4f", value)
        case .bool(let value):
            return value ? "true" : "false"
        case .object(let value):
            return value
                .sorted(by: { $0.key < $1.key })
                .map { key, nestedValue in "\(key)=\(nestedValue.displayText)" }
                .joined(separator: ", ")
        case .array(let value):
            return value.map(\.displayText).joined(separator: ", ")
        case .null:
            return "null"
        }
    }
}
