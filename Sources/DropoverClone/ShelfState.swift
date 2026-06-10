import Foundation
import Combine

/// Shared UI/runtime state for the shelf, observed by the SwiftUI view,
/// the window controller, and the app delegate.
final class ShelfState: ObservableObject {
    static let shared = ShelfState()

    /// When pinned, the shelf will not auto-hide after a drag ends.
    @Published var isPinned = false

    /// Set by the app delegate so the SwiftUI close button can dismiss the panel.
    var requestHide: (() -> Void)?

    private init() {}
}
