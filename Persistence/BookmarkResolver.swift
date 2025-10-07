import Foundation
import Dispatch

/// A safe cross-platform bookmark resolver.
/// On macOS, it uses security-scoped URLs; on iOS, it’s a simple URL decoder.
struct BookmarkResolver {

    struct ResolvedBookmark {
        let url: URL
        let isStale: Bool
    }

    enum Error: Swift.Error {
        case failedToResolveBookmark
    }

    /// Reconstructs a file URL from bookmark data.
    static func resolveBookmark(from data: Data) async throws -> ResolvedBookmark {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var isStale = false
                do {
                    let url = try URL(
                        resolvingBookmarkData: data,
                        bookmarkDataIsStale: &isStale
                    )
                    continuation.resume(returning: ResolvedBookmark(url: url, isStale: isStale))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Creates bookmark data from a URL.
    static func bookmark(for url: URL) -> Data? {
        return try? url.bookmarkData()
    }

    /// Resolves bookmark data and performs an operation on the resolved URL.
    static func withResolvedBookmark<T>(_ data: Data, perform block: (URL) throws -> T) async rethrows -> T? {
        let resolved = try await resolveBookmark(from: data)
        return try? block(resolved.url)
    }
}

#if os(macOS)
extension URL {
    func withSecurityScope<T>(_ block: (URL) throws -> T) rethrows -> T {
        _ = self.startAccessingSecurityScopedResource()
        defer { self.stopAccessingSecurityScopedResource() }
        return try block(self)
    }
}
#endif
