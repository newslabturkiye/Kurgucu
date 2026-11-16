import Foundation

public enum KurguError: Error, Equatable, Sendable {
    case invalidTime, overflow, invalidProject(String), missingClip, invalidEdit, unsupportedVersion(Int)
}

/// Exact rational seconds. No floating-point arithmetic in edit decisions.
public struct MediaTime: Hashable, Comparable, Codable, Sendable {
    public let value: Int64
    public let timescale: Int32
    public static let zero = try! MediaTime(0)

    public init(_ value: Int64, timescale: Int32 = 1) throws {
        guard timescale > 0, value != .min else { throw KurguError.invalidTime }
        let divisor = Self.gcd(abs(value), Int64(timescale))
        self.value = value / divisor
        self.timescale = Int32(Int64(timescale) / divisor)
    }

    private static func gcd(_ a: Int64, _ b: Int64) -> Int64 {
        var x = a, y = b
        while y != 0 { (x, y) = (y, x % y) }
        return x
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        let a = lhs.value.multipliedFullWidth(by: Int64(rhs.timescale))
        let b = rhs.value.multipliedFullWidth(by: Int64(lhs.timescale))
        return a.high == b.high ? a.low < b.low : a.high < b.high
    }

    public func adding(_ other: Self) throws -> Self {
        let divisor = Self.gcd(Int64(timescale), Int64(other.timescale))
        let leftMultiplier = Int64(other.timescale) / divisor
        let rightMultiplier = Int64(timescale) / divisor
        let scale = Int64(timescale) * leftMultiplier
        guard scale <= Int32.max else { throw KurguError.overflow }
        let a = value.multipliedReportingOverflow(by: leftMultiplier)
        let b = other.value.multipliedReportingOverflow(by: rightMultiplier)
        let sum = a.partialValue.addingReportingOverflow(b.partialValue)
        guard !a.overflow, !b.overflow, !sum.overflow else { throw KurguError.overflow }
        return try Self(sum.partialValue, timescale: Int32(scale))
    }

    public func subtracting(_ other: Self) throws -> Self {
        try adding(Self(-other.value, timescale: other.timescale))
    }

    private enum CodingKeys: String, CodingKey { case value, timescale }
    public init(from decoder: any Decoder) throws {
        let data = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(data.decode(Int64.self, forKey: .value), timescale: data.decode(Int32.self, forKey: .timescale))
    }
}
