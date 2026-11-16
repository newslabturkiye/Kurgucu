import Foundation
import KurguCore

public struct RecoveryEntry: Identifiable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public let name: String
    public let date: Date
}

public actor RecoveryStore {
    private let root: URL
    private var lastStamp: Int64 = 0
    public init(root: URL) { self.root = root }
    public func checkpoint(_ project: Project) throws {
        try project.validate()
        let directory = root.appendingPathComponent(project.id.uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        lastStamp = max(lastStamp + 1, Int64(Date().timeIntervalSince1970 * 1000))
        let name = String(lastStamp) + "-" + UUID().uuidString + ".json"
        try JSONEncoder().encode(project).write(to: directory.appendingPathComponent(name), options: .atomic)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        for url in files.dropFirst(20) { try FileManager.default.removeItem(at: url) }
    }
    public func entries() -> [RecoveryEntry] {
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }
        var result: [RecoveryEntry] = []
        for case let url as URL in walker where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url), let project = try? JSONDecoder().decode(Project.self, from: data), (try? project.validate()) != nil else { continue }
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            result.append(RecoveryEntry(url: url, name: project.name, date: date))
        }
        return result.sorted { $0.date > $1.date }
    }
    public func restore(_ entry: RecoveryEntry) throws -> Project {
        let project = try JSONDecoder().decode(Project.self, from: Data(contentsOf: entry.url))
        try project.validate(); return project
    }
}
