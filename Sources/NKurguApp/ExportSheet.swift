import SwiftUI
import KurguExport

struct ExportSheet: View {
    @Bindable var model: WorkspaceModel
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                StudioIcon(glyph: .export, size: 52)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Filmin hazır.").font(.system(size: 25, weight: .medium))
                    Text("SDR · Kadraj, metin ve ses birlikte").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 30) {
                metric("BOYUT", "\(model.sequence.width) × \(model.sequence.height)")
                metric("KARE HIZI", String(format: "%.2f fps", 1 / model.sequence.frameDuration.seconds))
                metric("SÜRE", String(format: "%.2f sn", model.timelineEnd))
            }.padding(18).background(Studio.raised, in: RoundedRectangle(cornerRadius: 10))
            if !model.exporter.isExporting && model.exportedURL == nil {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Kodek", selection: $model.exportSettings.codec) {
                        Text("H.264 · MP4").tag(ExportCodec.h264)
                        Text("HEVC · MP4").tag(ExportCodec.hevc)
                        Text("ProRes 422 · MOV").tag(ExportCodec.proRes)
                    }
                    Picker("Kalite", selection: $model.exportSettings.quality) {
                        Text("Küçük dosya · ~3 Mbps").tag(ExportQuality.compact)
                        Text("Standart · ~8 Mbps").tag(ExportQuality.standard)
                        Text("En iyi").tag(ExportQuality.best)
                    }.disabled(model.exportSettings.codec == .proRes)
                    Picker("Kare hızı", selection: Binding(get: { model.exportSettings.fps ?? 0 }, set: { model.exportSettings.fps = $0 == 0 ? nil : $0 })) {
                        Text("Projeyle aynı").tag(0)
                        ForEach([24, 25, 30, 50, 60], id: \.self) { Text("\($0) fps").tag($0) }
                    }
                    HStack {
                        Text("Boyut")
                        Menu("\(model.exportSettings.width ?? model.sequence.width) × \(model.exportSettings.height ?? model.sequence.height)") {
                            Button("Proje boyutu") { model.exportSettings.width = nil; model.exportSettings.height = nil }
                            Button("Yarım boyut") { model.exportSettings.width = max(64, model.sequence.width / 4 * 2); model.exportSettings.height = max(64, model.sequence.height / 4 * 2) }
                            Button("2× boyut") { model.exportSettings.width = model.sequence.width * 2; model.exportSettings.height = model.sequence.height * 2 }.disabled(model.sequence.width > 2048 || model.sequence.height > 2048)
                        }
                    }
                    let seconds = model.timelineEnd
                    let mbps = model.exportSettings.codec == .proRes ? 150.0 : model.exportSettings.quality == .compact ? 3.0 : model.exportSettings.quality == .standard ? 8.0 : 20.0
                    Text(String(format: "Yaklaşık %.1f MB · İçeriğe ve kodeğe göre değişir.", seconds * mbps / 8)).font(.caption).foregroundStyle(.secondary)
                }
            }
            if model.exporter.isExporting {
                ProgressView(value: model.exporter.progress).tint(Studio.accent)
                HStack { Text(model.exporter.phase); Spacer(); Text("\(Int(model.exporter.progress * 100))%") }.font(.caption).foregroundStyle(.secondary)
                Button("Dışa aktarmayı iptal et") { model.exporter.cancel() }.buttonStyle(StudioButton())
            } else if let url = model.exportedURL {
                Label("Dosyan kaydedildi", systemImage: "checkmark.circle.fill").foregroundStyle(Studio.accent)
                Text(url.lastPathComponent).font(.callout).textSelection(.enabled)
                HStack {
                    Button("Finder’da göster") { NSWorkspace.shared.activateFileViewerSelecting([url]) }.buttonStyle(StudioButton())
                    Spacer()
                    Button("Bitti") { model.showExport = false }.buttonStyle(StudioButton(prominent: true))
                }
            } else {
                Text("Görüntü, ses ve kesmeler önizlemeyle aynı kompozisyondan oluşturulur.").font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button("Vazgeç") { model.showExport = false }.buttonStyle(StudioButton())
                    Spacer()
                    Button("Konum seç ve dışa aktar", action: model.exportVideo).buttonStyle(StudioButton(prominent: true))
                }
            }
        }.padding(30).frame(width: 510).background(Studio.panel)
            .interactiveDismissDisabled(model.exporter.isExporting)
    }
    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
            Text(value).font(.system(size: 13, weight: .medium, design: .monospaced))
        }
    }
}
