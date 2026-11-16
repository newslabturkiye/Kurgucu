import Foundation
@preconcurrency import AVFoundation
import KurguCore

public enum MediaError: Error, Equatable, Sendable {
    case invalidTime, unsupportedMedia, unplayable, staleBookmark, missingFile(String), missingTrack, sourceRangeUnavailable
}

public extension MediaTime {
    var cmTime: CMTime { CMTime(value: value, timescale: timescale) }
    init(cmTime: CMTime) throws {
        guard cmTime.isNumeric, cmTime.epoch == 0 else { throw MediaError.invalidTime }
        try self.init(cmTime.value, timescale: cmTime.timescale)
    }
}

/// Access is held throughout asynchronous loading and the lifetime of a prepared preview.
public final class MediaAccess {
    public let url: URL
    private let scoped: Bool
    public init(url: URL, bookmark: Data? = nil) throws {
        let resolvedURL: URL
        if let bookmark {
            do {
                var stale = false
                let candidate = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI],
                                        relativeTo: nil, bookmarkDataIsStale: &stale)
                guard !stale else { throw MediaError.staleBookmark }
                resolvedURL = candidate
            } catch {
                // Ad-hoc application signatures change across local builds. Use the saved
                // source URL only when the OS already permits access; never bypass sandboxing.
                guard url.isFileURL, FileManager.default.isReadableFile(atPath: url.path) else { throw error }
                resolvedURL = url
            }
        } else { resolvedURL = url }
        let started = resolvedURL.startAccessingSecurityScopedResource()
        guard FileManager.default.isReadableFile(atPath: resolvedURL.path) else {
            if started { resolvedURL.stopAccessingSecurityScopedResource() }
            throw MediaError.missingFile(resolvedURL.lastPathComponent)
        }
        self.url = resolvedURL
        self.scoped = started
    }
    deinit { if scoped { url.stopAccessingSecurityScopedResource() } }
}

public struct ImportedMedia: Sendable {
    public let asset: MediaAsset
    public let hasAudio: Bool
    public let displayWidth: Double?
    public let displayHeight: Double?
    public let nominalFrameRate: Float?
}

@MainActor
public struct MediaImporter {
    public init() {}
    /// Pass persistAccess for URLs selected through NSOpenPanel in the sandboxed app.
    public func inspect(_ url: URL, persistAccess: Bool = false) async throws -> ImportedMedia {
        let access = try MediaAccess(url: url)
        defer { withExtendedLifetime(access) {} }
        let source = AVURLAsset(url: access.url)
        guard try await source.load(.isPlayable), try await !source.load(.hasProtectedContent) else { throw MediaError.unplayable }
        let duration = try await MediaTime(cmTime: source.load(.duration))
        guard duration > .zero else { throw MediaError.unsupportedMedia }
        let video = try await source.loadTracks(withMediaType: .video).first
        let audio = try await source.loadTracks(withMediaType: .audio).first
        guard video != nil || audio != nil else { throw MediaError.unsupportedMedia }
        var model = MediaAsset(name: url.lastPathComponent, kind: video == nil ? .audio : .video,
                               fileURL: access.url, duration: duration)
        if persistAccess {
            model.securityScopedBookmark = try access.url.bookmarkData(options: .withSecurityScope,
                includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        var width: Double?, height: Double?, rate: Float?
        if let video {
            let size = try await video.load(.naturalSize)
            let transform = try await video.load(.preferredTransform)
            let bounds = CGRect(origin: .zero, size: size).applying(transform)
            width = abs(bounds.width); height = abs(bounds.height)
            rate = try await video.load(.nominalFrameRate)
        }
        try Task.checkCancellation()
        return ImportedMedia(asset: model, hasAudio: audio != nil, displayWidth: width, displayHeight: height, nominalFrameRate: rate)
    }
}
