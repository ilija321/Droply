import AppKit
import Combine
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var shelfWindow: ShelfWindow?
    private var statusItem: NSStatusItem?
    private var dragMonitor: DragMonitor?
    private var hotkeyGlobal: Any?
    private var hotkeyLocal: Any?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupShelfWindow()
        setupDragMonitor()
        setupHotkey()
        observeStore()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "tray.full", accessibilityDescription: "Dropover Clone")
            button.imagePosition = .imageLeading
        }
        statusItem = item
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Shelf  ⌥⌘V", action: #selector(toggleShelf), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Hide Shelf", action: #selector(hideShelf), keyEquivalent: "").target = self
        menu.addItem(.separator())

        let launch = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launch.target = self
        launch.state = launchAtLoginEnabled ? .on : .off
        menu.addItem(launch)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu
    }

    /// Reflect total item count as a small badge on the menu-bar button.
    private func observeStore() {
        StackStore.shared.$stacks
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateBadge() }
            .store(in: &cancellables)
        updateBadge()
    }

    private func updateBadge() {
        let count = StackStore.shared.totalItemCount
        statusItem?.button?.title = count > 0 ? " \(count)" : ""
    }

    private func setupShelfWindow() {
        let w = ShelfWindow()
        shelfWindow = w
        ShelfState.shared.requestHide = { [weak w] in w?.animateHide() }
        // Hidden on launch — only summon via wiggle, hotkey, or menu bar.
    }

    private func setupDragMonitor() {
        let m = DragMonitor()
        m.onWiggle = { [weak self] cursor in
            DispatchQueue.main.async { self?.summonShelf(at: cursor) }
        }
        // No auto-hide: the shelf stays open until the user closes it (close
        // button, menu, or ⌥⌘V). Auto-hiding mid-add was dropping the panel.
        m.start()
        dragMonitor = m
    }

    /// Global summon hotkey: ⌥⌘V. Works app-wide (needs Accessibility, same
    /// permission the drag monitor already relies on).
    private func setupHotkey() {
        let matches: (NSEvent) -> Bool = { e in
            e.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command, .option]
                && e.charactersIgnoringModifiers?.lowercased() == "v"
        }
        hotkeyGlobal = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard matches(e) else { return }
            DispatchQueue.main.async { self?.toggleShelf() }
        }
        hotkeyLocal = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard matches(e) else { return e }
            self?.toggleShelf()
            return nil
        }
    }

    private func summonShelf(at cursor: NSPoint) {
        guard let w = shelfWindow else { return }
        w.animateShow(near: cursor)
    }

    @objc private func toggleShelf() {
        guard let w = shelfWindow else { return }
        if w.isVisible {
            w.animateHide()
        } else {
            summonShelf(at: NSEvent.mouseLocation)
        }
    }

    @objc private func hideShelf() {
        shelfWindow?.animateHide()
    }

    // MARK: - Launch at login

    private var launchAtLoginEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @objc private func toggleLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Launch-at-login toggle failed: \(error)")
        }
        rebuildMenu()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
