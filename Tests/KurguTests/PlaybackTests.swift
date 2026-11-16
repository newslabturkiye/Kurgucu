import Foundation
import AppKit
import Testing
@preconcurrency import AVFoundation
import KurguCore
import KurguMedia
import KurguPlayback
import KurguExport
import KurguEditing

@MainActor
private func audioFixture(at url: URL) throws {
    let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 96000)!
    buffer.frameLength = 96000
    for i in 0..<96000 { buffer.floatChannelData![0][i] = Float(sin(Double(i) * 2 * .pi * 440 / 48000)) * 0.1 }
    try file.write(from: buffer)
}

@Test func coreMediaTimeRoundTrip() throws {
    let rational = try MediaTime(1001, timescale: 30000)
    #expect(try MediaTime(cmTime: rational.cmTime) == rational)
    #expect(throws: MediaError.invalidTime) { try MediaTime(cmTime: .indefinite) }
    #expect(throws: MediaError.invalidTime) { try MediaTime(cmTime: CMTime(value: 1, timescale: 30, flags: .valid, epoch: 1)) }
}

@Test @MainActor func rotatedVideoFitsCanvas() {
    let transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)
    let fitted = TimelineCompiler.aspectFit(size: CGSize(width: 1920, height: 1080), preferred: transform,
                                            canvas: CGSize(width: 1920, height: 1080))
    let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080).applying(fitted)
    #expect(abs(bounds.height - 1080) < 0.001)
    #expect(abs(bounds.midX - 960) < 0.001)
    #expect(abs(bounds.midY - 540) < 0.001)
}

@Test @MainActor func importsAndCompilesRealAudio() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("tone.wav")
    try audioFixture(at: url)
    let imported = try await MediaImporter().inspect(url)
    #expect(imported.asset.kind == .audio)
    #expect(imported.hasAudio)
    #expect(imported.asset.duration == (try MediaTime(2)))
    let clip = Clip(assetID: imported.asset.id, start: try MediaTime(1), sourceStart: try MediaTime(1, timescale: 2), duration: try MediaTime(1))
    let sequence = Sequence(tracks: [Track(name: "A1", kind: .audio, clips: [clip])])
    let project = Project(name: "Audio", assets: [imported.asset], sequences: [sequence])
    let result = try await TimelineCompiler().compile(project, sequenceID: sequence.id)
    #expect(result.duration == (try MediaTime(2)))
    #expect(result.videoComposition == nil)
    let tracks = try await result.composition.loadTracks(withMediaType: .audio)
    #expect(tracks.count == 1)
    let segments = try await tracks[0].load(.segments).filter { !$0.isEmpty }
    #expect(segments.count == 1)
    #expect(segments[0].timeMapping.source.start == clip.sourceStart.cmTime)
    #expect(segments[0].timeMapping.target.start == clip.start.cmTime)
    let engine = PreviewEngine()
    try await engine.load(project, sequenceID: sequence.id)
    #expect(engine.player.currentItem != nil)
    let oldItem = engine.player.currentItem
    let empty = Project(name: "Empty")
    await #expect(throws: PlaybackError.emptySequence) { try await engine.load(empty, sequenceID: empty.sequences[0].id) }
    #expect(engine.player.currentItem === oldItem)
    #expect(!engine.isLoading)
    engine.unload()
    #expect(engine.player.currentItem == nil)
}

@Test @MainActor func missingMediaFailsClearly() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
    await #expect(throws: MediaError.missingFile(url.lastPathComponent)) { try await MediaImporter().inspect(url) }
}

