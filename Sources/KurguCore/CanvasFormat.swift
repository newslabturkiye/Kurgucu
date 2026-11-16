import Foundation

public enum CanvasFit: String, Codable, CaseIterable, Sendable { case fit, fill }

public struct ClipFraming: Codable, Equatable, Sendable {
    public var rotation: Double?
    public var flipHorizontal: Bool?
    public var flipVertical: Bool?
    public var fit: CanvasFit?
    public var zoom: Double
    /// Fraction of the remaining margin/overflow, -1 leading edge, +1 trailing edge.
    public var horizontal: Double
    public var vertical: Double
    public init(fit: CanvasFit? = nil, zoom: Double = 1, horizontal: Double = 0, vertical: Double = 0) {
        self.fit = fit; self.zoom = zoom; self.horizontal = horizontal; self.vertical = vertical
    }
    public var isValid: Bool {
        (rotation ?? 0).isFinite && (-180...180).contains(rotation ?? 0) && zoom.isFinite && (1...4).contains(zoom) && horizontal.isFinite && (-1...1).contains(horizontal)
            && vertical.isFinite && (-1...1).contains(vertical)
    }
}

public enum CanvasPreset: String, CaseIterable, Identifiable, Sendable {
    case portrait, landscape, square, social, classic, portraitClassic, cinema
    public var id: String { rawValue }
    public var ratio: String {
        switch self { case .portrait: "9:16"; case .landscape: "16:9"; case .square: "1:1"
        case .social: "4:5"; case .classic: "4:3"; case .portraitClassic: "3:4"; case .cinema: "21:9" }
    }
    public var label: String {
        switch self { case .portrait: "Reels · Shorts"; case .landscape: "Yatay video"; case .square: "Kare"
        case .social: "Dikey gönderi"; case .classic: "Klasik"; case .portraitClassic: "Dikey klasik"; case .cinema: "Sinema" }
    }
    public var width: Int {
        switch self { case .portrait, .square, .social, .portraitClassic: 1080; case .landscape: 1920; case .classic: 1440; case .cinema: 2520 }
    }
    public var height: Int {
        switch self { case .portrait: 1920; case .social: 1350; case .portraitClassic: 1440; default: 1080 }
    }
    public static func ratioLabel(width: Int, height: Int) -> String {
        guard width > 0, height > 0 else { return "—" }
        if let preset = allCases.first(where: { Int64($0.width) * Int64(height) == Int64($0.height) * Int64(width) }) { return preset.ratio }
        var a = width, b = height
        while b != 0 { let remainder = a % b; a = b; b = remainder }
        return "\(width / a):\(height / a)"
    }
}
