import Foundation

/// Lightweight type-erased Codable for capability params/results. Mirrors HermesBridge.JSONValue
/// but lives here to avoid forcing every capability to import HermesBridge.
public struct AnyCodable: Codable, Sendable, Equatable {
    public let value: Value

    public enum Value: Sendable, Equatable {
        case null
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case array([AnyCodable])
        case object([String: AnyCodable])
    }

    public init(_ value: Value) { self.value = value }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self.value = .null; return }
        if let v = try? c.decode(Bool.self)              { self.value = .bool(v); return }
        if let v = try? c.decode(Int.self)               { self.value = .int(v); return }
        if let v = try? c.decode(Double.self)            { self.value = .double(v); return }
        if let v = try? c.decode(String.self)            { self.value = .string(v); return }
        if let v = try? c.decode([AnyCodable].self)      { self.value = .array(v); return }
        if let v = try? c.decode([String: AnyCodable].self) { self.value = .object(v); return }
        throw DecodingError.typeMismatch(AnyCodable.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Not a JSON value"))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case .null:          try c.encodeNil()
        case .bool(let v):   try c.encode(v)
        case .int(let v):    try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v):  try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }

    public var stringValue: String? { if case .string(let s) = value { return s } else { return nil } }
    public var intValue: Int?       { if case .int(let i) = value { return i } else { return nil } }
    public var boolValue: Bool?     { if case .bool(let b) = value { return b } else { return nil } }
    public var objectValue: [String: AnyCodable]? { if case .object(let o) = value { return o } else { return nil } }
    public var arrayValue: [AnyCodable]? { if case .array(let a) = value { return a } else { return nil } }

    public static let null = AnyCodable(.null)
    public static func string(_ s: String) -> AnyCodable { AnyCodable(.string(s)) }
    public static func int(_ i: Int) -> AnyCodable { AnyCodable(.int(i)) }
    public static func double(_ d: Double) -> AnyCodable { AnyCodable(.double(d)) }
    public static func bool(_ b: Bool) -> AnyCodable { AnyCodable(.bool(b)) }
    public static func object(_ o: [String: AnyCodable]) -> AnyCodable { AnyCodable(.object(o)) }
    public static func array(_ a: [AnyCodable]) -> AnyCodable { AnyCodable(.array(a)) }
}
