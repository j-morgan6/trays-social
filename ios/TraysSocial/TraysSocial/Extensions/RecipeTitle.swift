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
/// D125: the web `TrayFormatting.caption_title/2` (D126) runs the same rule,
/// and both platforms must give the same title and note for the same caption,
/// so it is plain string scanning (never NLTokenizer, which the web cannot
/// reproduce). The rule is defined by
/// TraysSocialTests/Fixtures/recipe-title-vectors.json (W267): every title and
/// note there, and its abbreviation, whitespace and line-break lists, is
/// asserted against this type by RecipeTitleVectorTests and against the web by
/// tray_formatting_test.exs. Change the rule by editing that file and both
/// implementations together.
///
/// Whitespace and line breaks are the explicit sets below, never
/// `Character.isWhitespace` or `CharacterSet.whitespacesAndNewlines`, so the
/// rule does not move with the SDK's Unicode tables. The title is always a
/// prefix of the trimmed caption, which `note` relies on.
enum RecipeTitle {
    /// Words whose trailing period never ends a title. Lowercase; compared
    /// case-insensitively.
    static let abbreviations: Set<String> = [
        "mr", "mrs", "ms", "dr", "st", "mt", "jr", "sr", "prof", "vs", "approx", "no",
    ]

    /// Characters that end the title line.
    static let lineBreaks: Set<Character> = [
        "\n", "\r", "\r\n", "\u{000B}", "\u{000C}", "\u{0085}", "\u{2028}", "\u{2029}",
    ]

    /// Characters that separate words, line breaks included. Swift compares
    /// characters by canonical equivalence, so U+2000 and U+2001 match their
    /// equivalents U+2002 and U+2003, which are members too.
    static let whitespace: Set<Character> = lineBreaks.union([
        " ", "\t", "\u{00A0}", "\u{1680}",
        "\u{2000}", "\u{2001}", "\u{2002}", "\u{2003}", "\u{2004}", "\u{2005}",
        "\u{2006}", "\u{2007}", "\u{2008}", "\u{2009}", "\u{200A}",
        "\u{202F}", "\u{205F}", "\u{3000}",
    ])

    private static let terminators: Set<Character> = [".", "!", "?"]

    private static let noteTrim = whitespace.union(terminators)

    static func from(caption: String?) -> String {
        from(caption: caption, fallback: String(localized: "Untitled"))
    }

    static func from(caption: String?, fallback: String) -> String {
        let candidate = firstSentence(of: caption)
        return candidate.isEmpty ? fallback : candidate
    }

    /// The caption after its first sentence, without the joining punctuation
    /// or whitespace; empty when the caption is one sentence or has no first
    /// sentence.
    static func note(caption: String?) -> String {
        let raw = trimmed(caption)
        let title = firstSentence(of: caption)
        guard !title.isEmpty, raw.count > title.count else { return "" }
        return trim(raw.dropFirst(title.count), in: noteTrim)
    }

    private static func trimmed(_ caption: String?) -> String {
        trim((caption ?? "")[...], in: whitespace)
    }

    private static func trim(_ text: Substring, in set: Set<Character>) -> String {
        guard let first = text.firstIndex(where: { !set.contains($0) }),
              let last = text.lastIndex(where: { !set.contains($0) })
        else { return "" }
        return String(text[first ... last])
    }

    private static func firstSentence(of caption: String?) -> String {
        let raw = trimmed(caption)
        let line = raw.firstIndex(where: { lineBreaks.contains($0) }).map { raw[..<$0] } ?? raw[...]
        let chars = Array(line)
        var end = chars.count
        for index in chars.indices where terminators.contains(chars[index]) {
            let next = index + 1
            guard next == chars.count || whitespace.contains(chars[next]) else { continue }
            if chars[index] == ".", keepsPeriod(after: chars[..<index]) {
                continue
            }
            end = index
            break
        }
        var title = chars[..<end]
        while let last = title.last, terminators.contains(last) || whitespace.contains(last) {
            title.removeLast()
        }
        return String(title)
    }

    /// Whether a period after `prefix` belongs to the word before it (back to
    /// the previous whitespace, leading non-letters dropped): a known
    /// abbreviation in any case, or a dotted initial, single letters each
    /// followed by a period, so "J", "U.S" and "e.g" keep it and "Ph.D" does not.
    private static func keepsPeriod(after prefix: ArraySlice<Character>) -> Bool {
        let word = Array(prefix.reversed().prefix { !whitespace.contains($0) }.reversed().drop { !$0.isLetter })
        return isDottedInitial(word) || abbreviations.contains(String(word).lowercased())
    }

    /// "J", "U.S", "U.S.A": a letter, then any number of "." and a letter.
    private static func isDottedInitial(_ word: [Character]) -> Bool {
        guard word.count % 2 == 1 else { return false }
        return word.indices.allSatisfy { index in
            index.isMultiple(of: 2) ? word[index].isLetter : word[index] == "."
        }
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
