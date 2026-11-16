import Foundation
@preconcurrency import AVFoundation

public struct Waveform: Sendable {
    public var peaks: [Float]
    public var secondsPerBin: Double
    public init(peaks: [Float], secondsPerBin: Double) { self.peaks = peaks; self.secondsPerBin = secondsPerBin }
}

public enum AudioAnalysis {
    public static func waveform(url: URL, bins: Int = 1500) async throws -> Waveform {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty, duration.isFinite, duration > 0 else { return Waveform(peaks: [], secondsPerBin: 1) }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 8000, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true, AVLinearPCMIsNonInterleaved: false])
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? MediaError.unplayable }
        var peaks = [Float](repeating: 0, count: bins)
        while let buffer = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let length = CMBlockBufferGetDataLength(block)
            var values = [Float](repeating: 0, count: length / 4)
            let status = values.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: $0.baseAddress!) }
            guard status == kCMBlockBufferNoErr else { throw MediaError.unplayable }
            let start = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
            for (i, value) in values.enumerated() {
                let bin = min(bins - 1, max(0, Int((start + Double(i) / 8000) / duration * Double(bins))))
                peaks[bin] = max(peaks[bin], abs(value))
            }
        }
        guard reader.status == .completed else { throw reader.error ?? MediaError.unplayable }
        return Waveform(peaks: peaks, secondsPerBin: duration / Double(bins))
    }
}

@MainActor public enum ProxyBuilder {
    public static func build(source: URL, destination: URL) async throws {
        let asset = AVURLAsset(url: source)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else { throw MediaError.unplayable }
        try await export.export(to: destination, as: .mov)
    }
}
