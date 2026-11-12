import Foundation

/// The one implementation of "what do we call this recipe on a card".
///
/// Captions are free text; cards need a short line. The rule — first sentence,
/// trimmed, with a fallback — was previously copy-pasted into `MyTrayView`,
/// `PlannedPost`, and the recipe picker, which meant three places to change and
/// three chances to drift. A recipe must read the same on a tray tile, a plan
/// card, and a picker row.
///
/// W247: recipe detail, its hero and the share sheet used three more copies
/// of the same rule with their own fallbacks; they call `from(caption:fallback:)`
/// now, and the cook's note (the caption after its first sentence) is `note`.
enum RecipeTitle {
    static func from(caption: String?) -> String {
        from(caption: caption, fallback: String(localized: "Untitled"))
    }

    static func from(caption: String?, fallback: String) -> String {
        let candidate = firstSentence(of: caption)
        return candidate.isEmpty ? fallback : candidate
    }

    /// The caption after its first sentence, without the joining punctuation;
    /// empty when the caption is one sentence or has no first sentence.
    static func note(caption: String?) -> String {
        let raw = trimmed(caption)
        let title = firstSentence(of: caption)
        guard !title.isEmpty, raw.count > title.count else { return "" }
        return raw.dropFirst(title.count)
            .trimmingCharacters(in: CharacterSet(charactersIn: " \n\t.!?"))
    }

    private static func trimmed(_ caption: String?) -> String {
        (caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstSentence(of caption: String?) -> String {
        let raw = trimmed(caption)
        guard !raw.isEmpty else { return "" }
        return raw.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? raw
    }
}

/// W249: the recipe editor's "Recipe name" and "A line about it" fields over
/// the one caption the API stores. The caption stays the source of truth: the
/// name is the text before its first line break and the line is everything
/// after it, so a caption nobody types into round-trips unchanged, and
/// `RecipeTitle.from(caption:)` still reads the name as the title (a line
/// break ends the first sentence). A caption with no line break (older
/// posts) is all name.
enum CaptionParts {
    static func name(of caption: String) -> String {
        guard let newline = caption.firstIndex(where: \.isNewline) else { return caption }
        return String(caption[..<newline])
    }

    static func line(of caption: String) -> String {
        guard let newline = caption.firstIndex(where: \.isNewline) else { return "" }
        return String(caption[caption.index(after: newline)...])
    }

    /// The caption for a name and a line. The name stays one line (a pasted
    /// break becomes a space, a trailing one is dropped) and an empty line
    /// adds nothing, so a recipe with no line has no trailing break. A line
    /// of only spaces is kept, so a space typed first is not swallowed.
    static func caption(name: String, line: String) -> String {
        var oneLine = name
        while let last = oneLine.last, last.isNewline {
            oneLine.removeLast()
        }
        oneLine = String(oneLine.map { $0.isNewline ? " " : $0 })
        return line.isEmpty ? oneLine : oneLine + "\n" + line
    }
}
