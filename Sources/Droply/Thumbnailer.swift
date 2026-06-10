import AppKit
import QuickLookThumbnailing

/// Generates real file previews (QuickLook) with a generic-icon fallback.
/// Results are cached in-memory keyed by path so re-renders are instant.
final class Thumbnailer {
    static let shared = Thumbnailer()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 512
    }

    /// Async best-representation thumbnail. Falls back to the Finder icon.
    func thumbnail(for url: URL, side: CGFloat = 128, completion: @escaping (NSImage) -> Void) {
        let key = "\(url.path)@\(Int(side))" as NSString
        if let cached = cache.object(forKey: key) {
            completion(cached)
            return
        }

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: side, height: side),
            scale: scale,
            representationTypes: .all
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] rep, _ in
            let image: NSImage
            if let rep {
                image = rep.nsImage
            } else {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: side, height: side)
                image = icon
            }
            self?.cache.setObject(image, forKey: key)
            DispatchQueue.main.async { completion(image) }
        }
    }
}
