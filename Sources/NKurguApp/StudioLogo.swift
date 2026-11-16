import SwiftUI

/// One brand image in every surface, resolved for the current appearance.
struct StudioLogo: View {
    @Environment(\.colorScheme) private var colorScheme
    var size: CGFloat = 120

    var body: some View {
        StudioArtwork(name: colorScheme == .dark ? "Logo-Dark" : "Logo-Light")
            .frame(width: size, height: size)
            .accessibilityLabel("kurgucu logosu")
    }
}
