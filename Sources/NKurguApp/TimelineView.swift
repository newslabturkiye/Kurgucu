import SwiftUI
import AppKit
import KurguCore
import KurguEditing

struct TimelinePanel: View {
    @Bindable var model: WorkspaceModel
    @State private var viewportWidth: Double = 1000
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text("ZAMAN ÇİZELGESİ").font(.system(size: 10, weight: .semibold)).tracking(1)
                Divider().frame(height: 16)
                Button { model.cutTool = false } label: { Image(systemName: "cursorarrow").foregroundStyle(model.cutTool ? Color.secondary : Studio.accent) }.help("Seçim (V)")
                Button { model.cutTool = true } label: { StudioIcon(glyph: .cut, size: 22).padding(3).background(model.cutTool ? Studio.accent.opacity(0.22) : .clear, in: RoundedRectangle(cornerRadius: 6)) }.help("Kes (C)")
                Button(action: model.undo) { Image(systemName: "arrow.uturn.backward") }.disabled(!model.session.canUndo)
                Button(action: model.redo) { Image(systemName: "arrow.uturn.forward") }.disabled(!model.session.canRedo)
                Button { model.snappingEnabled.toggle() } label: {
                    Image(systemName: "dot.scope").foregroundStyle(model.snappingEnabled ? Studio.accent : .secondary)
                }.help("Otomatik hizalama (N); sürüklerken Option ile geçici kapat")
                Menu { Button("Video izi") { model.addTrack(.video) }; Button("Ses izi") { model.addTrack(.audio) } } label: { Label("İz", systemImage: "plus") }
                Spacer()
                Button("Sığdır") { model.zoom = max(1, min(180, (viewportWidth - 140) / max(1, model.timelineEnd + 1))) }
                    .help("Tüm kurguyu görünür alana sığdır").font(.system(size: 11))
                Image(systemName: "minus.magnifyingglass").foregroundStyle(.secondary)
                Slider(value: $model.zoom, in: 1...180).frame(width: 100).accessibilityLabel("Timeline yakınlaştırma")
                Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary)
            }.buttonStyle(.plain).padding(.horizontal, 16).frame(height: 42)
            Divider()
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    TimelineSurface(model: model, playhead: model.preview.currentTime.seconds)
                        .frame(width: max(geometry.size.width, 120 + (model.timelineEnd + max(2, model.timelineEnd * 0.05)) * model.zoom),
                               height: max(geometry.size.height, 32 + Double(model.sequence.tracks.count) * 66))
                }.onAppear { viewportWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, width in viewportWidth = width }
            }
            HStack { Text("V Seçim  ·  C Kes  ·  J / K / L Oynatma  ·  ← / → Kare  ·  Space Oynat"); Spacer(); Text("⇧Tık: çoklu seçim · Sürükle: taşı · Kenar: kısalt") }
                .font(.system(size: 10)).foregroundStyle(.tertiary).padding(.horizontal, 16).frame(height: 24)
        }
    }
}

struct TimelineSurface: NSViewRepresentable {
    let model: WorkspaceModel
    let playhead: Double
    func makeNSView(context: Context) -> TimelineCanvas { let view = TimelineCanvas(); view.model = model; return view }
    func updateNSView(_ view: TimelineCanvas, context: Context) {
        view.model = model; view.playhead = playhead; view.needsDisplay = true
    }
}

