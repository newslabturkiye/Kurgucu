import Foundation
import Observation
@preconcurrency import AVFoundation
import KurguCore
import KurguPlayback

public enum ExportCodec: String, CaseIterable, Sendable { case h264, hevc, proRes }
public enum ExportQuality: String, CaseIterable, Sendable { case compact, standard, best }
public struct ExportSettings: Sendable {
    public var codec: ExportCodec = .h264
    public var quality: ExportQuality = .best
    public var width: Int? = nil
    public var height: Int? = nil
    public var fps: Int? = nil
    public init() {}
    public var extensionName: String { codec == .proRes ? "mov" : "mp4" }
    public var preset: String {
        if codec == .proRes { return AVAssetExportPresetAppleProRes422LPCM }
        if codec == .hevc { return AVAssetExportPresetHEVCHighestQuality }
        return AVAssetExportPresetHighestQuality
    }
}

public enum ExportError: Error, Equatable {
    case alreadyRunning, invalidDestination, sourceOverwrite, destinationExists, noVideo, unavailableEncoder
}

@MainActor @Observable
public final class ExportEngine {
    public private(set) var isExporting = false
    public private(set) var progress: Double = 0
    public private(set) var phase = ""
    @ObservationIgnored private var session: AVAssetExportSession?
    @ObservationIgnored private var cancelled = false
    public init() {}
    public func cancel() { cancelled = true; session?.cancelExport() }

    /// Snapshot is immutable; write alongside destination, then commit only a complete file.
    public func export(_ project: Project, sequenceID: UUID, to destination: URL, replaceExisting: Bool = false, settings: ExportSettings = ExportSettings()) async throws {
        guard !isExporting else { throw ExportError.alreadyRunning }
        guard destination.isFileURL, destination.pathExtension.lowercased() == settings.extensionName else { throw ExportError.invalidDestination }
        let target = destination.standardizedFileURL.resolvingSymlinksInPath()
        guard !project.assets.contains(where: { $0.fileURL.standardizedFileURL.resolvingSymlinksInPath() == target }) else { throw ExportError.sourceOverwrite }
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path), !replaceExisting { throw ExportError.destinationExists }
        isExporting = true; cancelled = false; progress = 0; phase = "Kurgu hazırlanıyor"
        let staging = destination.deletingLastPathComponent().appendingPathComponent(".nkurgu-\(UUID().uuidString).\(settings.extensionName)")
        defer {
            session = nil; isExporting = false
            try? fm.removeItem(at: staging)
        }
        var snapshot = project
        if let s = snapshot.sequences.firstIndex(where: { $0.id == sequenceID }) {
            if let width = settings.width, let height = settings.height {
                guard (64...4096).contains(width), (64...4096).contains(height), width.isMultiple(of: 2), height.isMultiple(of: 2) else { throw ExportError.invalidDestination }
                snapshot.sequences[s].width = width; snapshot.sequences[s].height = height
            }
            if let fps = settings.fps {
                guard [24, 25, 30, 50, 60].contains(fps) else { throw ExportError.invalidDestination }
                snapshot.sequences[s].frameDuration = try MediaTime(1, timescale: Int32(fps))
            }
        }
        let compiled = try await TimelineCompiler().compile(snapshot, sequenceID: sequenceID)
        guard compiled.videoComposition != nil else { throw ExportError.noVideo }
        try checkCancellation()
        guard let exporter = AVAssetExportSession(asset: compiled.composition, presetName: settings.preset),
              exporter.supportedFileTypes.contains(settings.codec == .proRes ? .mov : .mp4) else { throw ExportError.unavailableEncoder }
        exporter.videoComposition = TitleLayers.exportComposition(compiled.videoComposition!, sequence: snapshot.sequences.first { $0.id == sequenceID }!)
        exporter.audioMix = compiled.audioMix
        exporter.timeRange = CMTimeRange(start: .zero, duration: compiled.duration.cmTime)
        exporter.shouldOptimizeForNetworkUse = true
        if settings.codec != .proRes && settings.quality != .best {
            let mbps: Double = settings.quality == .compact ? 3 : 8
            exporter.fileLengthLimit = Int64(max(100000, Double(compiled.duration.value) / Double(compiled.duration.timescale) * mbps * 1000000 / 8))
        }
        session = exporter; phase = "Video dışa aktarılıyor"
        let observer = Task { @MainActor in
            while !Task.isCancelled {
                progress = Double(exporter.progress)
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        defer { observer.cancel(); withExtendedLifetime(compiled) {} }
        do { try await exporter.export(to: staging, as: settings.codec == .proRes ? .mov : .mp4) }
        catch { if cancelled || Task.isCancelled { throw CancellationError() }; throw error }
        try checkCancellation()
        phase = "Dosya tamamlanıyor"
        if fm.fileExists(atPath: destination.path) {
            guard replaceExisting else { throw ExportError.destinationExists }
            _ = try fm.replaceItemAt(destination, withItemAt: staging)
        } else { try fm.moveItem(at: staging, to: destination) }
        progress = 1; phase = "Dışa aktarma tamamlandı"
    }
    private func checkCancellation() throws {
        try Task.checkCancellation()
        if cancelled { throw CancellationError() }
    }
}
