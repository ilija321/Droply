import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ShelfRootView: View {
    @EnvironmentObject var store: StackStore
    @EnvironmentObject var shelfState: ShelfState
    @State private var showingNewStackPrompt = false
    @State private var newStackName = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.18)
            content
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.activeStackID)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.activeStack?.items)
        }
        .background(
            VisualEffectBlur()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Header (close + stack tabs + actions)

    private var header: some View {
        HStack(spacing: 6) {
            CloseButton { shelfState.requestHide?() }
                .padding(.trailing, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(store.stacks) { stack in
                        StackTab(stack: stack)
                    }
                    Button {
                        showingNewStackPrompt = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.borderless)
                    .help("New stack")
                }
                .padding(.vertical, 1)
            }

            Spacer(minLength: 4)

            actionButton("pin", systemName: shelfState.isPinned ? "pin.fill" : "pin",
                         help: shelfState.isPinned ? "Unpin (allow auto-hide)" : "Pin (keep open)") {
                shelfState.isPinned.toggle()
            }
            .foregroundStyle(shelfState.isPinned ? Color.accentColor : Color.primary)

            actionButton("copy", systemName: "doc.on.doc", help: "Copy all to clipboard") {
                copyAll()
            }

            actionButton("share", systemName: "square.and.arrow.up", help: "Share items") {
                shareActiveStack()
            }

            Menu {
                if let active = store.activeStack {
                    Button("Rename '\(active.name)'…") { renameActive() }
                    Button("Clear Items") { store.clearStack(active.id) }
                    Button("Delete Stack", role: .destructive) { store.deleteStack(active.id) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 22)
            .help("More")
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .sheet(isPresented: $showingNewStackPrompt) {
            newStackSheet
        }
    }

    private func actionButton(_ id: String, systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private var newStackSheet: some View {
        VStack(spacing: 12) {
            Text("New Stack").font(.headline)
            TextField("Stack name", text: $newStackName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
            HStack {
                Button("Cancel") {
                    showingNewStackPrompt = false
                    newStackName = ""
                }
                Button("Create") {
                    let name = newStackName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { store.addStack(named: name) }
                    showingNewStackPrompt = false
                    newStackName = ""
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    private func renameActive() {
        guard let active = store.activeStack else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Stack"
        alert.informativeText = "New name for '\(active.name)':"
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        input.stringValue = active.name
        alert.accessoryView = input
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            store.renameStack(active.id, to: input.stringValue)
        }
    }

    private func shareActiveStack() {
        guard let stack = store.activeStack else { return }
        let urls = stack.items.compactMap { $0.resolveURL() }
        guard !urls.isEmpty else { return }
        let picker = NSSharingServicePicker(items: urls)
        if let window = NSApp.keyWindow, let contentView = window.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
    }

    private func copyAll() {
        guard let stack = store.activeStack else { return }
        let urls = stack.items.compactMap { $0.resolveURL() as NSURL? }
        guard !urls.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(urls)
    }

    @ViewBuilder
    private var content: some View {
        if let stack = store.activeStack {
            if stack.items.isEmpty {
                DropTargetArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 10)], spacing: 10) {
                        ForEach(stack.items) { item in
                            ItemTile(item: item, stackID: stack.id)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.6).combined(with: .opacity),
                                    removal: .scale(scale: 0.4).combined(with: .opacity)
                                ))
                        }
                    }
                    .padding(12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())   // empty grid space stays drop-hittable
                .modifier(FileDropReceiver())
            }
        } else {
            Text("No stack").foregroundStyle(.secondary)
        }
    }
}

// MARK: - Close button (mac traffic-light style)

struct CloseButton: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.38, blue: 0.35))
                    .frame(width: 12, height: 12)
                if hovering {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.55))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Close shelf")
    }
}

// MARK: - Whole-area file drop receiver

/// Accepts file drops over an entire region (used for the populated grid so the
/// user can drop anywhere, not onto a tiny strip). Highlights on target.
struct FileDropReceiver: ViewModifier {
    @EnvironmentObject var store: StackStore
    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isTargeted ? Color.accentColor.opacity(0.10) : Color.clear)
                    .padding(6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: isTargeted ? 2 : 0)
                    .padding(6)
            )
            .animation(.easeOut(duration: 0.15), value: isTargeted)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url {
                            DispatchQueue.main.async {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    if let item = try? ShelfItem(url: url) {
                                        store.addItem(item)
                                    }
                                }
                            }
                        }
                    }
                }
                return true
            }
    }
}

// MARK: - Stack tab pill

struct StackTab: View {
    let stack: Stack
    @EnvironmentObject var store: StackStore
    @State private var hovering = false

    private var isActive: Bool { stack.id == store.activeStackID }