@MainActor private func videoFixture(at url: URL, spatial: Bool = false) async throws {
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 48
    ])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 48
    ])
    writer.add(input)
    guard writer.startWriting() else { throw writer.error! }
    writer.startSession(atSourceTime: .zero)
    for frame in 0..<60 {
        let deadline = Date().addingTimeInterval(10)
        while !input.isReadyForMoreMediaData {
            guard Date() < deadline, writer.status == .writing else { throw MediaError.unplayable }
            try await Task.sleep(for: .milliseconds(2))
        }
        var optional: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 64, 48, kCVPixelFormatType_32BGRA, nil, &optional)
        let buffer = optional!
        CVPixelBufferLockBaseAddress(buffer, [])
        let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<48 { for x in 0..<64 {
            let p = y * stride + x * 4
            base[p] = frame < 30 ? 0 : 255; base[p+1] = 0
            base[p+2] = frame < 30 ? 255 : 0; base[p+3] = 255
            if spatial {
                base[p] = x >= 43 ? 255 : 0
                base[p+1] = (22..<43).contains(x) ? 255 : 0
                base[p+2] = x < 22 ? 255 : 0
            }
        } }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)) else { throw writer.error! }
    }
    input.markAsFinished()
    await writer.finishWriting()
    guard writer.status == .completed else { throw writer.error! }
}

@MainActor private func pixel(_ generator: AVAssetImageGenerator, seconds: Double) async throws -> [UInt8] {
    let result = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600))
    var bytes = [UInt8](repeating: 0, count: 4)
    bytes.withUnsafeMutableBytes { storage in
        let context = CGContext(data: storage.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(result.image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    return bytes
}

@Test(arguments: [false, true]) @MainActor func videoCompositingRendersCutsLayersAndGaps(custom: Bool) async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("colors.mov")
    try await videoFixture(at: url)
    let audioURL = root.appendingPathComponent("tone.wav")
    try audioFixture(at: audioURL)
    let combined = AVMutableComposition()
    let videoAsset = AVURLAsset(url: url)
    let audioAsset = AVURLAsset(url: audioURL)
    let videoTrack = try await videoAsset.loadTracks(withMediaType: .video)[0]
    let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio)[0]
    let fullRange = CMTimeRange(start: .zero, duration: CMTime(value: 2, timescale: 1))
    try combined.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        .insertTimeRange(fullRange, of: videoTrack, at: .zero)
    try combined.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
        .insertTimeRange(fullRange, of: audioTrack, at: .zero)
    let muxedURL = root.appendingPathComponent("colors-with-audio.mov")
    let muxer = AVAssetExportSession(asset: combined, presetName: AVAssetExportPresetPassthrough)!
    try await muxer.export(to: muxedURL, as: .mov)
    let imported = try await MediaImporter().inspect(muxedURL)
    #expect(imported.asset.kind == .video)
    #expect(imported.displayWidth == 64)
    #expect(imported.displayHeight == 48)
    #expect(imported.hasAudio)
    var red = Clip(assetID: imported.asset.id, start: .zero, duration: try MediaTime(1))
    if custom { var settings = VisualSettings(); settings.contrast = 1.0001; red.visual = settings }
    let blue = Clip(assetID: imported.asset.id, start: try MediaTime(2), sourceStart: try MediaTime(1), duration: try MediaTime(1))
    let overlay = Clip(assetID: imported.asset.id, start: try MediaTime(1, timescale: 2), sourceStart: try MediaTime(1), duration: try MediaTime(1, timescale: 2))
    let sequence = Sequence(width: 64, height: 48, tracks: [
        Track(name: "Overlay", kind: .video, clips: [overlay]),
        Track(name: "Main", kind: .video, clips: [red, blue])
    ])
    let project = Project(name: "Colors", assets: [imported.asset], sequences: [sequence])
    let result = try await TimelineCompiler().compile(project, sequenceID: sequence.id)
    #expect(result.duration == (try MediaTime(3)))
    let audioTracks = try await result.composition.loadTracks(withMediaType: .audio)
    #expect(audioTracks.count == 3)
    let overlayAudio = try await audioTracks[0].load(.segments).filter { !$0.isEmpty }
    #expect(overlayAudio[0].timeMapping.source.start == overlay.sourceStart.cmTime)
    #expect(overlayAudio[0].timeMapping.target.start == overlay.start.cmTime)
    let generator = AVAssetImageGenerator(asset: result.composition)
    generator.videoComposition = result.videoComposition
    generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
    let first = try await pixel(generator, seconds: 0.25)
    #expect(first[0] > 200 && first[2] < 30)
    let top = try await pixel(generator, seconds: 0.75)
    #expect(top[2] > 200 && top[0] < 30)
    let gap = try await pixel(generator, seconds: 1.5)
    #expect(gap.prefix(3).allSatisfy { $0 < 20 })
    let last = try await pixel(generator, seconds: 2.5)
    #expect(last[2] > 200 && last[0] < 30)
    let exportURL = root.appendingPathComponent("finished.mp4")
    let exporter = ExportEngine()
    try await exporter.export(project, sequenceID: sequence.id, to: exportURL)
    #expect(exporter.progress == 1)
    #expect(!exporter.isExporting)
    let exported = AVURLAsset(url: exportURL)
    #expect(abs(try await exported.load(.duration).seconds - 3) < 0.04)
    #expect(try await exported.loadTracks(withMediaType: .audio).count == 1)
    let exportedVideo = try await exported.loadTracks(withMediaType: .video)[0]
    let formats = try await exportedVideo.load(.formatDescriptions)
    #expect(CMFormatDescriptionGetMediaSubType(formats[0]) == kCMVideoCodecType_H264)
    let exportedFrames = AVAssetImageGenerator(asset: exported)
    exportedFrames.requestedTimeToleranceBefore = .zero
    exportedFrames.requestedTimeToleranceAfter = .zero
    let exportedRed = try await pixel(exportedFrames, seconds: 0.25)
    let exportedBlue = try await pixel(exportedFrames, seconds: 0.75)
    let exportedBlack = try await pixel(exportedFrames, seconds: 1.5)
    #expect(exportedRed[0] > 190 && exportedRed[2] < 40)
    #expect(exportedBlue[2] > 190 && exportedBlue[0] < 40)
    #expect(exportedBlack.prefix(3).allSatisfy { $0 < 20 })
    await #expect(throws: ExportError.destinationExists) {
        try await exporter.export(project, sequenceID: sequence.id, to: exportURL)
    }
    try await exporter.export(project, sequenceID: sequence.id, to: exportURL, replaceExisting: true)
    let before = try Data(contentsOf: exportURL)
    let cancelled = Task { @MainActor in
        try await exporter.export(project, sequenceID: sequence.id, to: exportURL, replaceExisting: true)
    }
    while !exporter.isExporting { await Task.yield() }
    exporter.cancel()
    await #expect(throws: CancellationError.self) { try await cancelled.value }
    #expect(try Data(contentsOf: exportURL) == before)
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).allSatisfy { !$0.hasPrefix(".nkurgu-") })
    let engine = PreviewEngine()
    try await engine.load(project, sequenceID: sequence.id)
    let sought = await engine.seek(to: try MediaTime(5, timescale: 2))
    #expect(sought)
    #expect(abs(engine.player.currentTime().seconds - 2.5) < 0.04)
    engine.player.isMuted = true
    engine.play()
    let deadline = Date().addingTimeInterval(5)
    while engine.player.currentTime().seconds < 2.7 && Date() < deadline {
        try await Task.sleep(for: .milliseconds(20))
    }
    engine.pause()
    #expect(engine.player.currentTime().seconds >= 2.7)
    #expect(engine.player.rate == 0)
    engine.unload()
}

