@testable import TraysSocial
import XCTest

@MainActor
final class APIClientURLTests: XCTestCase {
    private let baseURL = "https://example.test/api/v1"

    private func query(_ items: [URLQueryItem]?, path: String = "/search") throws -> String? {
        try APIClient.makeURL(baseURL: baseURL, path: path, queryItems: items).query(percentEncoded: true)
    }

    func test_plusInQueryValueIsPercentEncoded() throws {
        XCTAssertEqual(try query([.init(name: "q", value: "c++")]), "q=c%2B%2B")
        XCTAssertEqual(try query([.init(name: "q", value: "salt+pepper")]), "q=salt%2Bpepper")
    }

    func test_spaceStillEncodesAsPercent20() throws {
        XCTAssertEqual(try query([.init(name: "q", value: "olive oil")]), "q=olive%20oil")
        XCTAssertEqual(try query([.init(name: "q", value: "c++ salt")]), "q=c%2B%2B%20salt")
    }

    func test_literalPercentIsNotDoubleEncoded() throws {
        XCTAssertEqual(try query([.init(name: "q", value: "100%+")]), "q=100%25%2B")
    }

    func test_bracketedHaveKeysSurvive() throws {
        let items = [
            URLQueryItem(name: "have[]", value: "a+b"),
            URLQueryItem(name: "have[]", value: "salt"),
            URLQueryItem(name: "have[]", value: "c d"),
        ]
        XCTAssertEqual(
            try query(items),
            "have%5B%5D=a%2Bb&have%5B%5D=salt&have%5B%5D=c%20d"
        )
    }

    func test_noQueryItemsLeavesURLUnchanged() throws {
        let expected = "https://example.test/api/v1/search"
        let fromNil = try APIClient.makeURL(baseURL: baseURL, path: "/search", queryItems: nil)
        let fromEmpty = try APIClient.makeURL(baseURL: baseURL, path: "/search", queryItems: [])
        XCTAssertEqual(fromNil.absoluteString, expected)
        XCTAssertEqual(fromEmpty.absoluteString, expected)
    }

    func test_unparseableBaseURLThrowsInvalidURL() {
        // A non-numeric port makes URLComponents(string:) return nil.
        XCTAssertThrowsError(
            try APIClient.makeURL(baseURL: "https://example.test:abc/api/v1", path: "/search", queryItems: nil)
        ) { error in
            guard case APIError.invalidURL = error else {
                return XCTFail("Expected APIError.invalidURL, got \(error)")
            }
        }
    }

    func test_decodedValueRoundTripsThroughURLComponents() throws {
        let items = [URLQueryItem(name: "q", value: "c++ salt")]
        let url = try APIClient.makeURL(baseURL: baseURL, path: "/search", queryItems: items)
        let decoded = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(decoded, items)
    }
}
