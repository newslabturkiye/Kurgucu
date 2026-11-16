import SwiftUI
import AVKit
import KurguCore
import KurguPlayback

struct InteractivePlayer: View {
    let model: WorkspaceModel
    @State private var translation = CGSize.zero
    @State private var scale: CGFloat = 1
    var body: some View {
        GeometryReader { geometry in
            PlayerSurface(player: model.preview.player, sequence: model.sequence)
                .scaleEffect(scale).offset(translation).clipped()
                .overlay {
                    if let clip = model.clip, model.activeTrack?.kind == .video, !model.selectedIsLocked {
                        Rectangle().stroke(Studio.accent.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            .contentShape(Rectangle())
                            .gesture(DragGesture().onChanged { value in translation = value.translation }.onEnded { value in
                                var framing = clip.framing ?? ClipFraming()
                                if let image = model.thumbnails[clip.assetID] {
                                    let canvas = CGSize(width: model.sequence.width, height: model.sequence.height)
                                    let rect = CGRect(origin: .zero, size: image.size).applying(TimelineCompiler.framedTransform(size: image.size, preferred: .identity, canvas: canvas, defaultFit: model.sequence.fitMode, framing: framing))
                                    let dx = canvas.width - rect.width, dy = canvas.height - rect.height
                                    if abs(dx) > 0.1 { framing.horizontal = max(-1, min(1, framing.horizontal + value.translation.width / geometry.size.width * canvas.width * 2 / dx)) }
                                    if abs(dy) > 0.1 { framing.vertical = max(-1, min(1, framing.vertical + value.translation.height / geometry.size.height * canvas.height * 2 / dy)) }
                                }
                                model.apply(.setFraming(clipID: clip.id, framing: framing)); translation = .zero
                            })
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 12, weight: .bold)).padding(7).foregroundStyle(Studio.onAccent).background(Studio.accent, in: RoundedRectangle(cornerRadius: 5))
                                    .gesture(DragGesture().onChanged { value in scale = max(0.5, 1 + value.translation.width / max(1, geometry.size.width)) }.onEnded { value in
                                        var framing = clip.framing ?? ClipFraming()
                                        framing.zoom = max(1, min(4, framing.zoom * (1 + value.translation.width / max(1, geometry.size.width))))
                                        model.apply(.setFraming(clipID: clip.id, framing: framing)); scale = 1
                                    })
                            }.help("Kadrajı sürükle · Köşeden yakınlaştır · Boşluk/taşma olmayan eksen sabit kalır")
                    }
                }
        }.clipped()
    }
}

struct PlayerSurface: NSViewRepresentable {
    let player: AVPlayer
    let sequence: KurguCore.Sequence
    func makeNSView(context: Context) -> PreviewHost { PreviewHost() }
    func updateNSView(_ view: PreviewHost, context: Context) { view.update(player: player, sequence: sequence) }
}
final class PreviewHost: NSView {
    private let video = AVPlayerLayer()
    private var synced: AVSynchronizedLayer?
    private var caption: CALayer?
    private var identity: AVPlayerItem?
    private var signature = ""
    private var overlaySnapshot: [ImageOverlay] = []
    private var canvas = CGSize(width: 1920, height: 1080)
    override init(frame: NSRect) {
        super.init(frame: frame); wantsLayer = true; layer = CALayer(); layer?.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(video); video.videoGravity = .resizeAspect
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    func update(player: AVPlayer, sequence: KurguCore.Sequence) {
        video.player = player
        let overlays = sequence.overlays ?? []
        let key = String(data: (try? JSONEncoder().encode(sequence.titles ?? [])) ?? Data(), encoding: .utf8)! + "\(sequence.width)x\(sequence.height)"
        if identity !== player.currentItem || key != signature || overlaySnapshot != overlays {
            overlaySnapshot = overlays
            synced?.removeFromSuperlayer(); synced = nil; caption = nil
            identity = player.currentItem; signature = key; canvas = CGSize(width: sequence.width, height: sequence.height)
            if let item = player.currentItem {
                let sync = AVSynchronizedLayer(playerItem: item)
                let titles = TitleLayers.make(sequence: sequence); titles.anchorPoint = .zero; titles.position = .zero
                sync.addSublayer(titles); layer?.addSublayer(sync); synced = sync; caption = titles
            }
        }
        needsLayout = true
    }
    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        video.frame = bounds; synced?.frame = bounds
        caption?.transform = CATransform3DMakeScale(bounds.width / canvas.width, bounds.height / canvas.height, 1)
        CATransaction.commit()
    }
}

struct AudioMeter: View {
    let level: Float
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<12) { index in
                RoundedRectangle(cornerRadius: 1).fill(Double(level) > Double(index) / 12 ? (index > 9 ? Color.orange : Studio.accent) : Studio.border).frame(width: 3, height: 12)
            }
        }.accessibilityLabel("Ses seviyesi").accessibilityValue(level > 0 ? String(format: "%.1f dBFS", 20 * log10(level)) : "Sessiz")
    }
}