@Test func invalidBookmarkFallsBackOnlyToReadableSource() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try Data([1, 2, 3]).write(to: root)
    defer { try? FileManager.default.removeItem(at: root) }
    let access = try MediaAccess(url: root, bookmark: Data([0]))
    #expect(access.url == root)
    let absent = root.appendingPathExtension("missing")
    #expect(throws: (any Error).self) { try MediaAccess(url: absent, bookmark: Data([0])) }
}

@MainActor private func rms(_ asset: AVAsset, mix: AVAudioMix? = nil) async throws -> Double {
    let reader = try AVAssetReader(asset: asset)
    let tracks = try await asset.loadTracks(withMediaType: .audio)
    let output = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32,
        AVLinearPCMIsFloatKey: true, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false
    ])
    output.audioMix = mix
    reader.add(output)
    guard reader.startReading() else { throw reader.error ?? MediaError.unplayable }
    var sum = 0.0, count = 0
    while let sample = output.copyNextSampleBuffer() {
        guard let data = CMSampleBufferGetDataBuffer(sample) else { continue }
        let length = CMBlockBufferGetDataLength(data)
        var values = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
        let status = values.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(data, atOffset: 0, dataLength: length, destination: $0.baseAddress!) }
        guard status == kCMBlockBufferNoErr else { throw MediaError.unplayable }
        for value in values { sum += Double(value * value); count += 1 }
    }
    guard reader.status == .completed, count > 0 else { throw reader.error ?? MediaError.unplayable }
    return sqrt(sum / Double(count))
}

