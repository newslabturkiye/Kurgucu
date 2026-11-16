import SwiftUI
import AppKit

// Semantic colors resolve in both SwiftUI and the AppKit timeline.
enum Studio {
    static func adaptive(_ name: String, light: CGFloat, dark: CGFloat) -> NSColor {
        NSColor(name: NSColor.Name(name)) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(white: value, alpha: 1)
        }
    }
    static let canvasColor = adaptive("StudioCanvas", light: 0.965, dark: 0.085)
    static let background = Color(nsColor: canvasColor)
    static let panel = Color(nsColor: adaptive("StudioPanel", light: 0.99, dark: 0.105))
    static let raised = Color(nsColor: adaptive("StudioRaised", light: 0.935, dark: 0.145))
    static let ink = Color.primary
    static let accentColor = NSColor(name: NSColor.Name("StudioRed")) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.96, green: 0.32, blue: 0.38, alpha: 1)
            : NSColor(srgbRed: 0.85, green: 0.176, blue: 0.239, alpha: 1)
    }
    static let accent = Color(nsColor: accentColor)
    static let onAccent = Color(nsColor: adaptive("StudioOnRed", light: 1, dark: 0.055))
    static let border = Color.primary.opacity(0.12)
}

struct StudioButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 14).padding(.vertical, 9)
            .foregroundStyle(prominent ? Studio.onAccent : Studio.ink)
            .background(prominent ? Studio.accent : Studio.raised, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Studio.border))
            .opacity(!isEnabled ? 0.4 : configuration.isPressed ? 0.7 : 1)
    }
}

/// Original rounded monoline family, drawn at any display scale.
/// Detailed motifs are reserved for large empty states; tool icons stay simple.
enum StudioGlyph: String, CaseIterable { case media, audio, record, cut, add, export, inspector }
struct StudioIcon: View {
    var glyph: StudioGlyph
    var size: CGFloat = 24
    var body: some View {
        Canvas { context, dimensions in
            let scale = min(dimensions.width, dimensions.height) / 100
            context.scaleBy(x: scale, y: scale)
            let stroke = StrokeStyle(lineWidth: size < 32 ? 6 : 3.5, lineCap: .round, lineJoin: .round)
            func outline(_ path: Path) { context.stroke(path, with: .color(Studio.ink), style: stroke) }
            func line(_ points: [CGPoint]) {
                outline(Path { p in guard let first = points.first else { return }; p.move(to: first); for point in points.dropFirst() { p.addLine(to: point) } })
            }
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, accented: Bool = false, radius: CGFloat = 6) {
                let p = Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius)
                if accented { context.fill(p, with: .color(Studio.accent)) }; outline(p)
            }
            func circle(_ x: CGFloat, _ y: CGFloat, _ d: CGFloat, accented: Bool = false) {
                let p = Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d))
                if accented { context.fill(p, with: .color(Studio.accent)) }; outline(p)
            }
            func points(_ values: [(CGFloat, CGFloat)]) -> [CGPoint] { values.map { CGPoint(x: $0.0, y: $0.1) } }
            switch glyph {
            case .media:
                rect(10, 19, 80, 60)
                line(points([(10, 32), (90, 32)]))
                for x: CGFloat in [24, 44, 64, 82] { line(points([(x, 19), (x - 8, 32)])) }
                let triangle = Path { p in p.move(to: CGPoint(x: 42, y: 44)); p.addLine(to: CGPoint(x: 62, y: 56)); p.addLine(to: CGPoint(x: 42, y: 68)); p.closeSubpath() }
                context.fill(triangle, with: .color(Studio.accent)); outline(triangle)
            case .audio:
                outline(Path { p in p.move(to: CGPoint(x: 17, y: 60)); p.addCurve(to: CGPoint(x: 83, y: 60), control1: CGPoint(x: 8, y: -2), control2: CGPoint(x: 92, y: -2)) })
                rect(10, 49, 20, 35, accented: true, radius: 10)
                rect(70, 49, 20, 35, accented: true, radius: 10)
                if size >= 32 {
                    circle(36, 44, 28); circle(46, 54, 8, accented: true)
                    line(points([(80, 23), (80, 9), (94, 5), (94, 19)])); circle(72, 22, 8, accented: true); circle(86, 18, 8, accented: true)
                }
            case .record:
                rect(36, 12, 28, 48, accented: true, radius: 14)
                outline(Path { p in p.move(to: CGPoint(x: 24, y: 45)); p.addLine(to: CGPoint(x: 24, y: 50)); p.addCurve(to: CGPoint(x: 76, y: 50), control1: CGPoint(x: 24, y: 83), control2: CGPoint(x: 76, y: 83)); p.addLine(to: CGPoint(x: 76, y: 45)) })
                line(points([(50, 75), (50, 89)])); line(points([(32, 89), (68, 89)]))
                line(points([(37, 29), (46, 29)])); line(points([(54, 40), (63, 40)]))
            case .cut:
                circle(13, 63, 22, accented: true); circle(65, 63, 22, accented: true)
                line(points([(32, 66), (77, 15)])); line(points([(68, 66), (23, 15)])); circle(47, 45, 6)
            case .add:
                line(points([(65, 9), (20, 9), (20, 91), (82, 91), (82, 28), (65, 9), (65, 28), (82, 28)]))
                let cross = Path { p in p.addLines(points([(44, 42), (56, 42), (56, 55), (69, 55), (69, 67), (56, 67), (56, 80), (44, 80), (44, 67), (31, 67), (31, 55), (44, 55)])); p.closeSubpath() }
                context.fill(cross, with: .color(Studio.accent)); outline(cross)
            case .export:
                line(points([(17, 51), (17, 85), (83, 85), (83, 51)]))
                let arrow = Path { p in p.addLines(points([(42, 64), (42, 35), (27, 35), (50, 12), (73, 35), (58, 35), (58, 64)])); p.closeSubpath() }
                context.fill(arrow, with: .color(Studio.accent)); outline(arrow)
            case .inspector:
                for (x, y): (CGFloat, CGFloat) in [(24, 35), (50, 65), (76, 42)] {
                    line(points([(x, 15), (x, 85)])); circle(x - 8, y - 8, 16, accented: true)
                }
            }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct StudioLabel: View {
    let title: String
    let glyph: StudioGlyph
    var body: some View { HStack(spacing: 7) { StudioIcon(glyph: glyph, size: 20); Text(title) } }
}

struct WelcomeArtwork: View {
    let importAction: () -> Void
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 18) {
                Spacer(minLength: 12)
                StudioArtwork(name: "Scene-Landscape")
                    .frame(width: min(320, geometry.size.width * 0.7), height: min(180, geometry.size.height * 0.4))
                    .background(Color(red: 0.969, green: 0.969, blue: 0.949), in: RoundedRectangle(cornerRadius: 16))
                VStack(spacing: 9) {
                    Text("Hikâyene şekil ver.").font(.system(size: min(30, geometry.size.width / 16), weight: .semibold, design: .rounded)).tracking(-0.7)
                    Text("Görüntünü ekle. Ritmini bul. Kendi filmini yap.")
                        .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                Button(action: importAction) { StudioLabel(title: "Medya ekle", glyph: .add) }.buttonStyle(StudioButton(prominent: true))
                Spacer(minLength: 12)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 12)
                .background(Studio.background)
        }
    }
}
