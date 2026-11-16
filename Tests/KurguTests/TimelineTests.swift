import Foundation
import Testing
import KurguCore
import KurguEditing
import KurguPersistence

private func time(_ value: Int64, _ scale: Int32 = 1) throws -> MediaTime { try MediaTime(value, timescale: scale) }
private func fixture() throws -> (Project, Clip) {
    let asset = MediaAsset(name: "Sample", kind: .video, fileURL: URL(fileURLWithPath: "/tmp/sample.mov"), duration: try time(60))
    let clip = Clip(assetID: asset.id, start: try time(2), sourceStart: try time(10), duration: try time(8))
    let project = Project(name: "Test", assets: [asset], sequences: [Sequence(tracks: [Track(name: "V1", kind: .video, clips: [clip])])])
    return (project, clip)
}

@Test func rationalArithmetic() throws {
    #expect(try time(2, 4) == time(1, 2))
    let frame = try time(1001, 30000)
    var accumulated = MediaTime.zero
    for _ in 0..<30000 { accumulated = try accumulated.adding(frame) }
    #expect(try accumulated == time(1001))
    #expect(try time(1, 48000).adding(time(1, 44100)) == time(307, 7056000))
    #expect(try time(-1, 2) < .zero)
    #expect(throws: KurguError.self) { try time(1, 0) }
    #expect(throws: KurguError.self) { try time(.max).adding(time(1)) }
}

@Test func rejectsInvalidSerializedTime() throws {
    let invalid = Data(#"{"value":1,"timescale":0}"#.utf8)
    #expect(throws: KurguError.self) { try JSONDecoder().decode(MediaTime.self, from: invalid) }
}

@Test func splitPreservesSourceAndUndoRedo() throws {
    let (project, clip) = try fixture()
    var session = try EditorSession(project: project)
    try session.execute(.split(clipID: clip.id, at: time(5)))
    let pieces = session.project.sequences[0].tracks[0].clips
    #expect(pieces.count == 2)
    #expect(pieces[0].id == clip.id)
    #expect(try pieces[0].duration == time(3))
    #expect(try pieces[1].sourceStart == time(13))
    #expect(try pieces[1].duration == time(5))
    #expect(try pieces[1].end() == clip.end())
    let split = session.project
    session.undo(); #expect(session.project == project)
    session.redo(); #expect(session.project == split)
}

@Test func failedEditIsAtomic() throws {
    let (project, clip) = try fixture()
    var session = try EditorSession(project: project)
    #expect(throws: KurguError.self) { try session.execute(.split(clipID: clip.id, at: clip.start)) }
    #expect(session.project == project)
    #expect(!session.canUndo)
    #expect(throws: KurguError.self) { try session.execute(.trim(clipID: clip.id, start: time(1), end: time(5))) }
    #expect(session.project == project)
}

@Test func trimAndHistoryBranch() throws {
    let (project, clip) = try fixture()
    var session = try EditorSession(project: project)
    try session.execute(.trim(clipID: clip.id, start: time(4), end: time(9)))
    let result = session.project.sequences[0].tracks[0].clips[0]
    #expect(try result.sourceStart == time(12))
    #expect(try result.duration == time(5))
    session.undo()
    try session.execute(.split(clipID: clip.id, at: time(6)))
    #expect(!session.canRedo)
}

@Test func validatesBoundsDuplicatesOverlapAndLocks() throws {
    let (project, clip) = try fixture()
    var invalid = project
    invalid.assets.append(project.assets[0])
    #expect(throws: KurguError.self) { try invalid.validate() }
    invalid = project
    invalid.sequences[0].tracks[0].clips[0].sourceStart = try time(59)
    #expect(throws: KurguError.self) { try invalid.validate() }
    var session = try EditorSession(project: project)
    let overlapping = Clip(assetID: clip.assetID, start: try time(3), duration: try time(2))
    #expect(throws: KurguError.self) {
        try session.execute(.insert(sequenceID: project.sequences[0].id, trackID: project.sequences[0].tracks[0].id, clip: overlapping))
    }
    #expect(session.project == project)
    invalid = project
    invalid.sequences[0].tracks[0].isLocked = true
    session = try EditorSession(project: invalid)
    #expect(throws: KurguError.self) { try session.execute(.split(clipID: clip.id, at: time(5))) }
}

@Test func persistenceRoundTripAndVersionGate() async throws {
    let (project, _) = try fixture()
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("Test.nkurgu")
    let store = ProjectStore()
    try await store.save(project, to: url)
    #expect(try await store.load(from: url) == project)
    var updated = project; updated.name = "Updated"
    try await store.save(updated, to: url)
    #expect(try await store.load(from: url) == updated)
    try Data(#"{"schemaVersion":999}"#.utf8).write(to: url.appendingPathComponent("project.json"))
    await #expect(throws: KurguError.unsupportedVersion(999)) { try await store.load(from: url) }
}

@Test func mediaAndTrackCommandsAreUndoable() throws {
    let (project, _) = try fixture()
    var session = try EditorSession(project: project)
    let asset = MediaAsset(name: "Audio", kind: .audio, fileURL: URL(fileURLWithPath: "/tmp/audio.wav"), duration: try time(3))
    try session.execute(.addAsset(asset))
    let track = Track(name: "A1", kind: .audio)
    try session.execute(.addTrack(sequenceID: project.sequences[0].id, track: track))
    #expect(session.project.assets.count == 2)
    #expect(session.project.sequences[0].tracks.count == 2)
    session.undo()
    #expect(session.project.sequences[0].tracks.count == 1)
    session.undo()
    #expect(session.project == project)
    session.redo(); session.redo()
    #expect(session.project.sequences[0].tracks[1].id == track.id)
    let before = session.project
    #expect(throws: KurguError.self) { try session.execute(.addAsset(asset)) }
    #expect(session.project == before)
}

@Test func removingClipPreservesMediaAndCanBeUndone() throws {
    let (project, clip) = try fixture()
    var session = try EditorSession(project: project)
    try session.execute(.remove(clipID: clip.id))
    #expect(session.project.sequences[0].tracks[0].clips.isEmpty)
    #expect(session.project.assets == project.assets)
    session.undo()
    #expect(session.project == project)
}
