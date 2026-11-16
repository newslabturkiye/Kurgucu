import SwiftUI
import KurguCore

struct ClipAudioAndSlip: View {
    let model: WorkspaceModel
    let clip: Clip
    @State private var volume: Double
    @State private var sourceStart: Double
    init(model: WorkspaceModel, clip: Clip) {
        self.model = model; self.clip = clip
        _volume = State(initialValue: Double(clip.audioSettings.volume))
        _sourceStart = State(initialValue: clip.sourceStart.seconds)
    }
    private var maxSourceStart: Double {
        max(0, (model.project.assets.first { $0.id == clip.assetID }?.duration.seconds ?? 0) - clip.duration.seconds)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KLİP SESİ").font(.caption.bold())
            if clip.audioDetached == true {
                Label("Ses ayrı izde", systemImage: "waveform")
                Text("Ses ayarlarını ayrılan klipten düzenleyin. Video ve ses artık bağımsız taşınır. Ayırmayı ⌘Z ile geri alabilirsiniz.").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Seviye: %\(Int((volume * 100).rounded()))")
                Slider(value: $volume, in: 0...2, onEditingChanged: { editing in
                    if !editing { model.apply(.setClipAudio(clipID: clip.id, settings: TrackAudio(volume: Float(volume), isMuted: clip.audioSettings.isMuted))) }
                }).accessibilityLabel("Klip ses seviyesi")
                Toggle("Klibi sustur", isOn: Binding(get: { clip.audioSettings.isMuted }, set: {
                    model.apply(.setClipAudio(clipID: clip.id, settings: TrackAudio(volume: clip.audioSettings.volume, isMuted: $0)))
                }))
                if model.activeTrack?.kind == .video {
                    Button("Sesi ayrı ize ayır", action: model.detachSelectedAudio).buttonStyle(StudioButton())
                }
            }
            Divider()
            Text("KAYNAK KESİTİNİ KAYDIR").font(.caption.bold())
            Text("Timeline konumu ve süre sabit kalır. Kaynaktaki başka bir aralığı kullanır.").font(.caption).foregroundStyle(.secondary)
            TextField("Kaynak başlangıcı (sn)", value: $sourceStart, format: .number.precision(.fractionLength(3)))
                .textFieldStyle(.roundedBorder).accessibilityLabel("Kaynak başlangıcı")
            Text(String(format: "Aralık: 0 – %.3f sn", maxSourceStart)).font(.caption).foregroundStyle(.secondary)
            Button("Kaynak kesitini uygula") {
                if let time = model.quantized(sourceStart) { model.apply(.slip(clipID: clip.id, sourceStart: time)) }
            }.disabled(!sourceStart.isFinite || sourceStart < 0 || sourceStart > maxSourceStart)
        }.padding(12).background(Studio.raised, in: RoundedRectangle(cornerRadius: 12))
            .disabled(model.selectedIsLocked || model.isBusy)
            .onChange(of: clip.audio) { _, _ in volume = Double(clip.audioSettings.volume) }
            .onChange(of: clip.sourceStart) { _, value in sourceStart = value.seconds }
    }
}
