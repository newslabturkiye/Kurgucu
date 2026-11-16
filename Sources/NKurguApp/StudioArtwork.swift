import SwiftUI
import AppKit

/// Load loose PNGs by URL: named SwiftUI images can silently miss images in an
/// embedded SwiftPM bundle. Cache decoded images rather than reopening on redraw.
@MainActor enum StudioAssets {
    private static var images: [String: NSImage] = [:]
    static func image(_ name: String) -> NSImage? {
        if let image = images[name] { return image }
        guard let url = Bundle.module.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        images[name] = image
        return image
    }
}

struct StudioArtwork: View {
    let name: String
    var fill = false
    var body: some View {
        if let image = StudioAssets.image(name) {
            if fill {
                Image(nsImage: image).renderingMode(.original).resizable().interpolation(.high).scaledToFill()
            } else {
                Image(nsImage: image).renderingMode(.original).resizable().interpolation(.high).scaledToFit()
            }
        } else {
            StudioIcon(glyph: .media, size: 70)
        }
    }
}
