import Foundation
import KurguCore

public enum EditCommand: Sendable {
    case setClipAudio(clipID: UUID, settings: TrackAudio)
    case detachAudio(clipID: UUID)
    case slip(clipID: UUID, sourceStart: MediaTime)
    case closeGaps(trackID: UUID)
    case setVisual(clipID: UUID, settings: VisualSettings?)
    case setOverlays(sequenceID: UUID, overlays: [ImageOverlay])
    case addAsset(MediaAsset)
    case batch([EditCommand])
    case moveSelection(clipIDs: Set<UUID>, delta: MediaTime)
    case setTitles(sequenceID: UUID, titles: [TimelineTitle])
    case setLimiter(sequenceID: UUID, enabled: Bool)
    case setFades(clipID: UUID, fadeIn: Double, fadeOut: Double)
    case setCanvas(sequenceID: UUID, width: Int, height: Int, fit: CanvasFit)
    case setFraming(clipID: UUID, framing: ClipFraming?)
    case setTrackLocked(trackID: UUID, locked: Bool)
    case setTrackAudio(trackID: UUID, settings: TrackAudio)
    case renameTrack(trackID: UUID, name: String)
    /// Append a copy to the end of the same track without moving existing clips.
    case duplicate(clipID: UUID)
    case addTrack(sequenceID: UUID, track: Track)
    case remove(clipID: UUID)
    /// Close only the removed clip's occupied interval on its own track.
    case rippleRemove(clipID: UUID)
    case move(clipID: UUID, toTrackID: UUID, start: MediaTime)
    case split(clipID: UUID, at: MediaTime)
    /// Retain a range in timeline coordinates; neighboring clips do not move.
    case trim(clipID: UUID, start: MediaTime, end: MediaTime)
    case insert(sequenceID: UUID, trackID: UUID, clip: Clip)
}

/// Value-type session; the UI will own this on MainActor. Only validated commits enter history.
public struct EditorSession: Sendable {
    public private(set) var project: Project
    private var undoStack: [Project] = []
    private var redoStack: [Project] = []
    public let historyLimit: Int
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public init(project: Project, historyLimit: Int = 100) throws {
        try project.validate()
        self.project = project; self.historyLimit = max(1, historyLimit)
    }

