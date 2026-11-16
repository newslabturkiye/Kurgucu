import Foundation
@preconcurrency import AVFoundation
import KurguCore
import KurguMedia

public enum PlaybackError: Error, Equatable { case missingSequence, emptySequence, trackAllocationFailed }

@MainActor
public final class PreparedPreview {
    public let composition: AVComposition
    public let videoComposition: AVVideoComposition?
    public let audioMix: AVAudioMix?
    public let duration: MediaTime
    public var audioMaster: AudioMaster?
    private let access: [MediaAccess]
    init(composition: AVComposition, videoComposition: AVVideoComposition?, audioMix: AVAudioMix?, duration: MediaTime, access: [MediaAccess]) {
        self.composition = composition; self.videoComposition = videoComposition
        self.duration = duration; self.audioMix = audioMix; self.access = access
    }
    public func makePlayerItem() -> AVPlayerItem {
        let item = AVPlayerItem(asset: composition)
        item.videoComposition = videoComposition
        item.audioMix = audioMix
        return item
    }
}

@MainActor
public struct TimelineCompiler {
    public init() {}
    private struct Layer {
        let start: MediaTime
        let end: MediaTime
        let track: AVCompositionTrack
        let visual: VisualSettings
        let transform: CGAffineTransform
    }

    /// Track array order is front to back. Embedded audio follows its video clip.
    public func compile(_ project: Project, sequenceID: UUID) async throws -> PreparedPreview {
        try project.validate()
        guard let sequence = project.sequences.first(where: { $0.id == sequenceID }) else { throw PlaybackError.missingSequence }
        let composition = AVMutableComposition()
        let models = Dictionary(uniqueKeysWithValues: project.assets.map { ($0.id, $0) })
        var sources: [UUID: AVURLAsset] = [:]
        var access: [MediaAccess] = []
        var layers: [Layer] = []
        var audioParameters: [AVAudioMixInputParameters] = []
        var duration = MediaTime.zero
        var boundaries: Set<MediaTime> = [.zero]
        for track in sequence.tracks {
            for clip in track.clips.sorted(by: { $0.start < $1.start }) {
                try Task.checkCancellation()
                let model = models[clip.assetID]!
                let source: AVURLAsset
                if let cached = sources[model.id] { source = cached }
                else {
                    let lease = try MediaAccess(url: model.fileURL, bookmark: model.securityScopedBookmark)
                    access.append(lease)
                    source = AVURLAsset(url: lease.url)
                    sources[model.id] = source
                    guard try await source.load(.isPlayable) else { throw MediaError.unplayable }
                }
                let end = try clip.end()
                duration = max(duration, end)
                boundaries.formUnion([clip.start, end])
                let sourceRange = CMTimeRange(start: clip.sourceStart.cmTime, duration: clip.duration.cmTime)
                if track.kind == .video {
                    guard let video = try await source.loadTracks(withMediaType: .video).first else { throw MediaError.missingTrack }
                    let available = try await video.load(.timeRange)
                    guard CMTimeRangeContainsTimeRange(available, otherRange: sourceRange) else { throw MediaError.sourceRangeUnavailable }
                    guard let destination = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw PlaybackError.trackAllocationFailed }
                    try destination.insertTimeRange(sourceRange, of: video, at: clip.start.cmTime)
                    let size = try await video.load(.naturalSize)
                    let preferred = try await video.load(.preferredTransform)
                    let transform = Self.framedTransform(size: size, preferred: preferred,
                        canvas: CGSize(width: sequence.width, height: sequence.height), defaultFit: sequence.fitMode, framing: clip.framing ?? ClipFraming())
                    layers.append(Layer(start: clip.start, end: end, track: destination, visual: clip.visual ?? VisualSettings(), transform: transform))
                }
                // Intersection preserves offset when embedded audio starts later or ends sooner than video.
                if clip.audioDetached == true { continue }
                if let audio = try await source.loadTracks(withMediaType: .audio).first {
                    let available = try await audio.load(.timeRange)
                    let intersection = CMTimeRangeGetIntersection(sourceRange, otherRange: available)
                    if intersection.isValid && intersection.duration > .zero {
                        guard let destination = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw PlaybackError.trackAllocationFailed }
                        let offset = CMTimeSubtract(intersection.start, sourceRange.start)
                        try destination.insertTimeRange(intersection, of: audio, at: CMTimeAdd(clip.start.cmTime, offset))
                        let parameters = AVMutableAudioMixInputParameters(track: destination)
                        let gain = track.audioSettings.effectiveVolume * clip.audioSettings.effectiveVolume
                        parameters.setVolume(gain, at: .zero)
                        if let fade = clip.fadeIn, fade > 0 {
                            parameters.setVolumeRamp(fromStartVolume: 0, toEndVolume: gain, timeRange: CMTimeRange(start: clip.start.cmTime, duration: CMTime(seconds: fade, preferredTimescale: 60000)))
                        }
                        if let fade = clip.fadeOut, fade > 0 {
                            parameters.setVolumeRamp(fromStartVolume: gain, toEndVolume: 0, timeRange: CMTimeRange(start: CMTimeSubtract(end.cmTime, CMTime(seconds: fade, preferredTimescale: 60000)), duration: CMTime(seconds: fade, preferredTimescale: 60000)))
                        }
                        audioParameters.append(parameters)
                    } else if track.kind == .audio { throw MediaError.sourceRangeUnavailable }
                } else if track.kind == .audio { throw MediaError.missingTrack }
            }
        }
        guard duration > .zero else { throw PlaybackError.emptySequence }
        if composition.duration < duration.cmTime {
            composition.insertEmptyTimeRange(CMTimeRange(start: composition.duration, end: duration.cmTime))
        }
        var videoComposition: AVMutableVideoComposition?
        if !layers.isEmpty {
            let video = AVMutableVideoComposition()
            video.renderSize = CGSize(width: sequence.width, height: sequence.height)
            video.frameDuration = sequence.frameDuration.cmTime
            // This milestone intentionally produces SDR Rec.709. HDR is a separate pipeline milestone.
            video.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
            video.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
            video.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
            let points = boundaries.sorted()
            if layers.contains(where: { $0.visual != VisualSettings() }) {
                video.customVideoCompositorClass = VisualCompositor.self
                video.instructions = zip(points, points.dropFirst()).map { start, end in
                    VisualInstruction(range: CMTimeRange(start: start.cmTime, end: end.cmTime), layers: layers.filter { $0.start <= start && $0.end > start }.map {
                        VisualInstruction.Layer(trackID: $0.track.trackID, transform: $0.transform, start: $0.start.cmTime.seconds, end: $0.end.cmTime.seconds, settings: $0.visual)
                    })
                }
            } else {
            video.instructions = zip(points, points.dropFirst()).map { start, end in
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = CMTimeRange(start: start.cmTime, end: end.cmTime)
                instruction.backgroundColor = CGColor(gray: 0, alpha: 1)
                instruction.layerInstructions = layers.filter { $0.start <= start && $0.end > start }.map { layer in
                    let result = AVMutableVideoCompositionLayerInstruction(assetTrack: layer.track)
                    result.setTransform(layer.transform, at: start.cmTime)
                    return result
                }
                return instruction
            }
            }
            videoComposition = video
        }
        try Task.checkCancellation()
        let mix = AVMutableAudioMix()
        mix.inputParameters = audioParameters
        struct MixSignature: Encodable { let assets: [MediaAsset]; let tracks: [Track]; let limited: Bool; let fileDates: [Date?] }
        var audioTracks = sequence.tracks
        for t in audioTracks.indices {
            audioTracks[t].name = ""; audioTracks[t].isLocked = false
            for c in audioTracks[t].clips.indices { audioTracks[t].clips[c].framing = nil; audioTracks[t].clips[c].visual = nil }
        }
        let dates = project.assets.map { try? (sources[$0.id]?.url ?? $0.fileURL).resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let key = try encoder.encode(MixSignature(assets: project.assets, tracks: audioTracks, limited: sequence.limiter ?? false, fileDates: dates))
        let mastering = try await AudioMaster.render(composition: composition, mix: audioParameters.isEmpty ? nil : mix, limit: sequence.limiter ?? false, cacheKey: key)
        if sequence.limiter == true, let mastering {
            for track in composition.tracks(withMediaType: .audio) { composition.removeTrack(track) }
            let audioAsset = AVURLAsset(url: mastering.url)
            if let source = try await audioAsset.loadTracks(withMediaType: .audio).first,
               let destination = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                let available = try await source.load(.timeRange)
                try destination.insertTimeRange(CMTimeRange(start: .zero, duration: min(available.duration, duration.cmTime)), of: source, at: .zero)
                let parameter = AVMutableAudioMixInputParameters(track: destination); parameter.setVolume(1, at: .zero)
                mix.inputParameters = [parameter]
            }
        }
        let prepared = PreparedPreview(composition: composition.copy() as! AVComposition,
                               videoComposition: videoComposition?.copy() as? AVVideoComposition,
                               audioMix: audioParameters.isEmpty ? nil : mix.copy() as? AVAudioMix, duration: duration, access: access)
        prepared.audioMaster = mastering
        return prepared
    }

    public static func aspectFit(size: CGSize, preferred: CGAffineTransform, canvas: CGSize) -> CGAffineTransform {
        framedTransform(size: size, preferred: preferred, canvas: canvas, defaultFit: .fit, framing: ClipFraming())
    }

    public static func framedTransform(size: CGSize, preferred: CGAffineTransform, canvas: CGSize,
                                       defaultFit: CanvasFit, framing: ClipFraming) -> CGAffineTransform {
        // Orient source first; mirror and rotate in upright source coordinates,
        // then fit the rotated bounds to the canvas. This handles portrait metadata.
        let upright = CGRect(origin: .zero, size: size).applying(preferred)
        let oriented = preferred
            .concatenating(CGAffineTransform(translationX: -upright.midX, y: -upright.midY))
            .concatenating(CGAffineTransform(scaleX: framing.flipHorizontal == true ? -1 : 1, y: framing.flipVertical == true ? -1 : 1))
            .concatenating(CGAffineTransform(rotationAngle: (framing.rotation ?? 0) * .pi / 180))
        let bounds = CGRect(origin: .zero, size: size).applying(oriented)
        guard bounds.width > 0, bounds.height > 0 else { return preferred }
        let fit = framing.fit ?? defaultFit
        let base = fit == .fit ? min(canvas.width / bounds.width, canvas.height / bounds.height) : max(canvas.width / bounds.width, canvas.height / bounds.height)
        let scale = base * framing.zoom
        let marginX = canvas.width - bounds.width * scale
        let marginY = canvas.height - bounds.height * scale
        return oriented
            .concatenating(CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: marginX * (1 + framing.horizontal) / 2,
                                             y: marginY * (1 + framing.vertical) / 2))
    }
}
