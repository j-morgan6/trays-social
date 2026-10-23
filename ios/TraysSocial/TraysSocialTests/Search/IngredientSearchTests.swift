@testable import TraysSocial
import XCTest

@MainActor
final class IngredientSearchTests: XCTestCase {
    /// Matches APIClient's decoder configuration (Services/APIClient.swift).
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func postJSON(id: Int) -> String {
        """
        {"id": \(id), "type": "recipe", "caption": "Adobo", "cooking_time_minutes": 40,
         "servings": 4, "like_count": 0, "comment_count": 0, "liked_by_current_user": false,
         "bookmarked_by_current_user": false, "inserted_at": "2026-10-01T12:00:00Z",
         "user": {"id": 2, "username": "maria", "profile_photo_url": null},
         "photos": [], "ingredients": [], "cooking_steps": [], "tools": [], "tags": []}
        """
    }

    func test_decodesGroupedResults() throws {
        let json = """
        {"data": {"everything": [{"post": \(postJSON(id: 1)), "missing": [], "scope": "mine"}],
                  "almost": [{"post": \(postJSON(id: 2)), "missing": ["soy sauce"], "scope": "following"}]}}
        """
        let response = try decoder.decode(
            DataResponse<IngredientSearchResults>.self, from: Data(json.utf8)
        )
        XCTAssertEqual(response.data.everything.map(\.id), [1])
        XCTAssertEqual(response.data.almost.first?.missing, ["soy sauce"])
        XCTAssertEqual(response.data.almost.first?.scope, "following")
    }

    func test_addingTrimsLowercasesAndDedupes() {
        var chips = IngredientChips.adding("  Chicken ", to: [])
        chips = IngredientChips.adding("chicken", to: chips)
        chips = IngredientChips.adding("Rice", to: chips)
        XCTAssertEqual(chips, ["chicken", "rice"])
    }

    func test_addingIgnoresBlankAndCapsAtTen() {
        var chips = (1 ... 10).map { "item\($0)" }
        chips = IngredientChips.adding("eleven", to: chips)
        chips = IngredientChips.adding("   ", to: chips)
        XCTAssertEqual(chips.count, 10)
        XCTAssertFalse(chips.contains("eleven"))
        XCTAssertEqual(IngredientChips.adding("   ", to: []), [])
    }

    /// The server rejects a term over 50 characters with 422, which would
    /// silently fail the whole search, so the client clamps the chip.
    func test_addingClampsChipToServerTermLimit() {
        let chips = IngredientChips.adding(String(repeating: "a", count: 60), to: [])
        XCTAssertEqual(chips.first?.count, IngredientChips.maxTermLength)
    }

    // MARK: - View model

    private struct Offline: Error {}

    /// Records every chip set fetched; answers from `responses` in order
    /// and throws once they run out.
    @MainActor
    private final class FakeFetch {
        var calls: [[String]] = []
        var responses: [IngredientSearchResults]

        init(_ responses: [IngredientSearchResults]) {
            self.responses = responses
        }

        func callAsFunction(_ chips: [String]) async throws -> IngredientSearchResults {
            calls.append(chips)
            guard !responses.isEmpty else { throw Offline() }
            return responses.removeFirst()
        }
    }

    /// Counts toast-bus posts. The observer block is @Sendable, so the
    /// count lives behind a lock rather than in a captured var.
    private final class ToastCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0

        var count: Int {
            lock.withLock { value }
        }

        func increment() {
            lock.withLock { value += 1 }
        }
    }

    private func results(_ ids: [Int]) throws -> IngredientSearchResults {
        let rows = ids.map { #"{"post": \#(postJSON(id: $0)), "missing": [], "scope": "mine"}"# }
        let json = #"{"everything": [\#(rows.joined(separator: ","))], "almost": []}"#
        return try decoder.decode(IngredientSearchResults.self, from: Data(json.utf8))
    }

    private func makeViewModel(_ fake: FakeFetch, debounce: Duration = .zero) -> IngredientSearchViewModel {
        let defaults = UserDefaults(suiteName: "IngredientSearchTests")!
        defaults.removePersistentDomain(forName: "IngredientSearchTests")
        return IngredientSearchViewModel(
            preferences: SearchPreferences(defaults: defaults),
            debounce: debounce,
            fetch: { try await fake($0) }
        )
    }

    func test_failedSearchKeepsLastResultsAndNeverToasts() async throws {
        let fake = try FakeFetch([results([7])])
        let viewModel = makeViewModel(fake)
        let toasts = ToastCounter()
        let observer = NotificationCenter.default.addObserver(
            forName: .traysErrorOccurred, object: nil, queue: nil
        ) { _ in toasts.increment() }
        defer { NotificationCenter.default.removeObserver(observer) }

        viewModel.addChip("chicken")
        viewModel.addChip("rice")
        await viewModel.waitForSearch()
        XCTAssertEqual(viewModel.results?.everything.map(\.id), [7])

        viewModel.addChip("egg")
        await viewModel.waitForSearch()

        XCTAssertEqual(fake.calls, [["chicken", "rice"], ["chicken", "rice", "egg"]])
        XCTAssertEqual(viewModel.results?.everything.map(\.id), [7])
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertEqual(toasts.count, 0)
    }

    func test_newChipCancelsPendingDebouncedSearch() async throws {
        let fake = try FakeFetch([results([1])])
        let viewModel = makeViewModel(fake, debounce: .milliseconds(50))

        viewModel.addChip("chicken")
        viewModel.addChip("rice")
        viewModel.addChip("egg")
        await viewModel.waitForSearch()

        XCTAssertEqual(fake.calls, [["chicken", "rice", "egg"]])
        XCTAssertEqual(viewModel.results?.everything.map(\.id), [1])
    }

    func test_resumeIfNeededRerunsASearchDroppedOnDisappear() async throws {
        let fake = try FakeFetch([results([3])])
        let viewModel = makeViewModel(fake, debounce: .milliseconds(50))

        viewModel.addChip("eggs")
        viewModel.addChip("rice")
        viewModel.cancelInFlight()
        viewModel.resumeIfNeeded()
        await viewModel.waitForSearch()

        XCTAssertEqual(fake.calls, [["eggs", "rice"]])
        XCTAssertEqual(viewModel.results?.everything.map(\.id), [3])

        viewModel.resumeIfNeeded()
        await viewModel.waitForSearch()
        XCTAssertEqual(fake.calls.count, 1)
    }

    func test_queryItemsUseBracketedHaveKey() {
        let items = IngredientChips.queryItems(for: ["chicken", "rice"])
        XCTAssertEqual(items.map(\.name), ["have[]", "have[]"])
        XCTAssertEqual(items.map(\.value), ["chicken", "rice"])
    }
}
