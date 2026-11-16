import Foundation
import Testing
import KurguCore
import KurguEditing
import KurguPersistence

@Test func recoveryHistoryAndSubtitleRoundTrip() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let recovery = RecoveryStore(root: root)
    var project = Project(name: "Recover")
    for i in 0..<23 { project.name = "Version \(i)"; try await recovery.checkpoint(project) }
    let entries = await recovery.entries()
    #expect(entries.count == 20)
    #expect(try await recovery.restore(entries[0]) == project)
    let text = "1\n00:00:01,250 --> 00:00:02,750\nMerhaba dünya\nİkinci satır\n\n2\n00:00:03,000 --> 00:00:04,000\nSon\n"
    let titles = try SubtitleFile.parse(text)
    #expect(titles.count == 2)
    #expect(titles[0].start == (try MediaTime(5, timescale: 4)))
    let parsed = try SubtitleFile.parse(SubtitleFile.encode(titles))
    #expect(parsed.map(\.text) == titles.map(\.text))
    #expect(parsed.map(\.duration) == titles.map(\.duration))
    #expect(throws: KurguError.self) { try SubtitleFile.parse("1\n00:00:05,000 --> 00:00:04,000\nBad") }
}

@Test func groupMovesAreAtomicAndFadesSurviveEditing() throws {
    let media = MediaAsset(name: "A", kind: .audio, fileURL: URL(fileURLWithPath: "/tmp/a.wav"), duration: try MediaTime(10))
    let a = Clip(assetID: media.id, start: .zero, duration: try MediaTime(2))
    let b = Clip(assetID: media.id, start: try MediaTime(2), duration: try MediaTime(2))
    let track = Track(name: "A", kind: .audio, clips: [a, b])
    let project = Project(name: "Group", assets: [media], sequences: [Sequence(tracks: [track])])
    var session = try EditorSession(project: project)
    try session.execute(.moveSelection(clipIDs: [a.id, b.id], delta: MediaTime(1)))
    #expect(session.project.sequences[0].tracks[0].clips.map(\.start) == [try MediaTime(1), try MediaTime(3)])
    session.undo(); #expect(session.project == project)
    #expect(throws: KurguError.self) { try session.execute(.batch([.remove(clipID: a.id), .remove(clipID: UUID())])) }
    #expect(session.project == project)
    try session.execute(.setFades(clipID: a.id, fadeIn: 0.8, fadeOut: 0.8))
    try session.execute(.split(clipID: a.id, at: MediaTime(1)))
    let clips = session.project.sequences[0].tracks[0].clips
    #expect(clips[0].fadeIn == 0.8 && clips[0].fadeOut == nil)
    #expect(clips[1].fadeOut == 0.8 && clips[1].fadeIn == nil)
    try session.execute(.trim(clipID: a.id, start: .zero, end: MediaTime(1, timescale: 2)))
    #expect(session.project.sequences[0].tracks[0].clips[0].fadeIn == 0.5)
}

@Test func titleStylesPersistValidateAndUndo() async throws {
    var style = TitleStyle()
    style.font = .serif; style.bold = false; style.alignment = .left
    style.foreground = TitleColor(0, 1, 0); style.background.alpha = 0
    style.outlineWidth = 3; style.shadow = true
    let title = TimelineTitle(text: "Türkçe: ğüşİ", duration: try MediaTime(2), style: style)
    var project = Project(name: "Styles")
    project.sequences[0].titles = [title]
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".nkurgu")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = ProjectStore()
    try await store.save(project, to: root)
    #expect(try await store.load(from: root) == project)
    var session = try EditorSession(project: project)
    var invalid = title; invalid.style?.outlineWidth = 9
    #expect(throws: KurguError.self) { try session.execute(.setTitles(sequenceID: project.sequences[0].id, titles: [invalid])) }
    #expect(session.project == project)
    var changed = title; changed.style?.alignment = .right
    try session.execute(.setTitles(sequenceID: project.sequences[0].id, titles: [changed]))
    session.undo(); #expect(session.project == project)
    session.redo(); #expect(session.project.sequences[0].titles?[0].style?.alignment == .right)
    // An old project has no style field; loading must keep legacy defaults.
    project.schemaVersion = 4; project.sequences[0].titles?[0].style = nil
    try JSONEncoder().encode(project).write(to: root.appendingPathComponent("project.json"))
    let legacy = try await store.load(from: root)
    #expect(legacy.schemaVersion == Project.currentVersion)
    #expect(legacy.sequences[0].titles?[0].style == nil)
}