    var body: some View {
        Button {
            store.activeStackID = stack.id
        } label: {
            HStack(spacing: 5) {
                Text(stack.name)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
                if !stack.items.isEmpty {
                    Text("\(stack.items.count)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(isActive ? Color.white.opacity(0.25) : Color.secondary.opacity(0.18))
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(
                    isActive ? Color.accentColor.opacity(0.85)
                    : (hovering ? Color.secondary.opacity(0.18) : Color.secondary.opacity(0.10))
                )
            )
            .foregroundStyle(isActive ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Rename…") { renameStack() }
            Button("Clear Items") { store.clearStack(stack.id) }
            Button("Delete Stack", role: .destructive) { store.deleteStack(stack.id) }
        }
        .animation(.easeOut(duration: 0.15), value: isActive)
    }

    private func renameStack() {
        let alert = NSAlert()
        alert.messageText = "Rename Stack"
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        input.stringValue = stack.name
        alert.accessoryView = input
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            store.renameStack(stack.id, to: input.stringValue)
        }
    }
}

// MARK: - Drop target

struct DropTargetArea: View {
    var compact: Bool = false
    @EnvironmentObject var store: StackStore
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.4))
            VStack(spacing: 6) {
                Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "tray.and.arrow.down")
                    .font(.system(size: compact ? 14 : 30, weight: .light))
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                Text(compact ? "Drop here to add" : "Drop files to stash them")
                    .font(.system(size: compact ? 11 : 13))
                    .foregroundStyle(.secondary)
                if !compact {
                    Text("⌥⌘V to summon anywhere")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .opacity(compact ? 0.7 : 1)
        }
        .scaleEffect(isTargeted ? 1.03 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isTargeted)
        .padding(compact ? 0 : 12)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        DispatchQueue.main.async {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                if let item = try? ShelfItem(url: url) {
                                    store.addItem(item)
                                }
                            }
                        }
                    }
                }
            }
            return true
        }
    }
}

// MARK: - Item tile

struct ItemTile: View {
    let item: ShelfItem
    let stackID: UUID
    @EnvironmentObject var store: StackStore
    @State private var icon: NSImage?
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.10))
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(hovering ? 0.18 : 0.06), lineWidth: 1)
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                // AppKit drag overlay - intercepts drags without interfering with other events
                DragOverlay(url: item.resolveURL(), itemID: item.id, stackID: stackID)
                    .allowsHitTesting(true)

                // Hover remove button.
                if hovering {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    store.removeItem(item.id, fromStack: stackID)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white, Color.black.opacity(0.55))
                            }
                            .buttonStyle(.plain)
                            .padding(3)
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: 68, height: 68)

            Text(item.displayName)
                .font(.system(size: 10))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 84)

            if !item.sizeLabel.isEmpty {
                Text(item.sizeLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 84, height: 100)
        .scaleEffect(hovering ? 1.05 : 1)
        .shadow(color: .black.opacity(hovering ? 0.25 : 0), radius: 8, y: 3)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovering)
        .onAppear(perform: loadThumbnail)
        .contextMenu {
            Button("Open") { open() }
            Button("Reveal in Finder") { reveal() }
            Button("Copy Path") { copyPath() }
            Divider()
            Button("Remove", role: .destructive) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    store.removeItem(item.id, fromStack: stackID)
                }
            }
        }
    }

    private func loadThumbnail() {
        var staleData: Data?
        guard let url = item.resolveURL(staleBookmark: &staleData) else { return }
        if let staleData { store.refreshBookmark(itemID: item.id, to: staleData) }
        Thumbnailer.shared.thumbnail(for: url, side: 128) { img in
            self.icon = img
        }
    }

    private func open() {
        if let url = item.resolveURL() { NSWorkspace.shared.open(url) }
    }
    private func reveal() {
        if let url = item.resolveURL() { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }
    private func copyPath() {
        if let url = item.resolveURL() {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.path, forType: .string)
        }
    }
}

// MARK: - Blur backdrop

/// AppKit blur backdrop bridged into SwiftUI.
struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Drag overlay

/// Transparent AppKit overlay for intercepting drags without blocking other events.
struct DragOverlay: NSViewRepresentable {
    let url: URL?
    let itemID: UUID
    let stackID: UUID

    func makeNSView(context: Context) -> DragOverlayNSView {
        let v = DragOverlayNSView()
        v.url = url
        v.itemID = itemID
        v.stackID = stackID
        v.store = StackStore.shared
        return v
    }

    func updateNSView(_ nsView: DragOverlayNSView, context: Context) {
        nsView.url = url
        nsView.itemID = itemID
        nsView.stackID = stackID
    }
}

final class DragOverlayNSView: NSView, NSDraggingSource {
    var url: URL?
    var itemID: UUID?
    var stackID: UUID?
    var store: StackStore?
    private var isDragging = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Only intercept if we're about to drag (mouse is down and in bounds)
        if bounds.contains(point) {
            return self
        }
        return nil
    }

    override func mouseDown(with event: NSEvent) {
        // Don't start drag here, just mark that we're ready
    }

    override func mouseDragged(with event: NSEvent) {
        guard let url = url, !isDragging else { return }
        isDragging = true

        _ = url.startAccessingSecurityScopedResource()

        let pbItem = NSPasteboardItem()
        pbItem.setString(url.absoluteString, forType: .fileURL)

        let draggingItem = NSDraggingItem(pasteboardWriter: pbItem)
        let img = NSWorkspace.shared.icon(forFile: url.path)
        let size = NSSize(width: 64, height: 64)
        img.size = size

        let p = event.locationInWindow
        let originInView = convert(p, from: nil)
        draggingItem.setDraggingFrame(
            NSRect(x: originInView.x - size.width / 2,
                   y: originInView.y - size.height / 2,
                   width: size.width, height: size.height),
            contents: img
        )

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
    }

    // MARK: NSDraggingSource

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        switch context {
        case .outsideApplication: return [.copy, .link, .generic]
        case .withinApplication:  return [.copy]
        @unknown default:         return [.copy]
        }
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        // Delete item after successful drag
        if operation != .generic, let itemID = itemID, let stackID = stackID, let store = store {
            DispatchQueue.main.async {
                store.removeItem(itemID, fromStack: stackID)
            }
        }

        if let u = url {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                u.stopAccessingSecurityScopedResource()
            }
        }
        
        isDragging = false
    }
}
