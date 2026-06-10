import AppKit
import SwiftUI

final class ShelfWindow: NSPanel {
    private let defaultSize = NSSize(width: 360, height: 240)
    private var isAnimatingOut = false

    init() {
        let screen = NSScreen.main?.visibleFrame ?? .zero
        let rect = NSRect(
            x: screen.maxX - 360 - 24,
            y: screen.minY + 80,
            width: 360,
            height: 240
        )
        super.init(
            contentRect: rect,
            // Borderless: no titlebar inset, content sits flush to the rounded top.
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        self.isMovableByWindowBackground = true
        self.isMovable = true
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.hidesOnDeactivate = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.animationBehavior = .none      // we do custom fade

        let content = ShelfRootView()
            .environmentObject(StackStore.shared)
            .environmentObject(ShelfState.shared)
        let host = NSHostingView(rootView: content)
        host.wantsLayer = true
        // Clip the content layer to the rounded shape so the window's drop
        // shadow follows the rounded silhouette (no boxy corner halo).
        host.layer?.cornerRadius = 16
        host.layer?.cornerCurve = .continuous
        host.layer?.masksToBounds = true
        self.contentView = host
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func animateShow(near cursor: NSPoint) {
        isAnimatingOut = false
        let screen = NSScreen.screens.first(where: { NSMouseInRect(cursor, $0.frame, false) }) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        let size = self.frame.size == .zero ? defaultSize : self.frame.size
        var target = NSRect(origin: .zero, size: size)
        target.origin.x = min(max(cursor.x - size.width / 2, visible.minX + 8),
                              visible.maxX - size.width - 8)
        target.origin.y = min(max(cursor.y - size.height - 20, visible.minY + 8),
                              visible.maxY - size.height - 8)

        if isVisible {
            // Already visible — just slide to new position smoothly.
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                ctx.allowsImplicitAnimation = true
                self.animator().setFrame(target, display: true)
            }
            return
        }

        // Start: shifted down + transparent, then animate to target.
        var startFrame = target
        startFrame.origin.y -= 16
        self.setFrame(startFrame, display: false)
        self.alphaValue = 0
        self.orderFrontRegardless()
        self.invalidateShadow()   // recompute shadow against rounded content

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
            self.animator().setFrame(target, display: true)
        }
    }

    func animateHide(completion: (() -> Void)? = nil) {
        guard isVisible, !isAnimatingOut else { return }
        isAnimatingOut = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self = self else { return }
            self.orderOut(nil)
            self.alphaValue = 1
            self.isAnimatingOut = false
            completion?()
        })
    }
}
