import Foundation
@preconcurrency import AVFoundation
import CoreImage
import KurguCore

final class VisualInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    struct Layer: Sendable {
        let trackID: CMPersistentTrackID
        let transform: CGAffineTransform
        let start: Double
        let end: Double
        let settings: VisualSettings
    }
    let timeRange: CMTimeRange
    let enablePostProcessing = true
    let containsTweening = true
    let passthroughTrackID = kCMPersistentTrackID_Invalid
    var requiredSourceTrackIDs: [NSValue]? { layers.map { NSNumber(value: $0.trackID) } }
    struct Overlay: @unchecked Sendable {
        let image: CIImage
        let start: Double
        let end: Double
        let opacity: Double
    }
    let layers: [Layer]
    let overlays: [Overlay]
    init(range: CMTimeRange, layers: [Layer], overlays: [Overlay] = []) { timeRange = range; self.layers = layers; self.overlays = overlays }
}

/// Core Image composites all active source tracks in the same order as the
/// standard compositor. A request owns its render context, so concurrent resize
/// does not replace a buffer pool beneath it. No mutable per-frame filter state.
final class VisualCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    let sourcePixelBufferAttributes: [String: any Sendable]? = [kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_32BGRA]]
    let requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferMetalCompatibilityKey as String: true, kCVPixelBufferIOSurfacePropertiesKey as String: [String: String](), kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true]
    private let context = CIContext(options: [.cacheIntermediates: false])
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}
    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        autoreleasepool {
            guard let instruction = request.videoCompositionInstruction as? VisualInstruction,
                  let destination = request.renderContext.newPixelBuffer() else {
                request.finish(with: NSError(domain: "kurgucu.render", code: 1)); return
            }
            let bounds = CGRect(origin: .zero, size: request.renderContext.size)
            var output = CIImage(color: .black).cropped(to: bounds)
            let time = request.compositionTime.seconds
            for layer in instruction.layers.reversed() {
                guard let buffer = request.sourceFrame(byTrackID: layer.trackID) else {
                    request.finish(with: NSError(domain: "kurgucu.render", code: 2)); return
                }
                var frame = CIImage(cvPixelBuffer: buffer)
                let s = layer.settings
                var saturation = s.saturation, contrast = s.contrast, warmth = s.temperature
                switch s.look {
                case .original: break
                case .monochrome: saturation *= 1 - s.intensity
                case .warm: warmth += 1400 * s.intensity
                case .cool: warmth -= 1400 * s.intensity
                case .vivid: saturation *= 1 + 0.4 * s.intensity; contrast *= 1 + 0.15 * s.intensity
                case .faded: contrast *= 1 - 0.25 * s.intensity; saturation *= 1 - 0.2 * s.intensity
                }
                frame = frame.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: s.exposure])
                frame = frame.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: saturation, kCIInputContrastKey: contrast])
                if warmth != 0 { frame = frame.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: 6500 + warmth, y: 0)]) }
                frame = frame.transformed(by: layer.transform)
                if s.blur > 0 { let extent = frame.extent; frame = frame.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: s.blur * bounds.height / 1080]).cropped(to: extent) }
                if s.vignette > 0 { frame = frame.applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: s.vignette, kCIInputRadiusKey: bounds.width * 0.6]) }
                var alpha = 1.0
                if s.fadeIn > 0 { alpha = min(alpha, max(0, (time - layer.start) / s.fadeIn)) }
                if s.fadeOut > 0 { alpha = min(alpha, max(0, (layer.end - time) / s.fadeOut)) }
                if alpha < 1 { frame = frame.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha)]) }
                output = frame.composited(over: output)
            }
            for overlay in instruction.overlays where time >= overlay.start && time < overlay.end {
                let image = overlay.image.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: overlay.opacity)])
                output = image.composited(over: output)
            }
            context.render(output.cropped(to: bounds), to: destination, bounds: bounds, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
            request.finish(withComposedVideoFrame: destination)
        }
    }
    func cancelAllPendingVideoCompositionRequests() { /* Requests complete synchronously. */ }
}
