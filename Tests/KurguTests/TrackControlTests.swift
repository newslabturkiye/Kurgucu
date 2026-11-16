import Foundation
import Testing
import KurguCore
import KurguEditing
import KurguPersistence

@Test func trackControlsAndDuplicatePreserveHistory() throws {
    let asset = MediaAsset(name: "Source", kind: .video, fileURL: URL(fileURLWithPath: "/tmp/source.mov"), duration: try MediaTime(20))
    let clip = Clip(assetID: asset.id, start: try MediaTime(2), sourceStart: try MediaTime(4), duration: try MediaTime(3))
    let later = Clip(assetID: asset.id, start: try MediaTime(8), duration: try MediaTime(2))
    let track = Track(name: "Video", kind: .video, clips: [clip, later])
    let project = Project(name: "Controls", assets: [asset], sequences: [Sequence(tracks: [track])])
    var session = try EditorSession(project: project)
    try session.execute(.duplicate(clipID: clip.id))
    let copy = session.project.sequences[0].tracks[0].clips.last!
    #expect(copy.id != clip.id && copy.assetID == clip.assetID)
    #expect(copy.sourceStart == clip.sourceStart && copy.duration == clip.duration)
    #expect(copy.start == (try later.end()))
    session.undo(); #expect(session.project == project)
    session.redo(); #expect(session.project.sequences[0].tracks[0].clips.last == copy)
    try session.execute(.setTrackAudio(trackID: track.id, settings: TrackAudio(volume: 0.35, isMuted: true)))
    let mixed = session.project
    try session.execute(.setTrackLocked(trackID: track.id, locked: true))
    let locked = session.project
    for command in [EditCommand.duplicate(clipID: clip.id), .setTrackAudio(trackID: track.id, settings: TrackAudio()), .renameTrack(trackID: track.id, name: "Blocked")] {
        #expect(throws: KurguError.self) { try session.execute(command) }
        #expect(session.project == locked)
    }
    try session.execute(.setTrackLocked(trackID: track.id, locked: false))
    #expect(session.project == mixed)
    try session.execute(.renameTrack(trackID: track.id, name: "  Diyalog  "))
    #expect(session.project.sequences[0].tracks[0].name == "Diyalog")
    session.undo(); #expect(session.project == mixed)
    for value: Float in [-0.1, 2.1, .nan, .infinity] {
        #expect(throws: KurguError.self) { try session.execute(.setTrackAudio(trackID: track.id, settings: TrackAudio(volume: value))) }
        #expect(session.project == mixed)
    }
}

@Test func migratesLegacyProjectsAndPersistsAudio() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".nkurgu")
    defer { try? FileManager.default.removeItem(at: url) }
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    var original = Project(name: "Legacy", sequences: [Sequence(tracks: [Track(name: "V1", kind: .video)])])
    original.schemaVersion = 1
    let json = try JSONEncoder().encode(original)
    try json.write(to: url.appendingPathComponent("project.json"))
    let store = ProjectStore()
    var migrated = try await store.load(from: url)
    #expect(migrated.schemaVersion == Project.currentVersion)
    #expect(migrated.sequences[0].tracks[0].audioSettings == TrackAudio())
    #expect(try Data(contentsOf: url.appendingPathComponent("project.json")) == json) // Opening does not rewrite the user's file.
    migrated.sequences[0].tracks[0].audio = TrackAudio(volume: 0.65, isMuted: true)
    try await store.save(migrated, to: url)
    #expect(try await store.load(from: url) == migrated)
}
