import KurguCore

public struct SnapResult: Equatable, Sendable {
    public let start: MediaTime
    public let guide: MediaTime?
}

public enum Snapping {
    /// Match either moving edge to a target, preserving duration. Equal distances prefer
    /// the earlier target, then the leading edge. Negative starts are never produced.
    public static func move(start: MediaTime, duration: MediaTime, targets: [MediaTime], tolerance: MediaTime) throws -> SnapResult {
        guard start >= .zero, duration >= .zero, tolerance >= .zero else { throw KurguError.invalidEdit }
        var best = SnapResult(start: start, guide: nil)
        var distance: MediaTime?
        let end = try start.adding(duration)
        for target in Set(targets).sorted() {
            for edge in [start, end] {
                let delta = try target.subtracting(edge)
                let absolute = delta < .zero ? try MediaTime.zero.subtracting(delta) : delta
                let candidate = try start.adding(delta)
                guard candidate >= .zero, absolute <= tolerance, distance == nil || absolute < distance! else { continue }
                distance = absolute
                best = SnapResult(start: candidate, guide: target)
            }
        }
        return best
    }
}