@Test @MainActor func trackGainAndMuteReachPreviewAndExport() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let audioURL = root.appendingPathComponent("tone.wav"), videoURL = root.appendingPathComponent("video.mov")
    try audioFixture(at: audioURL); try await videoFixture(at: videoURL)
    let audio = try await MediaImporter().inspect(audioURL).asset
    let video = try await MediaImporter().inspect(videoURL).asset
    let duration = try MediaTime(2)
    let sequence = Sequence(width: 64, height: 48, tracks: [
        Track(name: "V1", kind: .video, clips: [Clip(assetID: video.id, start: .zero, duration: duration)]),
        Track(name: "A1", kind: .audio, audio: TrackAudio(volume: 0.25), clips: [Clip(assetID: audio.id, start: .zero, duration: duration)])
    ])
    var project = Project(name: "Mix", assets: [audio, video], sequences: [sequence])
    let prepared = try await TimelineCompiler().compile(project, sequenceID: sequence.id)
    #expect(prepared.makePlayerItem().audioMix != nil)
    let baseline = try await rms(AVURLAsset(url: audioURL))
    let previewRMS = try await rms(prepared.composition, mix: prepared.audioMix)
    #expect(abs(previewRMS / baseline - 0.25) < 0.01)
    let exporter = ExportEngine(), output = root.appendingPathComponent("quiet.mp4")
    try await exporter.export(project, sequenceID: sequence.id, to: output)
    let exportRMS = try await rms(AVURLAsset(url: output))
    #expect(abs(exportRMS / baseline - 0.25) < 0.04)
    project.sequences[0].tracks[1].audio?.isMuted = true
    let muted = try await TimelineCompiler().compile(project, sequenceID: sequence.id)
    #expect(muted.duration == duration)
    #expect(try await rms(muted.composition, mix: muted.audioMix) < 0.00001)
    let mutedURL = root.appendingPathComponent("muted.mp4")
    try await exporter.export(project, sequenceID: sequence.id, to: mutedURL)
    #expect(try await rms(AVURLAsset(url: mutedURL)) < 0.0001)
}

@Test @MainActor func portraitCropPixelsAndExportDimensionsMatch() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("bars.mov")
    try await videoFixture(at: source, spatial: true)
    let media = try await MediaImporter().inspect(source).asset
    let clip = Clip(assetID: media.id, start: .zero, duration: try MediaTime(1))
    let sequence = Sequence(width: 64, height: 192, canvasFit: .fill, tracks: [Track(name: "V", kind: .video, clips: [clip])])
    var project = Project(name: "Portrait", assets: [media], sequences: [sequence])
    for (position, channel) in [(-1.0, 0), (0.0, 1), (1.0, 2)] {
        project.sequences[0].tracks[0].clips[0].framing = ClipFraming(horizontal: position)
        let compiled = try await TimelineCompiler().compile(project, sequenceID: sequence.id)
        let generator = AVAssetImageGenerator(asset: compiled.composition)
        generator.videoComposition = compiled.videoComposition
        let color = try await pixel(generator, seconds: 0.25)
        #expect(color[channel] > 200)
        #expect(color[(channel + 1) % 3] < 40)
    }
    let output = root.appendingPathComponent("portrait.mp4")
    try await ExportEngine().export(project, sequenceID: sequence.id, to: output)
    let exported = AVURLAsset(url: output)
    let track = try await exported.loadTracks(withMediaType: .video)[0]
    #expect(try await track.load(.naturalSize) == CGSize(width: 64, height: 192))
    let exportedPixel = try await pixel(AVAssetImageGenerator(asset: exported), seconds: 0.25)
    #expect(exportedPixel[2] > 190 && exportedPixel[0] < 40)
    project.sequences[0].tracks[0].clips[0].framing = ClipFraming(fit: .fit)
    let fitted = try await TimelineCompiler().compile(project, sequenceID: sequence.id)
    let generator = AVAssetImageGenerator(asset: fitted.composition); generator.videoComposition = fitted.videoComposition
    let color = try await pixel(generator, seconds: 0.25)
    #expect(color.prefix(3).allSatisfy { $0 < 90 }) // Letterboxing takes 75% of the portrait canvas.
    for preset in [CanvasPreset.portrait, .landscape] {
        project.sequences[0].width = preset.width; project.sequences[0].height = preset.height
        let url = root.appendingPathComponent("preset-\(preset.rawValue).mp4")
        try await ExportEngine().export(project, sequenceID: sequence.id, to: url)
        let video = try await AVURLAsset(url: url).loadTracks(withMediaType: .video)[0]
        #expect(try await video.load(.naturalSize) == CGSize(width: preset.width, height: preset.height))
    }
}