@Test func visualSettingsAreAtomicAndSurviveEdits() throws {
    let asset = MediaAsset(name: "V", kind: .video, fileURL: URL(fileURLWithPath: "/tmp/v.mov"), duration: try MediaTime(5))
    var clip = Clip(assetID: asset.id, start: .zero, duration: try MediaTime(4))
    var settings = VisualSettings(); settings.look = .warm; settings.fadeIn = 1; settings.fadeOut = 1; settings.blur = 2
    clip.visual = settings
    let track = Track(name: "V", kind: .video, clips: [clip])
    let project = Project(name: "Visual", assets: [asset], sequences: [Sequence(tracks: [track])])
    var session = try EditorSession(project: project)
    var invalid = settings; invalid.exposure = .infinity
    #expect(throws: KurguError.self) { try session.execute(.setVisual(clipID: clip.id, settings: invalid)) }
    #expect(session.project == project)
    try session.execute(.split(clipID: clip.id, at: MediaTime(2)))
    let clips = session.project.sequences[0].tracks[0].clips
    #expect(clips[0].visual?.look == .warm && clips[1].visual?.look == .warm)
    #expect(clips[0].visual?.fadeIn == 1 && clips[0].visual?.fadeOut == 0)
    #expect(clips[1].visual?.fadeIn == 0 && clips[1].visual?.fadeOut == 1)
    session.undo(); #expect(session.project == project)
    try session.execute(.trim(clipID: clip.id, start: .zero, end: MediaTime(1)))
    #expect(session.project.sequences[0].tracks[0].clips[0].visual?.fadeOut == 0)
}

@Test func sourceSeparationSlipAndGapCommandsAreAtomic() throws {
    let media = MediaAsset(name: "Video", kind: .video, fileURL: URL(fileURLWithPath: "/tmp/video.mov"), duration: try MediaTime(12))
    var a = Clip(assetID: media.id, start: try MediaTime(2), sourceStart: try MediaTime(1), duration: try MediaTime(3))
    a.audio = TrackAudio(volume: 0.5); a.fadeIn = 0.25
    var framing = ClipFraming(); framing.rotation = 90; framing.flipHorizontal = true
    a.framing = framing
    let b = Clip(assetID: media.id, start: try MediaTime(8), duration: try MediaTime(2))
    let track = Track(name: "V", kind: .video, audio: TrackAudio(volume: 0.7), clips: [a,b])
    let original = Project(name: "Edits", assets: [media], sequences: [Sequence(tracks: [track])])
    var session = try EditorSession(project: original)
    try session.execute(.detachAudio(clipID: a.id))
    let detached = session.project
    let sound = detached.sequences[0].tracks[1]
    #expect(sound.kind == .audio && sound.audio == track.audio)
    #expect(sound.clips[0].start == a.start && sound.clips[0].sourceStart == a.sourceStart && sound.clips[0].duration == a.duration)
    #expect(sound.clips[0].audio == a.audio && sound.clips[0].fadeIn == a.fadeIn)
    #expect(sound.clips[0].framing == nil && sound.clips[0].id != a.id)
    #expect(detached.sequences[0].tracks[0].clips[0].audioDetached == true)
    #expect(throws: KurguError.self) { try session.execute(.detachAudio(clipID: a.id)) }
    #expect(session.project == detached)
    session.undo(); #expect(session.project == original); session.redo(); #expect(session.project == detached)
    try session.execute(.split(clipID: a.id, at: MediaTime(3)))
    #expect(session.project.sequences[0].tracks[0].clips.prefix(2).allSatisfy { $0.audioDetached == true && $0.framing == framing })
    session.undo(); session.undo()
    try session.execute(.slip(clipID: a.id, sourceStart: MediaTime(7)))
    #expect(session.project.sequences[0].tracks[0].clips[0].start == a.start)
    #expect(session.project.sequences[0].tracks[0].clips[0].duration == a.duration)
    let slipped = session.project
    #expect(throws: KurguError.self) { try session.execute(.slip(clipID: a.id, sourceStart: MediaTime(11))) }
    #expect(session.project == slipped)
    try session.execute(.closeGaps(trackID: track.id))
    #expect(session.project.sequences[0].tracks[0].clips.map(\.start) == [.zero, try MediaTime(3)])
    #expect(session.project.sequences[0].tracks[0].clips[0].sourceStart == (try MediaTime(7)))
    try session.execute(.setTrackLocked(trackID: track.id, locked: true))
    let locked = session.project
    #expect(throws: KurguError.self) { try session.execute(.closeGaps(trackID: track.id)) }
    #expect(throws: KurguError.self) { try session.execute(.setClipAudio(clipID: a.id, settings: TrackAudio(volume: 1))) }
    #expect(throws: KurguError.self) { try session.execute(.slip(clipID: a.id, sourceStart: .zero)) }
    #expect(session.project == locked)
    #expect(try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(locked)) == locked)
}

@Test func legacyFramingAndAudioDecodeWithSafeDefaults() throws {
    let data = Data(#"{"zoom":1,"horizontal":0,"vertical":0}"#.utf8)
    let framing = try JSONDecoder().decode(ClipFraming.self, from: data)
    #expect(framing.isValid && framing.rotation == nil && framing.flipHorizontal == nil)
    var invalid = framing; invalid.rotation = .infinity
    #expect(!invalid.isValid)
}
