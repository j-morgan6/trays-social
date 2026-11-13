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
///
/// D125: a sibling web task adopts this same rule, and both platforms must
/// produce the same title for the same caption, so it is plain string
/// scanning (never NLTokenizer, which the web cannot reproduce). Dotted
/// multi-initials such as "U.S." end the title at their last period, because
/// the word before it is "U.S", not a single letter:
/// 1. Trim the caption and take the text before its first line break.
/// 2. The title ends at the first `.`, `!` or `?` that is followed by
///    whitespace or the end of that line. A period never ends it when the word
///    just before it (the text back to the previous whitespace, leading
///    non-letters dropped) is a known abbreviation, matched case-insensitively,
///    or a single-letter initial. So "Mrs. Smith's pie", "St. Louis ribs!" and
///    "J. Kenji's eggs" keep their periods, and "1.5 hour brisket" is whole
///    because its period is followed by a digit.
/// 3. Trailing terminators and whitespace are dropped; an empty result uses
///    the fallback.
/// The title is always a prefix of the trimmed caption, which `note` relies on.
enum RecipeTitle {
    /// Words whose trailing period never ends a title. Lowercase; compared
    /// case-insensitively.
    private static let abbreviations: Set<String> = [
        "mr", "mrs", "ms", "dr", "st", "mt", "jr", "sr", "prof", "vs", "approx", "no",
    ]

    private static let terminators: Set<Character> = [".", "!", "?"]

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
        let line = raw.firstIndex(where: \.isNewline).map { raw[..<$0] } ?? raw[...]
        let chars = Array(line)
        var end = chars.count
        for index in chars.indices where terminators.contains(chars[index]) {
            let next = index + 1
            guard next == chars.count || chars[next].isWhitespace else { continue }
            if chars[index] == ".", keepsPeriod(after: chars[..<index]) {
                continue
            }
            end = index
            break
        }
        var title = chars[..<end]
        while let last = title.last, terminators.contains(last) || last.isWhitespace {
            title.removeLast()
        }
        return String(title)
    }

    /// Whether a period after `prefix` belongs to the word before it: a known
    /// abbreviation or a single-letter initial.
    private static func keepsPeriod(after prefix: ArraySlice<Character>) -> Bool {
        let word = prefix.reversed().prefix { !$0.isWhitespace }.reversed()
        let letters = String(word.drop { !$0.isLetter }).lowercased()
        if letters.count == 1, letters.first?.isLetter == true {
            return true
        }
        return abbreviations.contains(letters)
    }
}

/// W249: the recipe editor's "Recipe name" and "A line about it" fields over
/// the one caption the API stores. The caption stays the source of truth: the
/// name is the text before its first line break and the line is everything
/// after it, so a caption nobody types into round-trips unchanged, and
/// `RecipeTitle.from(caption:)` still reads the name as the title (the title
/// never reaches past the first line break). A caption with no line break (older
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
