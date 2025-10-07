import Foundation

enum BookmarkResolver {
    static func resolveBookmark(_ data: Data?) -> URL? {
        guard let data else { return nil }
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                return nil
            }
            return url
        } catch {
            print("Bookmark resolution failed: \(error)")
            return nil
        }
    }

    static func bookmark(for url: URL) -> Data? {
        do {
            return try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            print("Bookmark creation failed: \(error)")
            return nil
        }
    }
}
