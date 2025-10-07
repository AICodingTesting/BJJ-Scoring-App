import Foundation

/// A no-op iOS version of BookmarkResolver.
/// On macOS, this would handle persistent bookmarks with security-scoped URLs.
/// On iOS, sandboxed access makes that unnecessary, so this version just returns the URL directly.
struct BookmarkResolver {

    static func resolveBookmark(from data: Data) -> URL? {
        // On macOS, you'd use startAccessingSecurityScopedResource here.
        // On iOS, we simply decode and return the URL.
        return try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: nil)
    }

    static func bookmark(for url: URL) -> Data? {
        return try? url.bookmarkData()
    }

    static func withResolvedBookmark<T>(_ data: Data, perform block: (URL) throws -> T) rethrows -> T? {
        guard let url = resolveBookmark(from: data) else { return nil }
        return try? block(url)
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

