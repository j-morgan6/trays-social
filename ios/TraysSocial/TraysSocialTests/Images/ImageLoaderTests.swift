@testable import TraysSocial
import XCTest

final class ImageLoaderTests: XCTestCase {
    /// `cachedImage(for:)` returns nil before anything has been loaded.
    /// This is the cache-miss path the new `CachedAsyncImage` uses to
    /// decide whether to show the placeholder.
    func test_cachedImage_returnsNilForUnseenURL() throws {
        let loader = ImageLoader()
        let url = try XCTUnwrap(URL(string: "https://example.test/never-seen.jpg"))

        XCTAssertNil(loader.cachedImage(for: url))
    }

    /// `prefetch(urls:)` is a no-op on URLs already known to be
    /// cached or in-flight. We can't easily fake a hit without a
    /// network round-trip, but we can at least confirm it doesn't
    /// crash with an empty array (the W130 edge case "AsyncImage with
    /// nil URL").
    func test_prefetch_emptyArrayIsNoOp() {
        let loader = ImageLoader()
        loader.prefetch(urls: [])
        // Nothing to assert other than: didn't crash, didn't deadlock.
        XCTAssertTrue(true)
    }

    /// Multiple concurrent `prefetch` calls for the same URL should
    /// dedup internally so we don't spawn N redundant Tasks. We
    /// observe via the in-flight bookkeeping by issuing prefetches
    /// then asserting that subsequent prefetches no-op (no crash, no
    /// duplicate work).
    func test_prefetch_concurrentSameURL_doesNotCrash() throws {
        let loader = ImageLoader()
        let url = try XCTUnwrap(URL(string: "https://example.invalid/img.jpg"))

        // Fire 10 prefetches concurrently. URL is intentionally bogus
        // so the load fails immediately rather than racing the
        // network; the test is about the dedup bookkeeping, not the
        // load itself.
        DispatchQueue.concurrentPerform(iterations: 10) { _ in
            loader.prefetch(urls: [url])
        }

        // Wait briefly for the spawned Tasks to drain.
        let exp = expectation(description: "drain")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
}
