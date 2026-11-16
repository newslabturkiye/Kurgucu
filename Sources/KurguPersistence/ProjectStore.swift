import Foundation
import KurguCore

/// Versioned package contains one authoritative project.json. Cache/media management follows later.
public actor ProjectStore {
    public init() {}

    public func save(_ project: Project, to packageURL: URL) throws {
        try project.validate()
        guard packageURL.isFileURL, packageURL.pathExtension == "nkurgu" else { throw KurguError.invalidProject("Expected .nkurgu file package") }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(project)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        try data.write(to: packageURL.appendingPathComponent("project.json"), options: .atomic)
    }

    public func load(from packageURL: URL) throws -> Project {
        guard packageURL.isFileURL, packageURL.pathExtension == "nkurgu" else { throw KurguError.invalidProject("Expected .nkurgu file package") }
        let data = try Data(contentsOf: packageURL.appendingPathComponent("project.json"))
        // Read version before decoding the evolving payload.
        struct Header: Decodable { let schemaVersion: Int }
        let decoder = JSONDecoder()
        let version = try decoder.decode(Header.self, from: data).schemaVersion
        guard (1...Project.currentVersion).contains(version) else { throw KurguError.unsupportedVersion(version) }
        var project = try decoder.decode(Project.self, from: data)
        if version < Project.currentVersion { project.schemaVersion = Project.currentVersion }
        try project.validate()
        return project
    }
}
