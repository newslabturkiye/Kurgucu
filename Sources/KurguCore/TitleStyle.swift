import Foundation

public struct TitleColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double
    public init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }
    public var isValid: Bool { [red, green, blue, alpha].allSatisfy { $0.isFinite && (0...1).contains($0) } }
}
public enum TitleFont: String, Codable, CaseIterable, Sendable { case system, serif, monospaced }
public enum TitleAlignment: String, Codable, CaseIterable, Sendable { case left, center, right }
public struct TitleStyle: Codable, Equatable, Sendable {
    public var font: TitleFont = .system
    public var bold: Bool = true
    public var alignment: TitleAlignment = .center
    public var foreground = TitleColor(1, 1, 1)
    public var background = TitleColor(0, 0, 0, 0.65)
    public var outline = TitleColor(0, 0, 0)
    /// Outline width as percent of the font size, as used by attributed text.
    public var outlineWidth: Double = 0
    public var shadow: Bool = false
    public init() {}
    public var isValid: Bool {
        foreground.isValid && background.isValid && outline.isValid && outlineWidth.isFinite && (0...8).contains(outlineWidth)
    }
}
