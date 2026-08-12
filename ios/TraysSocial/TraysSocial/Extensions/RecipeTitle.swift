import Foundation

/// The one implementation of "what do we call this recipe on a card".
///
/// Captions are free text; cards need a short line. The rule — first sentence,
/// trimmed, with a fallback — was previously copy-pasted into `MyTrayView`,
/// `PlannedPost`, and the recipe picker, which meant three places to change and
/// three chances to drift. A recipe must read the same on a tray tile, a plan
/// card, and a picker row.
enum RecipeTitle {
    static func from(caption: String?) -> String {
        let raw = (caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return String(localized: "Untitled") }
        let candidate = raw.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? raw
        return candidate.isEmpty ? String(localized: "Untitled") : candidate
    }
}
