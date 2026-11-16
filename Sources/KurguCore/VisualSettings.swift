import Foundation

public enum LookPreset: String, Codable, CaseIterable, Sendable { case original, monochrome, warm, cool, vivid, faded }
public struct VisualSettings: Codable, Equatable, Sendable {
    public var exposure: Double = 0
    public var contrast: Double = 1
    public var saturation: Double = 1
    public var temperature: Double = 0
    public var blur: Double = 0
    public var vignette: Double = 0
    public var look: LookPreset = .original
    public var intensity: Double = 1
    public var fadeIn: Double = 0
    public var fadeOut: Double = 0
    public init() {}
    public func isValid(duration: Double) -> Bool {
        [exposure, contrast, saturation, temperature, blur, vignette, intensity, fadeIn, fadeOut].allSatisfy(\.isFinite)
        && (-2...2).contains(exposure) && (0.5...2).contains(contrast) && (0...2).contains(saturation)
        && (-2000...2000).contains(temperature) && (0...30).contains(blur) && (0...2).contains(vignette)
        && (0...1).contains(intensity) && fadeIn >= 0 && fadeOut >= 0 && fadeIn + fadeOut <= duration
    }
}

public struct ImageOverlay: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    /// Normalized PNG embedded in the project: overlays do not depend on a temporary path.
    public var png: Data
    public var start: MediaTime
    public var duration: MediaTime
    public var x: Double = 0.5
    public var y: Double = 0.5
    public var width: Double = 0.25
    public var rotation: Double = 0
    public var opacity: Double = 1
    public init(id: UUID = UUID(), name: String, png: Data, start: MediaTime = .zero, duration: MediaTime) {
        self.id = id; self.name = name; self.png = png; self.start = start; self.duration = duration
    }
    public var isValid: Bool {
        !png.isEmpty && png.count <= 8_000_000 && png.starts(with: [137,80,78,71,13,10,26,10])
        && !name.isEmpty && start >= .zero && duration > .zero
        && [x,y,width,rotation,opacity].allSatisfy(\.isFinite)
        && (0...1).contains(x) && (0...1).contains(y) && (0.02...1).contains(width)
        && (-180...180).contains(rotation) && (0...1).contains(opacity)
    }
}
