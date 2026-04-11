import Foundation

extension String {
    /// Resolves a backend asset path (profile photos, post images, thumbnails)
    /// to a full `URL` suitable for `AsyncImage`. Absolute URLs (starting with `http`)
    /// pass through unchanged; relative paths are prefixed with the API base URL.
    ///
    /// The `/uploads` endpoint on the Phoenix backend returns relative paths like
    /// `/uploads/abc123.jpg`, which must be resolved against `Configuration.apiBaseURL`
    /// before `AsyncImage` can fetch them.
    var asBackendURL: URL? {
        if hasPrefix("http") { return URL(string: self) }
        return URL(string: Configuration.apiBaseURL + self)
    }
}
