import Foundation
import AppKit

struct ShelfItem: Codable, Identifiable, Equatable {
    let id: UUID
    var bookmark: Data           // security-scoped bookmark
    var displayName: String
    var addedAt: Date
    var fileSize: Int64?         // bytes; nil = unknown/dir (optional for old-JSON decode)
    var isDirectory: Bool?

    init(url: URL) throws {
        self.id = UUID()
        self.bookmark = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        self.displayName = url.lastPathComponent
        self.addedAt = Date()

        let vals = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
        self.fileSize = vals?.fileSize.map(Int64.init)
        self.isDirectory = vals?.isDirectory
    }

    /// Resolve to a usable URL. When the bookmark goes stale (file moved),
    /// `staleBookmark` is filled so the store can persist a refreshed one.
    func resolveURL(staleBookmark: inout Data?) -> URL? {
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        if stale {
            _ = url.startAccessingSecurityScopedResource()
            staleBookmark = try? url.bookmarkData(options: [.withSecurityScope])
            url.stopAccessingSecurityScopedResource()
        }
        return url
    }

    func resolveURL() -> URL? {
        var ignored: Data?
        return resolveURL(staleBookmark: &ignored)
    }

    /// Human-readable size, e.g. "2.4 MB". Empty for directories/unknown.
    var sizeLabel: String {
        guard let fileSize, isDirectory != true else { return "" }
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

struct Stack: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var items: [ShelfItem] = []
    var createdAt: Date = Date()
}