    public mutating func execute(_ command: EditCommand) throws {
        var candidate = project
        switch command {
        case let .moveSelection(ids, delta):
            guard !ids.isEmpty else { throw KurguError.invalidEdit }
            for id in ids {
                let (s, t, c) = try location(id)
                candidate.sequences[s].tracks[t].clips[c].start = try candidate.sequences[s].tracks[t].clips[c].start.adding(delta)
            }
        case let .batch(commands):
            var staged = try EditorSession(project: candidate)
            for command in commands { try staged.execute(command) }
            candidate = staged.project
        case let .setClipAudio(id, settings):
            let (s, t, c) = try location(id)
            guard candidate.sequences[s].tracks[t].clips[c].audioDetached != true else { throw KurguError.invalidEdit }
            candidate.sequences[s].tracks[t].clips[c].audio = settings
        case let .detachAudio(id):
            let (s, t, c) = try location(id)
            let original = candidate.sequences[s].tracks[t].clips[c]
            guard candidate.sequences[s].tracks[t].kind == .video, original.audioDetached != true else { throw KurguError.invalidEdit }
            var audio = Clip(assetID: original.assetID, start: original.start, sourceStart: original.sourceStart, duration: original.duration)
            audio.audio = original.audio; audio.fadeIn = original.fadeIn; audio.fadeOut = original.fadeOut
            let track = Track(name: "Ayrılan ses", kind: .audio, audio: candidate.sequences[s].tracks[t].audio, clips: [audio])
            candidate.sequences[s].tracks[t].clips[c].audioDetached = true
            candidate.sequences[s].tracks.append(track)
        case let .slip(id, sourceStart):
            let (s, t, c) = try location(id)
            candidate.sequences[s].tracks[t].clips[c].sourceStart = sourceStart
        case let .closeGaps(id):
            let (s, t) = try trackLocation(id)
            guard !candidate.sequences[s].tracks[t].isLocked else { throw KurguError.invalidEdit }
            var cursor = MediaTime.zero
            var clips = candidate.sequences[s].tracks[t].clips.sorted { $0.start < $1.start }
            for i in clips.indices {
                clips[i].start = cursor
                cursor = try clips[i].end()
            }
            candidate.sequences[s].tracks[t].clips = clips
        case let .setVisual(id, settings):
            let (s,t,c) = try location(id)
            guard candidate.sequences[s].tracks[t].kind == .video else { throw KurguError.invalidEdit }
            candidate.sequences[s].tracks[t].clips[c].visual = settings
        case let .setOverlays(id, overlays):
            guard let s = candidate.sequences.firstIndex(where: { $0.id == id }) else { throw KurguError.invalidEdit }
            candidate.sequences[s].overlays = overlays
        case let .setTitles(id, titles):
            guard let s = candidate.sequences.firstIndex(where: { $0.id == id }) else { throw KurguError.invalidEdit }
            candidate.sequences[s].titles = titles
        case let .setLimiter(id, enabled):
            guard let s = candidate.sequences.firstIndex(where: { $0.id == id }) else { throw KurguError.invalidEdit }
            candidate.sequences[s].limiter = enabled
        case let .setFades(id, fadeIn, fadeOut):
            let (s, t, c) = try location(id)
            candidate.sequences[s].tracks[t].clips[c].fadeIn = fadeIn
            candidate.sequences[s].tracks[t].clips[c].fadeOut = fadeOut
        case let .setCanvas(id, width, height, fit):
            guard (64...4096).contains(width), (64...4096).contains(height), width.isMultiple(of: 2), height.isMultiple(of: 2),
                  let s = candidate.sequences.firstIndex(where: { $0.id == id }) else { throw KurguError.invalidEdit }
            candidate.sequences[s].width = width; candidate.sequences[s].height = height
            candidate.sequences[s].canvasFit = fit
        case let .setFraming(id, framing):
            let (s, t, c) = try location(id)
            guard candidate.sequences[s].tracks[t].kind == .video else { throw KurguError.invalidEdit }
            candidate.sequences[s].tracks[t].clips[c].framing = framing
        case let .setTrackLocked(id, locked):
            let (s, t) = try trackLocation(id)
            candidate.sequences[s].tracks[t].isLocked = locked
        case let .setTrackAudio(id, settings):
            let (s, t) = try trackLocation(id)
            guard !candidate.sequences[s].tracks[t].isLocked else { throw KurguError.invalidEdit }
            candidate.sequences[s].tracks[t].audio = settings
        case let .renameTrack(id, name):
            let (s, t) = try trackLocation(id)
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= 60, !candidate.sequences[s].tracks[t].isLocked else { throw KurguError.invalidEdit }
            candidate.sequences[s].tracks[t].name = trimmed
        case let .duplicate(id):
            let (s, t, c) = try location(id)
            let original = candidate.sequences[s].tracks[t].clips[c]
            let end = try candidate.sequences[s].tracks[t].clips.map { try $0.end() }.max() ?? .zero
            var copy = original
            copy = Clip(assetID: original.assetID, start: end, sourceStart: original.sourceStart, duration: original.duration, framing: original.framing)
            copy.audio = original.audio; copy.audioDetached = original.audioDetached
            copy.visual = original.visual
            copy.fadeIn = original.fadeIn; copy.fadeOut = original.fadeOut
            candidate.sequences[s].tracks[t].clips.append(copy)
        case let .addAsset(asset):
            candidate.assets.append(asset)
        case let .addTrack(sequenceID, track):
            guard let s = candidate.sequences.firstIndex(where: { $0.id == sequenceID }) else { throw KurguError.invalidEdit }
            candidate.sequences[s].tracks.append(track)
        case let .insert(sequenceID, trackID, clip):
            guard let s = candidate.sequences.firstIndex(where: { $0.id == sequenceID }),
                  let t = candidate.sequences[s].tracks.firstIndex(where: { $0.id == trackID }),
                  !candidate.sequences[s].tracks[t].isLocked else { throw KurguError.invalidEdit }
            candidate.sequences[s].tracks[t].clips.append(clip)
        case let .move(id, targetID, start):
            let (s, t, c) = try location(id)
            guard start >= .zero,
                  let destination = candidate.sequences[s].tracks.firstIndex(where: { $0.id == targetID }),
                  !candidate.sequences[s].tracks[destination].isLocked,
                  candidate.sequences[s].tracks[destination].kind == candidate.sequences[s].tracks[t].kind else {
                throw KurguError.invalidEdit
            }
            var clip = candidate.sequences[s].tracks[t].clips.remove(at: c)
            clip.start = start
            candidate.sequences[s].tracks[destination].clips.append(clip)
            candidate.sequences[s].tracks[destination].clips.sort { $0.start < $1.start }
        case let .rippleRemove(id):
            let (s, t, c) = try location(id)
            let removed = candidate.sequences[s].tracks[t].clips.remove(at: c)
            let end = try removed.end()
            for index in candidate.sequences[s].tracks[t].clips.indices {
                if candidate.sequences[s].tracks[t].clips[index].start >= end {
                    candidate.sequences[s].tracks[t].clips[index].start = try candidate.sequences[s].tracks[t].clips[index].start.subtracting(removed.duration)
                }
            }
        case let .remove(id):
            let (s, t, c) = try location(id)
            candidate.sequences[s].tracks[t].clips.remove(at: c)
        case let .split(id, time):
            let (s, t, c) = try location(id)
            let original = candidate.sequences[s].tracks[t].clips[c]
            guard time > original.start, try time < original.end() else { throw KurguError.invalidEdit }
            let offset = try time.subtracting(original.start)
            var left = original
            left.duration = offset
            var right = Clip(assetID: original.assetID, start: time,
                             sourceStart: try original.sourceStart.adding(offset),
                             duration: try original.duration.subtracting(offset), framing: original.framing)
            right.audio = original.audio; right.audioDetached = original.audioDetached
            right.visual = original.visual
            if left.visual != nil {
                left.visual?.fadeIn = min(original.visual?.fadeIn ?? 0, Double(offset.value) / Double(offset.timescale)); left.visual?.fadeOut = 0
                right.visual?.fadeIn = 0; right.visual?.fadeOut = min(original.visual?.fadeOut ?? 0, Double(right.duration.value) / Double(right.duration.timescale))
            }
            left.fadeIn = min(original.fadeIn ?? 0, Double(offset.value) / Double(offset.timescale)); left.fadeOut = nil
            right.fadeOut = min(original.fadeOut ?? 0, Double(right.duration.value) / Double(right.duration.timescale)); right.fadeIn = nil
            candidate.sequences[s].tracks[t].clips.replaceSubrange(c...c, with: [left, right])
        case let .trim(id, start, end):
            let (s, t, c) = try location(id)
            var clip = candidate.sequences[s].tracks[t].clips[c]
            guard start >= clip.start, end > start, try end <= clip.end() else { throw KurguError.invalidEdit }
            clip.sourceStart = try clip.sourceStart.adding(start.subtracting(clip.start))
            clip.start = start
            clip.duration = try end.subtracting(start)
            let length = Double(clip.duration.value) / Double(clip.duration.timescale)
            if var visual = clip.visual {
                visual.fadeIn = min(visual.fadeIn, length)
                visual.fadeOut = min(visual.fadeOut, length - visual.fadeIn)
                clip.visual = visual
            }
            clip.fadeIn = min(clip.fadeIn ?? 0, length)
            clip.fadeOut = min(clip.fadeOut ?? 0, length - (clip.fadeIn ?? 0))
            candidate.sequences[s].tracks[t].clips[c] = clip
        }
        try candidate.validate()
        guard candidate != project else { return }
        undoStack.append(project)
        if undoStack.count > historyLimit { undoStack.removeFirst() }
        redoStack.removeAll()
        project = candidate
    }

    private func trackLocation(_ id: UUID) throws -> (Int, Int) {
        for (s, sequence) in project.sequences.enumerated() {
            if let t = sequence.tracks.firstIndex(where: { $0.id == id }) { return (s, t) }
        }
        throw KurguError.invalidEdit
    }

    private func location(_ id: UUID) throws -> (Int, Int, Int) {
        for (s, sequence) in project.sequences.enumerated() {
            for (t, track) in sequence.tracks.enumerated() {
                if let c = track.clips.firstIndex(where: { $0.id == id }) {
                    guard !track.isLocked else { throw KurguError.invalidEdit }
                    return (s, t, c)
                }
            }
        }
        throw KurguError.missingClip
    }

    public mutating func undo() {
        guard let prior = undoStack.popLast() else { return }
        redoStack.append(project); project = prior
    }
    public mutating func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(project); project = next
    }
}
