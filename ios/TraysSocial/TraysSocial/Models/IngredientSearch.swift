import Foundation

/// Response of `GET /api/v1/search/ingredients`.
struct IngredientSearchResults: Decodable, Sendable {
    let everything: [IngredientMatch]
    let almost: [IngredientMatch]

    var isEmpty: Bool {
        everything.isEmpty && almost.isEmpty
    }
}

/// One recipe the viewer can make, plus what it still needs.
/// `scope` is "mine", "following" or "everyone"; the server already ranked it.
struct IngredientMatch: Decodable, Identifiable, Sendable, Hashable {
    let post: Post
    let missing: [String]
    let scope: String

    var id: Int {
        post.id
    }
}

/// Client-side chip rules. The server does the real normalization
/// (singularizing, pantry basics); the client only keeps the chip row tidy
/// and inside the server's limits (1 to 10 terms, each at most 50 characters).
enum IngredientChips {
    static let maxCount = 10
    static let maxTermLength = 50

    static func adding(_ raw: String, to chips: [String]) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let chip = String(trimmed.prefix(maxTermLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !chip.isEmpty, !chips.contains(chip), chips.count < maxCount else { return chips }
        return chips + [chip]
    }

    static func queryItems(for chips: [String]) -> [URLQueryItem] {
        chips.map { URLQueryItem(name: "have[]", value: $0) }
    }
}
