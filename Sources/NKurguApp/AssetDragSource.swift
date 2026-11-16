import SwiftUI
import AppKit

struct AssetDragSource: NSViewRepresentable {
    let id: UUID
    let image: NSImage?
    let select: () -> Void
    func makeNSView(context: Context) -> AssetDragView { AssetDragView() }
    func updateNSView(_ view: AssetDragView, context: Context) { view.assetID = id; view.thumbnail = image; view.select = select }
}
final class AssetDragView: NSView, NSDraggingSource {
    var assetID = UUID()
    var thumbnail: NSImage?
    var select: () -> Void = {}
    private var start: NSPoint?
    override var isFlipped: Bool { true }
    override func mouseDown(with event: NSEvent) { start = convert(event.locationInWindow, from: nil); select() }
    override func mouseDragged(with event: NSEvent) {
        guard let start else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard hypot(point.x - start.x, point.y - start.y) > 3 else { return }
        self.start = nil
        let item = NSPasteboardItem(); item.setString(assetID.uuidString, forType: .string)
        let dragging = NSDraggingItem(pasteboardWriter: item)
        let image = thumbnail ?? NSImage(systemSymbolName: "film", accessibilityDescription: nil)!
        dragging.setDraggingFrame(NSRect(x: point.x - 48, y: point.y - 27, width: 96, height: 54), contents: image)
        beginDraggingSession(with: [dragging], event: event, source: self)
    }
    override func mouseUp(with event: NSEvent) { start = nil }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
}
