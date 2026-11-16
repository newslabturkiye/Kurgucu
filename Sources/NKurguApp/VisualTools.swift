import SwiftUI
import KurguCore

struct VisualTools: View {
    let model: WorkspaceModel
    let section: EditorSection
    let clip: Clip
    @State private var settings: VisualSettings
    init(model: WorkspaceModel, section: EditorSection, clip: Clip) {
        self.model = model; self.section = section; self.clip = clip
        _settings = State(initialValue: clip.visual ?? VisualSettings())
    }
    private func knob(_ title: String, _ key: WritableKeyPath<VisualSettings, Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(title); Spacer(); Text(String(format: "%.2f", settings[keyPath: key])).monospacedDigit().foregroundStyle(.secondary) }.font(.caption)
            Slider(value: Binding(get: { settings[keyPath: key] }, set: { settings[keyPath: key] = $0 }), in: range).accessibilityLabel(title)
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label(section.rawValue.uppercased(), systemImage: section.symbol).font(.caption.bold())
                Text("Seçili video klibi").font(.headline)
                if section == .filters {
                    ForEach(LookPreset.allCases, id: \.self) { look in
                        Button { settings.look = look } label: {
                            HStack { Image(systemName: settings.look == look ? "checkmark.circle.fill" : "circle"); Text(label(look)); Spacer() }.padding(10).background(settings.look == look ? Studio.accent.opacity(0.12) : Studio.raised, in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                    }
                    knob("Yoğunluk", \.intensity, 0...1)
                } else if section == .effects {
                    knob("Bulanıklık", \.blur, 0...30)
                    knob("Kenar karartma", \.vignette, 0...2)
                } else if section == .transitions {
                    Text("Görüntü açılma / kararma").font(.subheadline)
                    Text("Tek klipte siyaha; altta başka video varsa o görüntüye geçer. Ses fade'i ayrı ayarlanır.").font(.caption).foregroundStyle(.secondary)
                    knob("Giriş (sn)", \.fadeIn, 0...max(0.001, clip.duration.seconds))
                    knob("Çıkış (sn)", \.fadeOut, 0...max(0.001, clip.duration.seconds))
                    if settings.fadeIn + settings.fadeOut > clip.duration.seconds { Text("Toplam süre klip süresini aşamaz.").font(.caption).foregroundStyle(.red) }
                } else {
                    Button("Tuval ve oran…") { model.showCanvas = true }.buttonStyle(StudioButton())
                    knob("Pozlama", \.exposure, -2...2)
                    knob("Kontrast", \.contrast, 0.5...2)
                    knob("Doygunluk", \.saturation, 0...2)
                    knob("Sıcaklık", \.temperature, -2000...2000)
                }
                Button("Klibe uygula") { model.apply(.setVisual(clipID: clip.id, settings: settings)) }.buttonStyle(StudioButton(prominent: true))
                    .disabled(model.isBusy || model.selectedIsLocked || !settings.isValid(duration: clip.duration.seconds))
                Button("Tüm görsel ayarları sıfırla") { settings = VisualSettings(); model.apply(.setVisual(clipID: clip.id, settings: nil)) }.disabled(model.selectedIsLocked || model.isBusy)
                Text("Önizleme ve dışa aktarma aynı ayarları kullanır.").font(.caption).foregroundStyle(.secondary)
            }.padding(16)
        }.onChange(of: clip.visual) { _, value in settings = value ?? VisualSettings() }
    }
    private func label(_ look: LookPreset) -> String {
        switch look { case .original: "Özgün"; case .monochrome: "Siyah-beyaz"; case .warm: "Sıcak"; case .cool: "Soğuk"; case .vivid: "Canlı"; case .faded: "Soluk film" }
    }
}
