import Foundation
import Testing
import KurguCore
import KurguEditing
import KurguPersistence
import KurguPlayback
import CoreGraphics

@Test func canvasAndFramingAreAtomicAndPreservedInEdits() throws {
    let asset = MediaAsset(name: "Landscape", kind: .video, fileURL: URL(fileURLWithPath: "/tmp/landscape.mov"), duration: try MediaTime(10))
    let clip = Clip(assetID: asset.id, start: .zero, duration: try MediaTime(4))
    let sequence = Sequence(tracks: [Track(name: "Video", kind: .video, clips: [clip])])
    let project = Project(name: "Canvas", assets: [asset], sequences: [sequence])
    var session = try EditorSession(project: project)
    try session.execute(.setCanvas(sequenceID: sequence.id, width: 1080, height: 1920, fit: .fill))
    #expect(session.project.sequences[0].tracks == sequence.tracks)
    #expect(session.project.sequences[0].frameDuration == sequence.frameDuration)
    session.undo(); #expect(session.project == project); session.redo()
    let portrait = session.project
    for (width, height) in [(0, 1080), (1081, 1920), (8192, 1080)] {
        #expect(throws: KurguError.self) { try session.execute(.setCanvas(sequenceID: sequence.id, width: width, height: height, fit: .fit)) }
        #expect(session.project == portrait)
    }
    let framing = ClipFraming(fit: .fill, zoom: 1.5, horizontal: -0.7, vertical: 0.25)
    try session.execute(.setFraming(clipID: clip.id, framing: framing))
    try session.execute(.split(clipID: clip.id, at: MediaTime(2)))
    #expect(session.project.sequences[0].tracks[0].clips.allSatisfy { $0.framing == framing })
    try session.execute(.duplicate(clipID: clip.id))
    #expect(session.project.sequences[0].tracks[0].clips.last?.framing == framing)
    let before = session.project
    #expect(throws: KurguError.self) { try session.execute(.setFraming(clipID: clip.id, framing: ClipFraming(zoom: .nan))) }
    #expect(session.project == before)
    try session.execute(.setTrackLocked(trackID: sequence.tracks[0].id, locked: true))
    #expect(throws: KurguError.self) { try session.execute(.setFraming(clipID: clip.id, framing: nil)) }
}

@Test @MainActor func fitFillAndRotationGeometry() {
    let source = CGSize(width: 1920, height: 1080), canvas = CGSize(width: 1080, height: 1920)
    let rect = CGRect(origin: .zero, size: source)
    let fit = rect.applying(TimelineCompiler.framedTransform(size: source, preferred: .identity, canvas: canvas, defaultFit: .fit, framing: ClipFraming()))
    #expect(abs(fit.width - 1080) < 0.001 && fit.height < canvas.height)
    let fill = rect.applying(TimelineCompiler.framedTransform(size: source, preferred: .identity, canvas: canvas, defaultFit: .fill, framing: ClipFraming()))
    #expect(abs(fill.height - 1920) < 0.001 && fill.width > canvas.width)
    #expect(abs(fill.midX - 540) < 0.001)
    let leading = rect.applying(TimelineCompiler.framedTransform(size: source, preferred: .identity, canvas: canvas, defaultFit: .fill, framing: ClipFraming(horizontal: -1)))
    #expect(abs(leading.minX) < 0.001)
    let trailing = rect.applying(TimelineCompiler.framedTransform(size: source, preferred: .identity, canvas: canvas, defaultFit: .fill, framing: ClipFraming(horizontal: 1)))
    #expect(abs(trailing.maxX - 1080) < 0.001)
    let rotated = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)
    let rotatedFill = rect.applying(TimelineCompiler.framedTransform(size: source, preferred: rotated, canvas: canvas, defaultFit: .fill, framing: ClipFraming()))
    #expect(abs(rotatedFill.width - 1080) < 0.001 && abs(rotatedFill.height - 1920) < 0.001)
}

@Test func framingPersistsAndVersionTwoMigrates() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".nkurgu")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = ProjectStore()
    let asset = MediaAsset(name: "Source", kind: .video, fileURL: URL(fileURLWithPath: "/tmp/a.mov"), duration: try MediaTime(2))
    let clip = Clip(assetID: asset.id, start: .zero, duration: try MediaTime(2), framing: ClipFraming(fit: .fill, zoom: 2, horizontal: 0.5))
    let project = Project(name: "Framed", assets: [asset], sequences: [Sequence(width: 1080, height: 1920, canvasFit: .fill, tracks: [Track(name: "V1", kind: .video, clips: [clip])])])
    try await store.save(project, to: root)
    #expect(try await store.load(from: root) == project)
    var legacy = project; legacy.schemaVersion = 2
    legacy.sequences[0].canvasFit = nil; legacy.sequences[0].tracks[0].clips[0].framing = nil
    try JSONEncoder().encode(legacy).write(to: root.appendingPathComponent("project.json"))
    let loaded = try await store.load(from: root)
    #expect(loaded.schemaVersion == Project.currentVersion)
    #expect(loaded.sequences[0].fitMode == .fit)
    #expect(loaded.sequences[0].tracks[0].clips[0].framing == nil)
    for preset in CanvasPreset.allCases {
        #expect(preset.width.isMultiple(of: 2) && preset.height.isMultiple(of: 2))
        #expect(CanvasPreset.ratioLabel(width: preset.width, height: preset.height) == preset.ratio)
    }
}
