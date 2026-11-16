import Foundation
@preconcurrency import AVFoundation
import CoreImage
import ImageIO

@MainActor public enum StillImageVideo {
    /// Creates a managed 5-second clip. Transparent pixels are composited on black.
    public static func create(source: URL, destination: URL) async throws {
        let access = try MediaAccess(url: source)
        defer { withExtendedLifetime(access) {} }
        guard let image = CIImage(contentsOf: access.url, options: [.applyOrientationProperty: true]), image.extent.width > 0, image.extent.height > 0 else { throw MediaError.unsupportedMedia }
        let ratio = min(1, 1920 / max(image.extent.width, image.extent.height))
        let width = max(2, Int(image.extent.width * ratio) / 2 * 2), height = max(2, Int(image.extent.height * ratio) / 2 * 2)
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mov)
        var success = false
        defer { if !success { writer.cancelWriting(); try? FileManager.default.removeItem(at: destination) } }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height])
        let attributes: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height, kCVPixelBufferIOSurfacePropertiesKey as String: [:]]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? MediaError.unplayable }
        writer.startSession(atSourceTime: .zero)
        var raw: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &raw) == kCVReturnSuccess, let buffer = raw else { throw MediaError.unplayable }
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let frame = image.transformed(by: CGAffineTransform(scaleX: Double(width) / image.extent.width, y: Double(height) / image.extent.height)).composited(over: CIImage(color: .black)).cropped(to: bounds)
        CIContext().render(frame, to: buffer, bounds: bounds, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        for index in 0..<150 {
            let deadline = Date().addingTimeInterval(20)
            while !input.isReadyForMoreMediaData {
                try Task.checkCancellation()
                guard writer.status == .writing, Date() < deadline else { throw writer.error ?? MediaError.unplayable }
                try await Task.sleep(for: .milliseconds(5))
            }
            try Task.checkCancellation()
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(index), timescale: 30)) else { throw writer.error ?? MediaError.unplayable }
        }
        input.markAsFinished(); writer.endSession(atSourceTime: CMTime(value: 5, timescale: 1))
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? MediaError.unplayable }
        success = true
    }
}