@Test @MainActor func studioAudioProxyAndCaptionExport() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let audioURL = root.appendingPathComponent("tone.wav"), videoURL = root.appendingPathComponent("video.mov")
    try audioFixture(at: audioURL); try await videoFixture(at: videoURL)
    let wave = try await AudioAnalysis.waveform(url: audioURL, bins: 100)
    #expect(wave.peaks.count == 100 && wave.peaks.max()! > 0.09)
    let proxy = root.appendingPathComponent("proxy.mov")
    try await ProxyBuilder.build(source: videoURL, destination: proxy)
    let proxyAsset = try await MediaImporter().inspect(proxy).asset
    #expect(abs(proxyAsset.duration.cmTime.seconds - 2) < 0.04)
    let audio = try await MediaImporter().inspect(audioURL).asset
    let video = try await MediaImporter().inspect(videoURL).asset
    let videoClip = Clip(assetID: video.id, start: .zero, duration: try MediaTime(2))
    var audioClip = Clip(assetID: audio.id, start: try MediaTime(1), duration: try MediaTime(1))
    audioClip.fadeIn = 0.1; audioClip.fadeOut = 0.1
    let fadeSequence = Sequence(tracks: [Track(name: "Fade", kind: .audio, clips: [audioClip])])
    let fadeProject = Project(name: "Fade", assets: [audio], sequences: [fadeSequence])
    let fadePrepared = try await TimelineCompiler().compile(fadeProject, sequenceID: fadeSequence.id)
    let fadePeaks = try #require(fadePrepared.audioMaster).peaks
    #expect(fadePeaks[20] < fadePeaks[25] * 0.6)
    #expect(fadePeaks[39] < fadePeaks[25] * 0.6)
    let tracks = [Track(name: "V", kind: .video, clips: [videoClip])] + (0..<8).map { Track(name: "A\($0)", kind: .audio, audio: TrackAudio(volume: 2), clips: [Clip(assetID: audio.id, start: audioClip.start, duration: audioClip.duration)]) }
    var sequence = Sequence(width: 640, height: 480, tracks: tracks)
    sequence.limiter = true
    sequence.titles = [TimelineTitle(text: "TEST", start: try MediaTime(1, timescale: 4), duration: try MediaTime(1, timescale: 2), fontSize: 120, vertical: 0.4)]
    let project = Project(name: "Master", assets: [video, audio], sequences: [sequence])
    let compiled = try await TimelineCompiler().compile(project, sequenceID: sequence.id)
    let master = try #require(compiled.audioMaster)
    #expect(master.peaks.max()! <= 0.981)
    #expect(master.peaks.max()! > 0.97)
    #expect(master.peaks.prefix(18).allSatisfy { $0 < 0.0001 })
    let output = root.appendingPathComponent("titles.mp4")
    try await ExportEngine().export(project, sequenceID: sequence.id, to: output)
    let asset = AVURLAsset(url: output)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
    let withTitle = try await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 600))
    // Title adds white pixels to an otherwise pure red frame.
    let width = withTitle.image.width, height = withTitle.image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    bytes.withUnsafeMutableBytes { raw in
        let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(withTitle.image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    var white = 0
    for i in stride(from: 0, to: bytes.count, by: 4) { if bytes[i] > 190 && bytes[i+1] > 190 && bytes[i+2] > 190 { white += 1 } }
    #expect(white > 30)
    for time in [0.1, 1.5] {
        let frame = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600))
        bytes.withUnsafeMutableBytes { raw in
            let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(frame.image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        var outsideWhite = 0
        for i in stride(from: 0, to: bytes.count, by: 4) { if bytes[i] > 190 && bytes[i+1] > 190 && bytes[i+2] > 190 { outsideWhite += 1 } }
        #expect(outsideWhite < 5)
    }
    for codec in [ExportCodec.hevc, .proRes] {
        var settings = ExportSettings(); settings.codec = codec; settings.fps = 24; settings.width = 320; settings.height = 240
        let target = root.appendingPathComponent("codec-\(codec.rawValue).\(settings.extensionName)")
        try await ExportEngine().export(project, sequenceID: sequence.id, to: target, settings: settings)
        let track = try await AVURLAsset(url: target).loadTracks(withMediaType: .video)[0]
        #expect(try await track.load(.naturalSize) == CGSize(width: 320, height: 240))
        #expect(abs(try await track.load(.nominalFrameRate) - 24) < 0.1)
    }
}

@Test(arguments: [false, true]) @MainActor func styledTitleColorReachesPreviewAndExport(custom: Bool) async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("video.mov")
    try await videoFixture(at: source)
    let asset = try await MediaImporter().inspect(source).asset
    var clip = Clip(assetID: asset.id, start: .zero, duration: try MediaTime(2))
    if custom { var settings = VisualSettings(); settings.contrast = 1.1; clip.visual = settings }
    var sequence = Sequence(width: 640, height: 480, tracks: [Track(name: "Video", kind: .video, clips: [clip])])
    var style = TitleStyle(); style.font = .serif; style.foreground = TitleColor(0, 1, 0)
    style.background.alpha = 0; style.outlineWidth = 2; style.shadow = true
    sequence.titles = [TimelineTitle(text: "KURGU", start: try MediaTime(1, timescale: 4), duration: try MediaTime(1, timescale: 2), fontSize: 140, vertical: 0.4, style: style)]
    func greenPixels(_ image: CGImage) -> Int {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes { raw in
            let context = CGContext(data: raw.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return stride(from: 0, to: bytes.count, by: 4).filter { bytes[$0 + 1] > 150 && bytes[$0] < 100 && bytes[$0 + 2] < 100 }.count
    }
    let layer = try #require(TitleLayers.make(sequence: sequence).sublayers?.first)
    let contents = try #require(layer.contents)
    let preview = contents as! CGImage
    #expect(greenPixels(preview) > 100)
    let project = Project(name: "Color", assets: [asset], sequences: [sequence])
    let target = root.appendingPathComponent("styled.mp4")
    try await ExportEngine().export(project, sequenceID: sequence.id, to: target)
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: target))
    generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
    let visible = try await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 600))
    #expect(greenPixels(visible.image) > 100)
    let hidden = try await generator.image(at: CMTime(seconds: 0.9, preferredTimescale: 600))
    #expect(greenPixels(hidden.image) < 5)
}

