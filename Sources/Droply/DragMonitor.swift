import AppKit

/// Detects a "wiggle while dragging file" gesture (Droply-style summon).
/// Tracks horizontal direction reversals during a left-mouse drag while the
/// drag pasteboard carries a file URL. Fires `onWiggle(cursorPoint)` when the
/// user reverses direction enough times within a short window.
final class DragMonitor {
    var onWiggle: ((NSPoint) -> Void)?
    var onDragEnd: (() -> Void)?

    private var localDrag: Any?
    private var globalDrag: Any?
    private var localUp: Any?
    private var globalUp: Any?

    // Wiggle state
    private var samples: [(t: TimeInterval, x: CGFloat)] = []
    private var reversalCount: Int = 0
    private var lastDir: Int = 0           // -1, 0, +1
    private var lastFireTime: TimeInterval = 0
    private var dragActive = false

    // Tunables
    private let windowSeconds: TimeInterval = 0.6
    private let minReversalsToFire: Int = 3
    private let minSegmentDX: CGFloat = 12     // ignore micro-jitter
    private let refireCooldown: TimeInterval = 1.5

    func start() {
        let dragMask: NSEvent.EventTypeMask = [.leftMouseDragged]
        let upMask: NSEvent.EventTypeMask = [.leftMouseUp]

        globalDrag = NSEvent.addGlobalMonitorForEvents(matching: dragMask) { [weak self] e in
            self?.handleDrag(e)
        }
        localDrag = NSEvent.addLocalMonitorForEvents(matching: dragMask) { [weak self] e in
            self?.handleDrag(e); return e
        }
        globalUp = NSEvent.addGlobalMonitorForEvents(matching: upMask) { [weak self] _ in
            self?.handleUp()
        }
        localUp = NSEvent.addLocalMonitorForEvents(matching: upMask) { [weak self] e in
            self?.handleUp(); return e
        }
    }

    func stop() {
        for m in [localDrag, globalDrag, localUp, globalUp].compactMap({ $0 }) {
            NSEvent.removeMonitor(m)
        }
        localDrag = nil; globalDrag = nil; localUp = nil; globalUp = nil
    }

    private func pasteboardHasFile() -> Bool {
        let pb = NSPasteboard(name: .drag)
        guard let types = pb.types else { return false }
        return types.contains(.fileURL)
            || types.contains(NSPasteboard.PasteboardType("public.file-url"))
    }

    private func handleDrag(_ event: NSEvent) {
        guard pasteboardHasFile() else { return }
        dragActive = true

        let now = event.timestamp
        let x = NSEvent.mouseLocation.x

        // Drop old samples outside window
        samples.append((now, x))
        samples = samples.filter { now - $0.t <= windowSeconds }

        // Need at least 2 samples to compute direction
        guard samples.count >= 2 else { return }

        // Walk segments looking for direction reversals across minSegmentDX
        var dir = lastDir
        var prevX = samples[0].x
        var localReversals = 0
        var accDX: CGFloat = 0
        for s in samples.dropFirst() {
            let dx = s.x - prevX
            accDX += dx
            if abs(accDX) >= minSegmentDX {
                let newDir: Int = accDX > 0 ? 1 : -1
                if dir != 0 && newDir != dir {
                    localReversals += 1
                }
                dir = newDir
                accDX = 0
            }
            prevX = s.x
        }
        reversalCount = localReversals
        lastDir = dir

        if reversalCount >= minReversalsToFire,
           now - lastFireTime > refireCooldown {
            lastFireTime = now
            let cursor = NSEvent.mouseLocation
            samples.removeAll()
            reversalCount = 0
            onWiggle?(cursor)
        }
    }

    private func handleUp() {
        if dragActive {
            dragActive = false
            samples.removeAll()
            reversalCount = 0
            lastDir = 0
            onDragEnd?()
        }
    }
}
