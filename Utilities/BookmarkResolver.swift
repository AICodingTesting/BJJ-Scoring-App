import Foundation
import Dispatch

/// A no-op iOS version of BookmarkResolver.
/// On macOS, this would handle persistent bookmarks with security-scoped URLs.
/// On iOS, sandboxed access makes that unnecessary, so this version just returns the URL directly.
struct BookmarkResolver {

    struct ResolvedBookmark {
        let url: URL
        let isStale: Bool
    }

    static func resolveBookmark(from data: Data) async throws -> ResolvedBookmark {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: nil)
                    continuation.resume(returning: ResolvedBookmark(url: url, isStale: false))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func bookmark(for url: URL) -> Data? {
        return try? url.bookmarkData()
    }

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