@Test @MainActor func photoFilterFadeAndStickerExport() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    func png(red: CGFloat, green: CGFloat, blue: CGFloat) -> Data {
        let context = CGContext(data: nil, width: 64, height: 48, bitsPerComponent: 8, bytesPerRow: 256, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
        return NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
    }
    let photo = root.appendingPathComponent("photo.png"), movie = root.appendingPathComponent("still.mov")
    try png(red: 1, green: 0, blue: 0).write(to: photo)
    try await StillImageVideo.create(source: photo, destination: movie)
    let asset = try await MediaImporter().inspect(movie).asset
    #expect(abs(asset.duration.cmTime.seconds - 5) < 0.04)
    var clip = Clip(assetID: asset.id, start: .zero, duration: try MediaTime(1))
    var visual = VisualSettings(); visual.look = .monochrome; visual.fadeIn = 0.4; visual.blur = 1
    clip.visual = visual
    var sequence = Sequence(width: 320, height: 240, tracks: [Track(name: "V", kind: .video, clips: [clip])])
    var project = Project(name: "Visual", assets: [asset], sequences: [sequence])
    let prepared = try await TimelineCompiler().compile(project, sequenceID: sequence.id)
    let preview = AVAssetImageGenerator(asset: prepared.composition); preview.videoComposition = prepared.videoComposition
    preview.requestedTimeToleranceBefore = .zero; preview.requestedTimeToleranceAfter = .zero
    let gray = try await pixel(preview, seconds: 0.6)
    #expect(abs(Int(gray[0]) - Int(gray[1])) < 10 && abs(Int(gray[1]) - Int(gray[2])) < 10)
    let faded = try await pixel(preview, seconds: 0.1)
    #expect(Double(faded[0]) < Double(gray[0]) * 0.7) // Gamma-encoded output is not linear luminance.
    var overlay = ImageOverlay(name: "Green", png: png(red: 0, green: 1, blue: 0), start: try MediaTime(1, timescale: 4), duration: try MediaTime(1, timescale: 2))
    overlay.width = 0.5
    sequence.overlays = [overlay]; project.sequences = [sequence]
    let url = root.appendingPathComponent("output.mp4")
    try await ExportEngine().export(project, sequenceID: sequence.id, to: url)
    let exported = AVAssetImageGenerator(asset: AVURLAsset(url: url))
    exported.requestedTimeToleranceBefore = .zero; exported.requestedTimeToleranceAfter = .zero
    let sticker = try await pixel(exported, seconds: 0.5)
    #expect(Int(sticker[1]) > Int(sticker[0]) + 20 && Int(sticker[1]) > Int(sticker[2]) + 20) // pixel() averages the entire frame; sticker covers 25%.
    let after = try await pixel(exported, seconds: 0.9)
    #expect(abs(Int(after[0]) - Int(after[1])) < 15)
    #expect(abs(Int(after[0]) - Int(gray[0])) < 20)
    let data = try JSONEncoder().encode(project)
    #expect(try JSONDecoder().decode(Project.self, from: data) == project)
}

