import Foundation

public enum TrackKind: String, Codable, Sendable { case video, audio, text, effect }
public enum MediaKind: String, Codable, Sendable { case video, audio }

public struct MediaAsset: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var kind: MediaKind
    public var fileURL: URL
    public var duration: MediaTime
    public var securityScopedBookmark: Data?
    public init(id: UUID = UUID(), name: String, kind: MediaKind, fileURL: URL, duration: MediaTime) {
        self.id = id; self.name = name; self.kind = kind; self.fileURL = fileURL; self.duration = duration
    }
}

/// First milestone supports unit-speed media clips. Time remapping will be a separate model.
public struct Clip: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var assetID: UUID
    public var start: MediaTime
    public var audio: TrackAudio?
    public var audioDetached: Bool?
    public var audioSettings: TrackAudio { audio ?? TrackAudio() }
    public var fadeIn: Double?
    public var fadeOut: Double?
    public var visual: VisualSettings?
    public var framing: ClipFraming?
    public var sourceStart: MediaTime
    public var duration: MediaTime
    public init(id: UUID = UUID(), assetID: UUID, start: MediaTime, sourceStart: MediaTime = .zero, duration: MediaTime, framing: ClipFraming? = nil) {
        self.id = id; self.assetID = assetID; self.start = start; self.framing = framing; self.sourceStart = sourceStart; self.duration = duration
    }
    public func end() throws -> MediaTime { try start.adding(duration) }
}

public struct TrackAudio: Codable, Equatable, Sendable {
    public var volume: Float
    public var isMuted: Bool
    public init(volume: Float = 1, isMuted: Bool = false) {
        self.volume = volume; self.isMuted = isMuted
    }
    public var effectiveVolume: Float { isMuted ? 0 : volume }
}

public struct Track: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var kind: TrackKind
    public var isLocked: Bool
    public var audio: TrackAudio?
    public var audioSettings: TrackAudio { audio ?? TrackAudio() }
    public var clips: [Clip]
    public init(id: UUID = UUID(), name: String, kind: TrackKind, isLocked: Bool = false, audio: TrackAudio? = nil, clips: [Clip] = []) {
        self.id = id; self.name = name; self.kind = kind; self.isLocked = isLocked; self.audio = audio; self.clips = clips
    }
}

public struct Sequence: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var width: Int
    public var height: Int
    public var overlays: [ImageOverlay]?
    public var titles: [TimelineTitle]?
    public var limiter: Bool?
    public var canvasFit: CanvasFit?
    public var fitMode: CanvasFit { canvasFit ?? .fit }
    /// Seconds per output frame, e.g. 1001/30000.
    public var frameDuration: MediaTime
    public var tracks: [Track]
    public init(id: UUID = UUID(), name: String = "Ana kurgu", width: Int = 1920, height: Int = 1080,
                frameDuration: MediaTime = try! MediaTime(1, timescale: 30), canvasFit: CanvasFit? = nil, tracks: [Track] = []) {
        self.id = id; self.name = name; self.width = width; self.height = height
        self.frameDuration = frameDuration; self.canvasFit = canvasFit; self.tracks = tracks
    }
}

public struct Project: Codable, Equatable, Sendable {
    public static let currentVersion = 7
    public var schemaVersion: Int
    public let id: UUID
    public var name: String
    public var assets: [MediaAsset]
    public var sequences: [Sequence]
    public init(id: UUID = UUID(), name: String, assets: [MediaAsset] = [], sequences: [Sequence] = [Sequence()]) {
        schemaVersion = Self.currentVersion; self.id = id; self.name = name
        self.assets = assets; self.sequences = sequences
    }

    public func validate() throws {
        guard schemaVersion == Self.currentVersion else { throw KurguError.unsupportedVersion(schemaVersion) }
        var identifiers = Set<UUID>()
        func unique(_ id: UUID) throws {
            guard identifiers.insert(id).inserted else { throw KurguError.invalidProject("Duplicate identifier") }
        }
        try unique(id)
        for asset in assets {
            try unique(asset.id)
            guard asset.duration > .zero, asset.fileURL.isFileURL else { throw KurguError.invalidProject("Invalid media") }
        }
        let media = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) })
        guard !sequences.isEmpty else { throw KurguError.invalidProject("Missing sequence") }
        for sequence in sequences {
            try unique(sequence.id)
            for overlay in sequence.overlays ?? [] {
                try unique(overlay.id)
                guard overlay.isValid else { throw KurguError.invalidProject("Invalid overlay") }
            }
            for title in sequence.titles ?? [] {
                try unique(title.id)
                guard !title.text.isEmpty, title.text.count <= 2000, title.start >= .zero, title.duration > .zero,
                      (title.style?.isValid ?? true), title.fontSize.isFinite, (12...180).contains(title.fontSize), title.vertical.isFinite, (0...1).contains(title.vertical) else { throw KurguError.invalidProject("Invalid title") }
            }
            guard (1...8192).contains(sequence.width), (1...8192).contains(sequence.height), sequence.frameDuration > .zero else {
                throw KurguError.invalidProject("Invalid sequence settings")
            }
            for track in sequence.tracks {
                try unique(track.id)
                guard track.audioSettings.volume.isFinite, (0...2).contains(track.audioSettings.volume) else {
                    throw KurguError.invalidProject("Track volume must be between 0 and 2")
                }
                var previousEnd = MediaTime.zero
                for clip in track.clips.sorted(by: { $0.start < $1.start }) {
                    try unique(clip.id)
                    guard clip.audioSettings.volume.isFinite, (0...2).contains(clip.audioSettings.volume),
                          !(track.kind == .audio && clip.audioDetached == true) else { throw KurguError.invalidProject("Invalid clip audio") }
                    let seconds = Double(clip.duration.value) / Double(clip.duration.timescale)
                    guard (clip.fadeIn ?? 0).isFinite, (clip.fadeOut ?? 0).isFinite, (clip.fadeIn ?? 0) >= 0, (clip.fadeOut ?? 0) >= 0,
                          (clip.fadeIn ?? 0) + (clip.fadeOut ?? 0) <= seconds else { throw KurguError.invalidProject("Invalid fade") }
                    guard clip.visual?.isValid(duration: seconds) ?? true else { throw KurguError.invalidProject("Invalid visual settings") }
                    guard clip.framing?.isValid ?? true else { throw KurguError.invalidProject("Invalid framing") }
                    guard let asset = media[clip.assetID], clip.start >= .zero, clip.sourceStart >= .zero,
                          clip.duration > .zero, clip.start >= previousEnd else {
                        throw KurguError.invalidProject("Invalid clip or overlapping clips")
                    }
                    guard (track.kind == .video && asset.kind == .video) || (track.kind == .audio && (asset.kind == .audio || asset.kind == .video)) else {
                        throw KurguError.invalidProject("Incompatible track and media")
                    }
                    guard try clip.sourceStart.adding(clip.duration) <= asset.duration else {
                        throw KurguError.invalidProject("Source range exceeds media")
                    }
                    previousEnd = try clip.end()
                }
            }
        }
    }
}