final class TimelineCanvas: NSView {
    var model: WorkspaceModel!
    var playhead: Double = 0
    private var scrubbing = false
    private enum DragMode { case move, leading, trailing }
    private struct DragState {
        let clip: Clip
        let trackID: UUID
        let origin: NSPoint
        let mode: DragMode
        let snapshot: Project
        var command: EditCommand?
        var rect: NSRect?
        var guide: MediaTime?
        var valid = false
    }
    private var dragState: DragState?
    override init(frame: NSRect) {
        super.init(frame: frame); registerForDraggedTypes([.string])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation { .copy }
    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation { .copy }
    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool { true }
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let value = sender.draggingPasteboard.string(forType: .string), let id = UUID(uuidString: value) else { return false }
        let point = convert(sender.draggingLocation, from: nil)
        let row = Int(floor((point.y - 32) / 66))
        guard point.x >= labelWidth, model.sequence.tracks.indices.contains(row) else { return false }
        return model.dropAsset(id, trackID: model.sequence.tracks[row].id, seconds: (point.x - labelWidth) / model.zoom)
    }
    override var isFlipped: Bool { true }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
    override var acceptsFirstResponder: Bool { true }
    private let labelWidth: Double = 120
    override func draw(_ dirtyRect: NSRect) {
        Studio.canvasColor.setFill(); dirtyRect.fill()
        let scale = model.zoom
        let text: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular), .foregroundColor: NSColor.secondaryLabelColor]
        let step = max(1, Int(80 / scale))
        let first = max(0, Int((visibleRect.minX - labelWidth) / scale) / step * step)
        let last = Int(max(0, visibleRect.maxX - labelWidth) / scale) + step
        for second in stride(from: first, through: last, by: step) {
            let x = labelWidth + Double(second) * scale
            NSColor.labelColor.withAlphaComponent(0.08).setFill()
            NSRect(x: x, y: 24, width: 1, height: bounds.height - 24).fill()
            ("\(second)s" as NSString).draw(at: NSPoint(x: x + 4, y: 8), withAttributes: text)
        }
        for (index, track) in model.sequence.tracks.enumerated() {
            let y = 32.0 + Double(index) * 66
            NSColor.labelColor.withAlphaComponent(0.05).setFill(); NSRect(x: 0, y: y, width: bounds.width, height: 1).fill()
            if track.id == model.selectedTrack { Studio.accentColor.withAlphaComponent(0.1).setFill(); NSRect(x: 0, y: y, width: 116, height: 66).fill() }
            let titleStyle = NSMutableParagraphStyle(); titleStyle.lineBreakMode = .byTruncatingTail
            (track.name as NSString).draw(in: NSRect(x: 12, y: y + 8, width: 98, height: 17), withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: NSColor.labelColor, .paragraphStyle: titleStyle])
            for (symbol, x, active) in [(track.isLocked ? "lock.fill" : "lock.open", 14.0, track.isLocked),
                                        (track.audioSettings.isMuted ? "speaker.slash.fill" : "speaker.wave.2", 47.0, track.audioSettings.isMuted)] {
                let buttonRect = NSRect(x: x - 4, y: y + 32, width: 26, height: 23)
                (active ? Studio.accentColor.withAlphaComponent(0.18) : NSColor.labelColor.withAlphaComponent(0.05)).setFill()
                NSBezierPath(roundedRect: buttonRect, xRadius: 5, yRadius: 5).fill()
                if let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(.init(paletteColors: [active ? Studio.accentColor : .secondaryLabelColor])) {
                    icon.draw(in: NSRect(x: x, y: y + 36, width: 16, height: 15), from: .zero, operation: .sourceOver, fraction: 0.85, respectFlipped: true, hints: nil)
                }
            }
            ("\(Int((track.audioSettings.volume * 100).rounded()))%" as NSString).draw(at: NSPoint(x: 79, y: y + 39), withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular), .foregroundColor: NSColor.secondaryLabelColor])
            for clip in track.clips {
                let rect = NSRect(x: labelWidth + clip.start.seconds * scale, y: y + 8, width: max(2, clip.duration.seconds * scale), height: 49)
                guard rect.intersects(visibleRect) else { continue }
                let selected = clip.id == model.selectedClip || model.selectedClips.contains(clip.id)
                let color = track.kind == .audio ? NSColor(srgbRed: 0.45, green: 0.32, blue: 0.12, alpha: 1) : NSColor(srgbRed: 0.48, green: 0.13, blue: 0.18, alpha: 1)
                color.withAlphaComponent(selected ? 1 : 0.90).setFill()
                let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6); path.fill()
                if let image = model.thumbnails[clip.assetID], rect.width > 24 {
                    NSGraphicsContext.saveGraphicsState()
                    path.addClip()
                    let tileWidth = 80.0
                    let left = max(rect.minX, visibleRect.minX)
                    let right = min(rect.maxX, visibleRect.maxX)
                    let firstTile = Int((left - rect.minX) / tileWidth)
                    let lastTile = Int((right - rect.minX) / tileWidth)
                    for index in firstTile...lastTile {
                        let sourceTime = clip.sourceStart.seconds + Double(index) * tileWidth / scale
                        let duration = model.project.assets.first { $0.id == clip.assetID }?.duration.seconds ?? 1
                        let strip = model.filmstrips[clip.assetID] ?? [image]
                        let frame = strip[min(strip.count - 1, max(0, Int(sourceTime / max(0.001, duration) * Double(strip.count))))]
                        frame.draw(in: NSRect(x: rect.minX + Double(index) * tileWidth, y: rect.minY + 18, width: tileWidth, height: 31),
                                   from: .zero, operation: .sourceOver, fraction: 0.65, respectFlipped: true, hints: nil)
                    }
                    NSColor.black.withAlphaComponent(0.5).setFill()
                    NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: 19).fill()
                    NSGraphicsContext.restoreGraphicsState()
                }
                if let wave = model.waveforms[clip.assetID], !wave.peaks.isEmpty {
                    NSGraphicsContext.saveGraphicsState(); path.addClip()
                    Studio.accentColor.withAlphaComponent(0.9).setStroke()
                    let waveform = NSBezierPath(); waveform.lineWidth = 1
                    let left = max(rect.minX, visibleRect.minX), right = min(rect.maxX, visibleRect.maxX)
                    for x in stride(from: left, to: right, by: 2) {
                        let sourceTime = clip.sourceStart.seconds + (x - rect.minX) / scale
                        let bin = min(wave.peaks.count - 1, max(0, Int(sourceTime / wave.secondsPerBin)))
                        let height = Double(min(1, wave.peaks[bin])) * 14
                        waveform.move(to: NSPoint(x: x, y: rect.midY + 8 - height)); waveform.line(to: NSPoint(x: x, y: rect.midY + 8 + height))
                    }
                    waveform.stroke(); NSGraphicsContext.restoreGraphicsState()
                }
                (selected ? Studio.accentColor : color.withAlphaComponent(0.7)).setStroke(); path.lineWidth = selected ? 2 : 1; path.stroke()
                if selected && rect.width > 20 {
                    NSColor.white.withAlphaComponent(0.8).setFill()
                    NSRect(x: rect.minX + 3, y: rect.minY + 20, width: 2, height: 12).fill()
                    NSRect(x: rect.maxX - 5, y: rect.minY + 20, width: 2, height: 12).fill()
                }
                let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingTail
                (model.assetName(clip.assetID) as NSString).draw(in: rect.insetBy(dx: 8, dy: 3), withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white, .paragraphStyle: paragraph])
            }
        }
        if let drag = dragState, let rect = drag.rect {
            let color = drag.valid ? Studio.accentColor : NSColor.systemOrange
            color.withAlphaComponent(0.2).setFill()
            let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
            path.fill(); color.setStroke(); path.lineWidth = 2; path.setLineDash([4, 3], count: 2, phase: 0); path.stroke()
            if let guide = drag.guide {
                color.setFill()
                NSRect(x: labelWidth + guide.seconds * scale, y: 24, width: 1, height: bounds.height - 24).fill()
            }
        }
        let x = labelWidth + playhead * scale
        Studio.accentColor.setFill(); NSRect(x: x, y: 20, width: 1.5, height: bounds.height - 20).fill()
        let marker = NSBezierPath(); marker.move(to: NSPoint(x: x - 5, y: 13)); marker.line(to: NSPoint(x: x + 6, y: 13)); marker.line(to: NSPoint(x: x, y: 22)); marker.close(); marker.fill()
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        dragState = nil
        let p = convert(event.locationInWindow, from: nil)
        if p.y < 32 && p.x >= labelWidth { scrubbing = true; model.seek((p.x - labelWidth) / model.zoom, precise: false); return }
        let index = Int((p.y - 32) / 66)
        guard p.y >= 32, model.sequence.tracks.indices.contains(index) else { return }
        let track = model.sequence.tracks[index]; model.selectedTrack = track.id
        if p.x < labelWidth {
            model.selectedClip = nil; model.selectedClips = []
            let localY = p.y - (32 + Double(index) * 66)
            if (32...55).contains(localY) {
                if (10...36).contains(p.x) { model.toggleLock(track) }
                else if (43...69).contains(p.x), !track.isLocked { model.toggleMute(track) }
            }
            needsDisplay = true; return
        }
        let seconds = (p.x - labelWidth) / model.zoom
        let clip = track.clips.first { seconds >= $0.start.seconds && seconds < ((try? $0.end().seconds) ?? 0) }
        if event.modifierFlags.contains(.shift), let clip {
            if model.selectedClips.contains(clip.id) { model.selectedClips.remove(clip.id) } else { model.selectedClips.insert(clip.id) }
            model.selectedClip = clip.id; needsDisplay = true; return
        }
        if let clip, !model.selectedClips.contains(clip.id) { model.selectedClips = [clip.id] }
        model.selectedClip = clip?.id
        if clip == nil { model.selectedClips = [] }
        if let clip, model.cutTool, !track.isLocked { model.split(clipID: clip.id, seconds: seconds) }
        else if let clip, !track.isLocked, p.x >= labelWidth {
            model.preview.pause()
            let left = labelWidth + clip.start.seconds * model.zoom
            let right = labelWidth + ((try? clip.end().seconds) ?? 0) * model.zoom
            let handle = min(7.0, max(2, (right - left) / 4))
            let mode: DragMode = abs(p.x - left) <= handle ? .leading : (abs(p.x - right) <= handle ? .trailing : .move)
            dragState = DragState(clip: clip, trackID: track.id, origin: p, mode: mode, snapshot: model.project)
        }
        needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if scrubbing { model.seek((p.x - labelWidth) / model.zoom, precise: false); return }
        updateDrag(at: p, disableSnap: event.modifierFlags.contains(.option))
        autoscroll(with: event)
    }
    private func updateDrag(at p: NSPoint, disableSnap: Bool) {
        guard var drag = dragState, model.project == drag.snapshot else { return }
        guard abs(p.x - drag.origin.x) + abs(p.y - drag.origin.y) >= 3 else {
            drag.command = nil; drag.rect = nil; drag.guide = nil; drag.valid = false
            dragState = drag; needsDisplay = true; return
        }
        do {
            let delta = (p.x - drag.origin.x) / model.zoom
            let end = try drag.clip.end()
            var start = drag.clip.start
            var finish = end
            var row = model.sequence.tracks.firstIndex { $0.id == drag.trackID }!
            var targets: [MediaTime] = [.zero, model.preview.currentTime]
            for clip in model.sequence.tracks.flatMap(\.clips) where clip.id != drag.clip.id {
                targets.append(clip.start); targets.append(try clip.end())
            }
            let tolerance = try MediaTime(Int64((8 / model.zoom * 60000).rounded()), timescale: 60000)
            func snapped(_ time: MediaTime, duration: MediaTime) throws -> SnapResult {
                try Snapping.move(start: time, duration: duration, targets: model.snappingEnabled && !disableSnap ? targets : [], tolerance: tolerance)
            }
            switch drag.mode {
            case .move:
                guard let proposed = model.quantized(max(0, start.seconds + delta)) else { return }
                let snap = try snapped(proposed, duration: drag.clip.duration)
                start = snap.start; finish = try start.adding(drag.clip.duration); drag.guide = snap.guide
                row = Int(floor((p.y - 32) / 66))
                guard model.sequence.tracks.indices.contains(row) else {
                    drag.command = nil; drag.valid = false; dragState = drag; needsDisplay = true; return
                }
                if model.selectedClips.count > 1 {
                    guard model.sequence.tracks[row].id == drag.trackID else {
                        drag.command = nil; drag.valid = false; dragState = drag; needsDisplay = true; return
                    }
                    drag.command = .moveSelection(clipIDs: model.selectedClips, delta: try start.subtracting(drag.clip.start))
                } else { drag.command = .move(clipID: drag.clip.id, toTrackID: model.sequence.tracks[row].id, start: start) }
            case .leading:
                guard let proposed = model.quantized(max(start.seconds, min(end.seconds, start.seconds + delta))) else { return }
                let snap = try snapped(proposed, duration: .zero)
                start = max(drag.clip.start, min(snap.start, end)); drag.guide = start == snap.start ? snap.guide : nil
                drag.command = .trim(clipID: drag.clip.id, start: start, end: end)
            case .trailing:
                guard let proposed = model.quantized(max(start.seconds, min(end.seconds, end.seconds + delta))) else { return }
                let snap = try snapped(proposed, duration: .zero)
                finish = min(end, max(snap.start, start)); drag.guide = finish == snap.start ? snap.guide : nil
                drag.command = .trim(clipID: drag.clip.id, start: start, end: finish)
            }
            drag.rect = NSRect(x: labelWidth + start.seconds * model.zoom, y: 40 + Double(row) * 66,
                               width: max(2, (finish.seconds - start.seconds) * model.zoom), height: 49)
            if let command = drag.command {
                var trial = model.session
                do { try trial.execute(command); drag.valid = true } catch { drag.valid = false }
            }
        } catch { drag.valid = false }
        dragState = drag; needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if scrubbing { scrubbing = false; model.seek((p.x - labelWidth) / model.zoom); return }
        updateDrag(at: p, disableSnap: event.modifierFlags.contains(.option))
        if let drag = dragState, drag.snapshot == model.project, let command = drag.command {
            if drag.valid { model.apply(command) }
            else { model.status = "Yerleştirilemedi: iz türü, kilit veya klip çakışmasını kontrol edin." }
        }
        dragState = nil; needsDisplay = true
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { dragState = nil; scrubbing = false; needsDisplay = true; return }
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { super.keyDown(with: event); return }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "v": model.cutTool = false
        case "c": model.cutTool = true
        case "n": model.snappingEnabled.toggle()
        case " ": model.togglePlayback()
        case "k": model.preview.pause()
        case "l": model.preview.play()
        case "j":
            if model.preview.player.currentItem?.canPlayReverse == true { model.preview.player.rate = -1 }
            else { model.seek(model.preview.currentTime.seconds - model.sequence.frameDuration.seconds) }
        default:
            if event.keyCode == 51 { model.removeSelected(ripple: event.modifierFlags.contains(.shift)) }
            else if event.keyCode == 123 { model.seek(model.preview.currentTime.seconds - model.sequence.frameDuration.seconds) }
            else if event.keyCode == 124 { model.seek(model.preview.currentTime.seconds + model.sequence.frameDuration.seconds) }
            else { super.keyDown(with: event) }
        }
    }
}