@Test(arguments: [false, true]) @MainActor func rotatedAndMirroredPixelsReachExport(custom: Bool) async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("bars.mov")
    try await videoFixture(at: url, spatial: true)
    let media = try await MediaImporter().inspect(url).asset
    var clip = Clip(assetID: media.id, start: .zero, duration: try MediaTime(1))
    if custom { var settings = VisualSettings(); settings.contrast = 1.0001; clip.visual = settings }
    // Mirror the horizontal bars, then crop the left edge: blue must replace red.
    var framing = ClipFraming(fit: .fill, horizontal: -1); framing.flipHorizontal = true
    clip.framing = framing
    var sequence = Sequence(width: 64, height: 192, tracks: [Track(name: "V", kind: .video, clips: [clip])])
    var project = Project(name: "Transform", assets: [media], sequences: [sequence])
    let compiled = try await TimelineCompiler().compile(project, sequenceID: sequence.id)
    let frames = AVAssetImageGenerator(asset: compiled.composition); frames.videoComposition = compiled.videoComposition
    #expect(try await pixel(frames, seconds: 0.2)[2] > 190)
    let mirrorURL = root.appendingPathComponent("mirror.mp4")
    try await ExportEngine().export(project, sequenceID: sequence.id, to: mirrorURL)
    #expect(try await pixel(AVAssetImageGenerator(asset: AVURLAsset(url: mirrorURL)), seconds: 0.2)[2] > 190)
    // A quarter turn swaps source dimensions; its fitted bounds fill 48×64 exactly.
    framing = ClipFraming(); framing.rotation = 90; framing.flipVertical = true
    let transform = TimelineCompiler.framedTransform(size: CGSize(width: 64, height: 48), preferred: .identity, canvas: CGSize(width: 48, height: 64), defaultFit: .fit, framing: framing)
    let bounds = CGRect(x: 0, y: 0, width: 64, height: 48).applying(transform)
    #expect(abs(bounds.minX) < 0.001 && abs(bounds.minY) < 0.001)
    #expect(abs(bounds.width - 48) < 0.001 && abs(bounds.height - 64) < 0.001)
    sequence.width = 48; sequence.height = 64; sequence.tracks[0].clips[0].framing = framing
    project.sequences = [sequence]
    let result = try await TimelineCompiler().compile(project, sequenceID: sequence.id)
    let generator = AVAssetImageGenerator(asset: result.composition); generator.videoComposition = result.videoComposition
    let expected = try await generator.image(at: CMTime(seconds: 0.2, preferredTimescale: 600)).image
    let rotationURL = root.appendingPathComponent("rotate.mp4")
    try await ExportEngine().export(project, sequenceID: sequence.id, to: rotationURL)
    let actual = try await AVAssetImageGenerator(asset: AVURLAsset(url: rotationURL)).image(at: CMTime(seconds: 0.2, preferredTimescale: 600)).image
    func samples(_ image: CGImage) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4 * 3)
        bytes.withUnsafeMutableBytes { raw in
            let context = CGContext(data: raw.baseAddress, width: 1, height: 3, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 3))
        }
        return bytes
    }
    let a = samples(expected), b = samples(actual)
    #expect(abs(Int(a[0]) - Int(a[8])) > 150) // bars became horizontal
    #expect(zip(a,b).allSatisfy { abs(Int($0) - Int($1)) < 25 })
}

