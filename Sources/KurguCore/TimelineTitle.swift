import Foundation

public struct TimelineTitle: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var text: String
    public var start: MediaTime
    public var duration: MediaTime
    public var fontSize: Double
    /// Bottom-origin position in canvas coordinates.
    public var style: TitleStyle?
    public var vertical: Double
    public init(id: UUID = UUID(), text: String, start: MediaTime = .zero, duration: MediaTime, fontSize: Double = 48, vertical: Double = 0.1, style: TitleStyle? = nil) {
        self.id = id; self.text = text; self.start = start; self.duration = duration; self.fontSize = fontSize; self.vertical = vertical; self.style = style
    }
}

public enum SubtitleFile {
    public static func parse(_ text: String) throws -> [TimelineTitle] {
        func time(_ value: String) throws -> MediaTime {
            let parts = value.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".").split(separator: ":")
            guard parts.count == 3, let h = Double(parts[0]), let m = Double(parts[1]), let s = Double(parts[2]), h >= 0, m >= 0, m < 60, s >= 0, s < 60, h < 1000 else { throw KurguError.invalidEdit }
            return try MediaTime(Int64(((h * 3600 + m * 60 + s) * 1000).rounded()), timescale: 1000)
        }
        let blocks = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n\n")
        return try blocks.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.map { block in
            let lines = block.components(separatedBy: "\n")
            guard let i = lines.firstIndex(where: { $0.contains("-->") }), i + 1 < lines.count else { throw KurguError.invalidEdit }
            let range = lines[i].components(separatedBy: "-->")
            guard range.count == 2 else { throw KurguError.invalidEdit }
            let start = try time(range[0]), end = try time(range[1])
            guard end > start else { throw KurguError.invalidEdit }
            let body = lines.dropFirst(i + 1).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { throw KurguError.invalidEdit }
            return TimelineTitle(text: body, start: start, duration: try end.subtracting(start))
        }
    }
    public static func encode(_ titles: [TimelineTitle]) -> String {
        func stamp(_ time: MediaTime) -> String {
            let ms = Int((Double(time.value) / Double(time.timescale) * 1000).rounded())
            return String(format: "%02d:%02d:%02d,%03d", ms / 3600000, ms / 60000 % 60, ms / 1000 % 60, ms % 1000)
        }
        return titles.sorted { $0.start < $1.start }.enumerated().map { index, title in
            "\(index + 1)\n\(stamp(title.start)) --> \(stamp((try? title.start.adding(title.duration)) ?? title.start))\n\(title.text)"
        }.joined(separator: "\n\n") + "\n"
    }
}
