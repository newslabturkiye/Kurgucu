import Foundation
@preconcurrency import AVFoundation
import KurguMedia

@MainActor public final class AudioMaster {
    private static var cached: (Data, AudioMaster)?
    public let url: URL
    public let peaks: [Float]
    public let binDuration: Double = 0.05
    private init(url: URL, peaks: [Float]) { self.url = url; self.peaks = peaks }
    deinit { try? FileManager.default.removeItem(at: url) }
    public static func render(composition: AVComposition, mix: AVAudioMix?, limit: Bool, cacheKey: Data? = nil) async throws -> AudioMaster? {
        if let cacheKey, let cached, cached.0 == cacheKey { return cached.1 }
        let tracks = try await composition.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nkurgu-mix-\(UUID().uuidString).caf")
        var succeeded = false
        defer { if !succeeded { try? FileManager.default.removeItem(at: url) } }
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        var fileSettings = format.settings; fileSettings[AVLinearPCMIsNonInterleaved] = false
        let file = try AVAudioFile(forWriting: url, settings: fileSettings)
        let reader = try AVAssetReader(asset: composition)
        let output = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 2, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true, AVLinearPCMIsNonInterleaved: false])
        output.audioMix = mix; reader.add(output)
        guard reader.startReading() else { throw reader.error ?? MediaError.unplayable }
        var peaks: [Float] = [], frames = 0
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard let data = CMSampleBufferGetDataBuffer(sample) else { continue }
            let length = CMBlockBufferGetDataLength(data)
            var values = [Float](repeating: 0, count: length / 4)
            let status = values.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(data, atOffset: 0, dataLength: length, destination: $0.baseAddress!) }
            guard status == kCMBlockBufferNoErr else { throw MediaError.unplayable }
            let desired = Int((CMSampleBufferGetPresentationTimeStamp(sample).seconds * 48000).rounded())
            while frames < desired {
                let gap = min(8192, desired - frames)
                let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(gap))!
                silence.frameLength = AVAudioFrameCount(gap)
                for channel in 0..<2 { silence.floatChannelData![channel].initialize(repeating: 0, count: gap) }
                try file.write(from: silence); frames += gap
                while peaks.count <= frames / 2400 { peaks.append(0) }
            }
            let count = values.count / 2
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count))!
            buffer.frameLength = AVAudioFrameCount(count)
            for frame in 0..<count {
                let bin = frames / 2400
                if bin >= peaks.count { peaks.append(0) }
                for channel in 0..<2 {
                    let input = values[frame * 2 + channel]
                    // Explicit hard-ceiling limiter: sample peaks are bounded, no look-ahead or true-peak claim.
                    let value = limit ? max(-0.98, min(0.98, input)) : input
                    buffer.floatChannelData![channel][frame] = value
                    peaks[bin] = max(peaks[bin], abs(value))
                }
                frames += 1
            }
            try file.write(from: buffer)
            await Task.yield()
        }
        guard reader.status == .completed else { throw reader.error ?? MediaError.unplayable }
        succeeded = true
        let master = AudioMaster(url: url, peaks: peaks)
        if let cacheKey { cached = (cacheKey, master) }
        return master
    }
}