@Test @MainActor func separatedAudioPreservesGainAndDoesNotDoubleSound() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let videoURL = root.appendingPathComponent("video.mov"), audioURL = root.appendingPathComponent("tone.wav")
    try await videoFixture(at: videoURL); try audioFixture(at: audioURL)
    let mux = AVMutableComposition()
    let videoAsset = AVURLAsset(url: videoURL), audioAsset = AVURLAsset(url: audioURL)
    let video = try await videoAsset.loadTracks(withMediaType: .video)[0]
    let audio = try await audioAsset.loadTracks(withMediaType: .audio)[0]
    let range = CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600))
    try mux.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!.insertTimeRange(range, of: video, at: .zero)
    try mux.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!.insertTimeRange(range, of: audio, at: .zero)
    let muxURL = root.appendingPathComponent("mux.mov")
    try await AVAssetExportSession(asset: mux, presetName: AVAssetExportPresetHighestQuality)!.export(to: muxURL, as: .mov)
    let media = try await MediaImporter().inspect(muxURL).asset
    var clip = Clip(assetID: media.id, start: .zero, sourceStart: try MediaTime(1, timescale: 2), duration: try MediaTime(1))
    clip.audio = TrackAudio(volume: 0.5)
    let sequence = Sequence(width: 64, height: 48, tracks: [Track(name: "V", kind: .video, audio: TrackAudio(volume: 0.5), clips: [clip])])
    var session = try EditorSession(project: Project(name: "Detach", assets: [media], sequences: [sequence]))
    let before = try await TimelineCompiler().compile(session.project, sequenceID: sequence.id)
    let level = try await rms(before.composition, mix: before.audioMix)
    let sourceLevel = try await rms(AVURLAsset(url: muxURL))
    #expect(abs(level / sourceLevel - 0.25) < 0.02)
    try session.execute(.detachAudio(clipID: clip.id))
    let after = try await TimelineCompiler().compile(session.project, sequenceID: sequence.id)
    #expect(try await after.composition.loadTracks(withMediaType: .audio).count == 1)
    #expect(abs(try await rms(after.composition, mix: after.audioMix) - level) < 0.001)
    let output = root.appendingPathComponent("detached.mp4")
    try await ExportEngine().export(session.project, sequenceID: sequence.id, to: output)
    #expect(abs(try await rms(AVURLAsset(url: output)) - level) < 0.003)
    let sound = session.project.sequences[0].tracks[1].clips[0]
    try session.execute(.setClipAudio(clipID: sound.id, settings: TrackAudio(isMuted: true)))
    let muted = try await TimelineCompiler().compile(session.project, sequenceID: sequence.id)
    #expect(try await rms(muted.composition, mix: muted.audioMix) < 0.00001)
}
