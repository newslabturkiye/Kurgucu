import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers
import KurguCore

struct OverlayPanel: View {
    let model: WorkspaceModel
    @State private var draft: ImageOverlay?
    private let presets = [("Sticker-Arrow", "Ok"), ("Sticker-Spark", "Yıldızlar"), ("Sticker-Heart", "Kalp")]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("ÇIKARTMALAR").font(.caption.bold())
                Text("Hareketli hikâyene bir vurgu.").font(.headline)
                HStack {
                    ForEach(presets, id: \.0) { preset in
                        Button {
                            if let url = Bundle.module.url(forResource: preset.0, withExtension: "png") { load(url, name: preset.1) }
                        } label: { StudioArtwork(name: preset.0).frame(width: 58, height: 58).background(Studio.raised, in: RoundedRectangle(cornerRadius: 10)) }
                            .buttonStyle(.plain).help(preset.1).accessibilityLabel(preset.1)
                    }
                }
                Button("Görsel / PNG ekle…") {
                    let panel = NSOpenPanel(); panel.allowedContentTypes = [.image]
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    load(url, name: url.deletingPathExtension().lastPathComponent)
                }.buttonStyle(StudioButton())
                if let item = draft {
                    Text(item.name).font(.subheadline.bold())
                    HStack { Text("Başlangıç"); TextField("sn", value: timeBinding(start: true), format: .number) }.textFieldStyle(.roundedBorder)
                    HStack { Text("Süre"); TextField("sn", value: timeBinding(start: false), format: .number) }.textFieldStyle(.roundedBorder)
                    slider("Yatay", \.x, 0...1)
                    slider("Dikey", \.y, 0...1)
                    slider("Boyut", \.width, 0.02...1)
                    slider("Döndür", \.rotation, -180...180)
                    slider("Opaklık", \.opacity, 0...1)
                    HStack {
                        Button("Uygula") {
                            var all = model.sequence.overlays ?? []
                            if let i = all.firstIndex(where: { $0.id == item.id }) { all[i] = item } else { all.append(item) }
                            model.apply(.setOverlays(sequenceID: model.sequence.id, overlays: all))
                        }.buttonStyle(StudioButton(prominent: true)).disabled(!item.isValid || model.isBusy)
                        Button("Sil") { model.apply(.setOverlays(sequenceID: model.sequence.id, overlays: (model.sequence.overlays ?? []).filter { $0.id != item.id })); draft = nil }.disabled(model.isBusy)
                    }
                }
                Divider()
                ForEach(model.sequence.overlays ?? []) { overlay in
                    Button { draft = overlay } label: {
                        HStack { Text(overlay.name).lineLimit(1); Spacer(); Text(String(format: "%.1f sn", overlay.duration.seconds)).font(.caption) }.padding(8).background(Studio.raised, in: RoundedRectangle(cornerRadius: 6))
                    }.buttonStyle(.plain)
                }
                Text("Görseller proje dosyasına gömülür. Üst üste gelenlerde en son eklenen üsttedir; yazılar hepsinin üstüne çizilir. Görseli video süresi içinde tutun.").font(.caption).foregroundStyle(.secondary)
            }.padding(16)
        }
    }
    private func slider(_ title: String, _ key: WritableKeyPath<ImageOverlay, Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack { Text(title); Spacer(); Text(String(format: "%.2f", draft?[keyPath: key] ?? 0)).monospacedDigit() }.font(.caption)
            Slider(value: Binding(get: { draft?[keyPath: key] ?? range.lowerBound }, set: { draft?[keyPath: key] = $0 }), in: range).accessibilityLabel(title)
        }
    }
    private func timeBinding(start: Bool) -> Binding<Double> {
        Binding(get: { start ? (draft?.start.seconds ?? 0) : (draft?.duration.seconds ?? 3) }, set: { value in
            guard value.isFinite, value >= 0, value <= 86400, let time = model.quantized(value) else { return }
            if start { draft?.start = time } else { draft?.duration = time }
        })
    }
    private func load(_ url: URL, name: String) {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 1024] as CFDictionary),
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            model.errorMessage = "Görsel okunamadı."; return
        }
        draft = ImageOverlay(name: name, png: png, start: model.preview.currentTime, duration: try! MediaTime(3))
    }
}
