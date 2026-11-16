import AppKit
import CoreImage
import QuartzCore
import AVFoundation
import KurguCore
import KurguMedia

@MainActor public enum TitleLayers {
    public static func make(sequence: KurguCore.Sequence) -> CALayer {
        let root = CALayer()
        root.frame = CGRect(x: 0, y: 0, width: sequence.width, height: sequence.height)
        root.masksToBounds = true
        for overlay in sequence.overlays ?? [] {
            guard let image = NSBitmapImageRep(data: overlay.png)?.cgImage else { continue }
            let layer = CALayer()
            layer.name = overlay.id.uuidString
            let width = Double(sequence.width) * overlay.width
            layer.bounds = CGRect(x: 0, y: 0, width: width, height: width * Double(image.height) / Double(image.width))
            layer.position = CGPoint(x: overlay.x * Double(sequence.width), y: overlay.y * Double(sequence.height))
            layer.contents = image; layer.contentsGravity = .resizeAspect
            layer.transform = CATransform3DMakeRotation(overlay.rotation * .pi / 180, 0, 0, 1)
            let start = overlay.start.cmTime.seconds, end = start + overlay.duration.cmTime.seconds
            let total = max(end, sequence.tracks.flatMap(\.clips).compactMap { try? $0.end().cmTime.seconds }.max() ?? end) + 1
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            animation.values = start == 0 ? [overlay.opacity, 0, 0] : [0, overlay.opacity, 0, 0]
            animation.keyTimes = start == 0 ? [0, NSNumber(value: end / total), 1] : [0, NSNumber(value: start / total), NSNumber(value: end / total), 1]
            animation.calculationMode = .discrete; animation.beginTime = AVCoreAnimationBeginTimeAtZero
            animation.duration = total; animation.isRemovedOnCompletion = false; animation.fillMode = .both
            layer.add(animation, forKey: "visibility"); root.addSublayer(layer)
        }
        for title in sequence.titles ?? [] {
            let appearance = title.style ?? TitleStyle()
            let size = title.fontSize * Double(sequence.height) / 1080
            let base: NSFont
            switch appearance.font {
            case .system: base = NSFont.systemFont(ofSize: size, weight: appearance.bold ? .semibold : .regular)
            case .serif: base = NSFont(name: appearance.bold ? "Georgia-Bold" : "Georgia", size: size) ?? NSFont.systemFont(ofSize: size)
            case .monospaced: base = NSFont.monospacedSystemFont(ofSize: size, weight: appearance.bold ? .bold : .regular)
            }
            func color(_ value: TitleColor) -> NSColor { NSColor(srgbRed: value.red, green: value.green, blue: value.blue, alpha: value.alpha) }
            let paragraph = NSMutableParagraphStyle()
            switch appearance.alignment { case .left: paragraph.alignment = .left; case .center: paragraph.alignment = .center; case .right: paragraph.alignment = .right }
            let text = CALayer()
            text.name = title.id.uuidString
            var attributes: [NSAttributedString.Key: Any] = [.font: base, .foregroundColor: color(appearance.foreground), .paragraphStyle: paragraph]
            if appearance.outlineWidth > 0 { attributes[.strokeWidth] = -appearance.outlineWidth; attributes[.strokeColor] = color(appearance.outline) }
            if appearance.shadow {
                let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.8)
                shadow.shadowBlurRadius = size * 0.08; shadow.shadowOffset = CGSize(width: size * 0.03, height: -size * 0.04)
                attributes[.shadow] = shadow
            }
            let attributed = NSAttributedString(string: title.text, attributes: attributes)
            let width = Double(sequence.width) * 0.84
            let measured = attributed.boundingRect(with: CGSize(width: width - 20, height: Double(sequence.height)), options: [.usesLineFragmentOrigin, .usesFontLeading])
            let height = min(Double(sequence.height) * 0.8, ceil(measured.height) + 20)
            text.frame = CGRect(x: Double(sequence.width) * 0.08, y: Double(sequence.height) * title.vertical, width: width, height: height)
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(ceil(width)), pixelsHigh: Int(ceil(height)), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            attributed.draw(with: CGRect(x: 10, y: 10, width: width - 20, height: height - 20), options: [.usesLineFragmentOrigin, .usesFontLeading])
            NSGraphicsContext.restoreGraphicsState()
            text.contents = bitmap.cgImage; text.contentsGravity = .resize
            text.backgroundColor = color(appearance.background).cgColor
            text.cornerRadius = 8; text.opacity = 1
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            let start = Double(title.start.value) / Double(title.start.timescale)
            let end = start + Double(title.duration.value) / Double(title.duration.timescale)
            let total = max(end, sequence.tracks.flatMap(\.clips).compactMap { try? $0.end().cmTime.seconds }.max() ?? end) + 1
            animation.values = start == 0 ? [1, 0, 0] : [0, 1, 0, 0]
            animation.keyTimes = start == 0 ? [0, NSNumber(value: end / total), 1] : [0, NSNumber(value: start / total), NSNumber(value: end / total), 1]
            animation.calculationMode = .discrete
            animation.beginTime = AVCoreAnimationBeginTimeAtZero
            animation.duration = total
            animation.isRemovedOnCompletion = false; animation.fillMode = .both
            text.add(animation, forKey: "visibility"); root.addSublayer(text)
        }
        return root
    }
    public static func exportComposition(_ composition: AVVideoComposition, sequence: KurguCore.Sequence) -> AVVideoComposition {
        guard !(sequence.titles ?? []).isEmpty || !(sequence.overlays ?? []).isEmpty else { return composition }
        let copy = composition.mutableCopy() as! AVMutableVideoComposition
        if composition.customVideoCompositorClass != nil {
            // Custom compositor + Core Animation post-processing does not preserve
            // the video frame on this export path. Composite the same raster layers
            // directly into CI instead of feeding a second animation tool.
            let layers = make(sequence: sequence).sublayers ?? []
            var times: [String: (Double, Double, Double, Double)] = [:]
            for item in sequence.overlays ?? [] { times[item.id.uuidString] = (item.start.cmTime.seconds, item.duration.cmTime.seconds, item.opacity, item.rotation) }
            for item in sequence.titles ?? [] { times[item.id.uuidString] = (item.start.cmTime.seconds, item.duration.cmTime.seconds, 1, 0) }
            var overlays: [VisualInstruction.Overlay] = []
            for layer in layers {
                guard let name = layer.name, let timing = times[name], let contents = layer.contents else { continue }
                let bitmap = contents as! CGImage
                let size = layer.bounds.size
                var image = CIImage(cgImage: bitmap).transformed(by: CGAffineTransform(scaleX: size.width / Double(bitmap.width), y: size.height / Double(bitmap.height)))
                if let background = layer.backgroundColor {
                    let fill = CIFilter(name: "CIRoundedRectangleGenerator", parameters: ["inputExtent": CIVector(cgRect: CGRect(origin: .zero, size: size)), "inputRadius": layer.cornerRadius, "inputColor": CIColor(cgColor: background)])!.outputImage!
                    image = image.composited(over: fill)
                }
                let (start, duration, opacity, rotation) = timing
                image = image.transformed(by: CGAffineTransform(translationX: -size.width / 2, y: -size.height / 2)
                    .concatenating(CGAffineTransform(rotationAngle: rotation * .pi / 180)))
                    .transformed(by: CGAffineTransform(translationX: layer.position.x, y: layer.position.y))
                overlays.append(VisualInstruction.Overlay(image: image, start: start, end: start + duration, opacity: opacity))
            }
            copy.instructions = composition.instructions.compactMap { value in
                guard let instruction = value as? VisualInstruction else { return nil }
                return VisualInstruction(range: instruction.timeRange, layers: instruction.layers, overlays: overlays)
            }
            return copy
        }
        let root = CALayer(); root.frame = CGRect(x: 0, y: 0, width: sequence.width, height: sequence.height)
        let video = CALayer(); video.frame = root.bounds; root.addSublayer(video)
        root.addSublayer(make(sequence: sequence))
        copy.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: video, in: root)
        return copy
    }
}
