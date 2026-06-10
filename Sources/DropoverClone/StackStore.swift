import Foundation
import Combine

final class StackStore: ObservableObject {
    static let shared = StackStore()

    @Published var stacks: [Stack] = []
    @Published var activeStackID: UUID?

    private let storageURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DropoverClone", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.storageURL = dir.appendingPathComponent("stacks.json")
        load()
        if stacks.isEmpty {
            let s = Stack(name: "Default")
            stacks.append(s)
            activeStackID = s.id
            save()
        } else if activeStackID == nil {
            activeStackID = stacks.first?.id
        }
    }

    var activeStack: Stack? {
        guard let id = activeStackID else { return nil }
        return stacks.first { $0.id == id }
    }

    var totalItemCount: Int {
        stacks.reduce(0) { $0 + $1.items.count }
    }

    /// Persist a refreshed bookmark after a stale-resolve (file was moved).
    func refreshBookmark(itemID: UUID, to data: Data) {
        for sIdx in stacks.indices {
            if let iIdx = stacks[sIdx].items.firstIndex(where: { $0.id == itemID }) {
                stacks[sIdx].items[iIdx].bookmark = data
                save()
                return
            }
        }
    }

    func addItem(_ item: ShelfItem, toStack stackID: UUID? = nil) {
        let target = stackID ?? activeStackID
        guard let target,
              let idx = stacks.firstIndex(where: { $0.id == target }) else { return }
        stacks[idx].items.append(item)
        save()
    }

    func removeItem(_ itemID: UUID, fromStack stackID: UUID) {
        guard let sIdx = stacks.firstIndex(where: { $0.id == stackID }) else { return }
        stacks[sIdx].items.removeAll { $0.id == itemID }
        save()
    }

    func clearStack(_ stackID: UUID) {
        guard let sIdx = stacks.firstIndex(where: { $0.id == stackID }) else { return }
        stacks[sIdx].items.removeAll()
        save()
    }

    func addStack(named name: String) {
        let s = Stack(name: name)
        stacks.append(s)
        activeStackID = s.id
        save()
    }

    func deleteStack(_ id: UUID) {
        stacks.removeAll { $0.id == id }
        if activeStackID == id { activeStackID = stacks.first?.id }
        if stacks.isEmpty {
            let s = Stack(name: "Default")
            stacks.append(s)
            activeStackID = s.id
        }
        save()
    }

    func renameStack(_ id: UUID, to newName: String) {
        guard let idx = stacks.firstIndex(where: { $0.id == id }) else { return }
        stacks[idx].name = newName
        save()
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(StateBlob(stacks: stacks, activeStackID: activeStackID))
            try data.write(to: storageURL, options: .atomic)
        } catch {
            NSLog("StackStore save failed: \(error)")
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let blob = try? JSONDecoder().decode(StateBlob.self, from: data) else { return }
        stacks = blob.stacks
        activeStackID = blob.activeStackID
    }

    private struct StateBlob: Codable {
        var stacks: [Stack]
        var activeStackID: UUID?
    }
}
