import SwiftUI
import KurguCore
import KurguEditing

struct TrackInspector: View {
    let model: WorkspaceModel
    let track: Track
    @State private var name: String
    @State private var volume: Double
    init(model: WorkspaceModel, track: Track) {
        self.model = model; self.track = track
        _name = State(initialValue: track.name)
        _volume = State(initialValue: Double(track.audioSettings.volume))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                StudioIcon(glyph: track.kind == .video ? .media : .audio, size: 24)
                Text(track.kind == .video ? "VİDEO İZİ" : "SES İZİ").font(.system(size: 10, weight: .semibold)).tracking(1)
                Spacer()
                Text("\(track.clips.count) klip").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                TextField("İz adı", text: $name).textFieldStyle(.roundedBorder).disabled(track.isLocked)
                    .onSubmit { commitName() }.accessibilityLabel("İz adı")
                Button(action: commitName) { Image(systemName: "checkmark") }
                    .disabled(track.isLocked || name == track.name).help("İz adını uygula")
            }
            HStack(spacing: 8) {
                Button { model.toggleLock(track) } label: {
                    Label(track.isLocked ? "Kilidi aç" : "Kilitle", systemImage: track.isLocked ? "lock.fill" : "lock.open")
                }.buttonStyle(StudioButton())
                Button { model.toggleMute(track) } label: {
                    Label(track.audioSettings.isMuted ? "Sesi aç" : "Sustur", systemImage: track.audioSettings.isMuted ? "speaker.slash.fill" : "speaker.wave.2")
                }.buttonStyle(StudioButton()).disabled(track.isLocked)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("SES SEVİYESİ").font(.system(size: 9, weight: .semibold)).tracking(1)
                    Spacer()
                    Text("%\(Int((volume * 100).rounded()))").font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                Slider(value: $volume, in: 0...2, onEditingChanged: { editing in
                    if !editing { model.setVolume(track, volume: volume) }
                }).disabled(track.isLocked).accessibilityLabel("İz ses seviyesi")
                HStack { Text("0"); Spacer(); Text("100"); Spacer(); Text("200") }.font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                if track.audioSettings.isMuted {
                    Label("Bu iz sessiz", systemImage: "speaker.slash.fill").font(.caption).foregroundStyle(.orange)
                }
                Button("%100'e sıfırla") { volume = 1; model.setVolume(track, volume: 1) }.font(.caption).disabled(track.isLocked || volume == 1)
            }.padding(12).background(Studio.raised, in: RoundedRectangle(cornerRadius: 12))
            Button("Bu izdeki boşlukları kapat") { model.apply(.closeGaps(trackID: track.id)) }
                .disabled(track.isLocked || track.clips.isEmpty || model.isBusy)
            Text("Klipleri sıfırdan başlayarak yan yana getirir; diğer izleri ve yazıları taşımaz.").font(.caption).foregroundStyle(.secondary)
            Toggle("Master limiter · −0.18 dBFS", isOn: Binding(get: { model.sequence.limiter ?? false }, set: { model.apply(.setLimiter(sequenceID: model.sequence.id, enabled: $0)) })).font(.caption)
            Text("Limiter örnek tepelerini sınırlar; true-peak veya look-ahead içermez.").font(.system(size: 9)).foregroundStyle(.secondary)
            Text(track.isLocked ? "İz kilitli. Düzenleme yapmak için kilidi açın." : track.kind == .video ? "Ses ayarı bu izdeki videoların kaynak sesine uygulanır. Önizleme ve çıktıda aynıdır." : "Bu izdeki bütün ses kliplerine uygulanır. Önizleme ve çıktıda aynıdır.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(.horizontal, 16)
            .onChange(of: track.name) { _, value in name = value }
            .onChange(of: track.audioSettings.volume) { _, value in volume = Double(value) }
    }
    private func commitName() { model.apply(.renameTrack(trackID: track.id, name: name), rebuild: false) }
}
