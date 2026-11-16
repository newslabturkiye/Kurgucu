import Foundation
import Testing
import KurguCore
import KurguEditing

private func t(_ v: Int64, _ scale: Int32 = 1) throws -> MediaTime { try MediaTime(v, timescale: scale) }
private func fixture() throws -> (Project, Clip, Clip) {
    let asset = MediaAsset(name: "Film", kind: .video, fileURL: URL(fileURLWithPath: "/tmp/film.mov"), duration: try t(30))
    let first = Clip(assetID: asset.id, start: try t(1), sourceStart: try t(4), duration: try t(3))
    let later = Clip(assetID: asset.id, start: try t(6), sourceStart: try t(10), duration: try t(2))
    let overlay = Clip(assetID: asset.id, start: try t(8), duration: try t(2))
    let sequence = Sequence(tracks: [Track(name: "V1", kind: .video, clips: [first, later]),
                                     Track(name: "V2", kind: .video, clips: [overlay]),
                                     Track(name: "A1", kind: .audio)])
    return (Project(name: "Direct", assets: [asset], sequences: [sequence]), first, later)
}

@Test func moveAcrossTracksPreservesSourceAndUndo() throws {
    let (project, first, _) = try fixture()
    var session = try EditorSession(project: project)
    let destination = project.sequences[0].tracks[1].id
    try session.execute(.move(clipID: first.id, toTrackID: destination, start: t(2)))
    let moved = session.project.sequences[0].tracks[1].clips[0]
    #expect(moved.id == first.id)
    #expect(moved.sourceStart == first.sourceStart)
    #expect(moved.duration == first.duration)
    #expect(moved.start == (try t(2)))
    session.undo(); #expect(session.project == project)
    session.redo(); #expect(session.project.sequences[0].tracks[1].clips[0] == moved)
}

@Test func invalidMovesDoNotMutateHistory() throws {
    let (project, first, _) = try fixture()
    var session = try EditorSession(project: project)
    for (track, time) in [(project.sequences[0].tracks[0].id, try t(5)),
                          (project.sequences[0].tracks[2].id, try t(0)),
                          (project.sequences[0].tracks[0].id, try t(-1))] {
        #expect(throws: KurguError.self) { try session.execute(.move(clipID: first.id, toTrackID: track, start: time)) }
        #expect(session.project == project)
        #expect(!session.canUndo)
    }
    var locked = project
    locked.sequences[0].tracks[1].isLocked = true
    session = try EditorSession(project: locked)
    #expect(throws: KurguError.self) { try session.execute(.move(clipID: first.id, toTrackID: locked.sequences[0].tracks[1].id, start: t(0))) }
    locked.sequences[0].tracks[0].isLocked = true
    session = try EditorSession(project: locked)
    #expect(throws: KurguError.self) { try session.execute(.rippleRemove(clipID: first.id)) }
}

@Test func rippleClosesOccupiedIntervalOnOneTrack() throws {
    let (project, first, later) = try fixture()
    var session = try EditorSession(project: project)
    try session.execute(.rippleRemove(clipID: first.id))
    let remaining = session.project.sequences[0].tracks[0].clips
    #expect(remaining.count == 1)
    #expect(remaining[0].start == (try t(3))) // Existing two-second gap is preserved.
    #expect(remaining[0].sourceStart == later.sourceStart)
    #expect(session.project.sequences[0].tracks[1] == project.sequences[0].tracks[1])
    session.undo(); #expect(session.project == project)
}

@Test func snappingMatchesBothEdgesWithinTolerance() throws {
    let targets = [try t(5), try t(10)]
    let leading = try Snapping.move(start: t(49, 10), duration: t(2), targets: targets, tolerance: t(2, 10))
    #expect(leading.start == (try t(5)))
    let trailing = try Snapping.move(start: t(81, 10), duration: t(2), targets: targets, tolerance: t(2, 10))
    #expect(trailing.start == (try t(8)))
    #expect(trailing.guide == (try t(10)))
    let outside = try Snapping.move(start: t(7), duration: t(2), targets: targets, tolerance: t(2, 10))
    #expect(outside.guide == nil)
    let nonnegative = try Snapping.move(start: .zero, duration: t(2), targets: [try t(1)], tolerance: t(1))
    #expect(nonnegative.start >= .zero)
    let tie = try Snapping.move(start: t(5), duration: .zero, targets: [try t(6), try t(4)], tolerance: t(1))
    #expect(tie.guide == (try t(4)))
}
