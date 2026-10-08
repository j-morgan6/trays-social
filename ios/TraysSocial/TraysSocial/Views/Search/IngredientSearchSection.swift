import SwiftUI

/// The "What I have" body: chip input, results grouped into
/// "You have everything" and "Almost there", and recently used chips.
///
/// The section pads its own content (16pt) rather than taking outer
/// padding, because `SectionHeader` carries a built-in 20pt inset that
/// lines up with the screen title; outer padding would double it.
struct IngredientSearchSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: IngredientSearchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            chipInput
            if viewModel.chips.isEmpty {
                emptyPrompt
            } else if viewModel.isSearching, viewModel.results == nil {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
            } else if let results = viewModel.results {
                if results.isEmpty {
                    EditorialEmptyState(
                        title: String(localized: "No matches yet. Try removing an ingredient."),
                        topPadding: 24
                    )
                } else {
                    matchSection(String(localized: "You have everything"), results.everything)
                    matchSection(String(localized: "Almost there"), results.almost)
                }
            }
            if !viewModel.suggestions.isEmpty {
                recentRow
            }
        }
        .onDisappear { viewModel.cancelInFlight() }
    }

    private var chipInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("", text: $viewModel.draft, prompt: Text("Add an ingredient…"))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { viewModel.submitDraft() }
                .disabled(!viewModel.canAddMore)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                .accessibilityLabel(Text("Add an ingredient"))
                .padding(.horizontal, 16)
            if !viewModel.chips.isEmpty {
                chipRow
            }
            if !viewModel.canAddMore {
                Text("Up to 10 ingredients")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }
        }
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(viewModel.chips, id: \.self) { chip in
                    Button { viewModel.removeChip(chip) } label: {
                        HStack(spacing: 4) {
                            Text(chip)
                            Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accentInk(for: colorScheme))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.accentMuted))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Remove \(chip)"))
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var emptyPrompt: some View {
        Text("Add what's in your kitchen to see what you can make.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func matchSection(_ title: String, _ matches: [IngredientMatch]) -> some View {
        if !matches.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(label: title, count: matches.count)
                ForEach(matches) { match in
                    NavigationLink(value: match.post) { matchRow(match) }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    private func matchRow(_ match: IngredientMatch) -> some View {
        HStack(spacing: 12) {
            Photo(key: photoKey(match.post), url: match.post.thumbURL?.asBackendURL)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(RecipeTitle.from(caption: match.post.caption))
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text("@\(match.post.user.username)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !match.missing.isEmpty {
                    Text("missing: \(match.missing.joined(separator: ", "))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var recentRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(label: String(localized: "Recently used"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(viewModel.suggestions, id: \.self) { chip in
                        FilterChip(label: "+ \(chip)", isActive: false) { viewModel.addChip(chip) }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func photoKey(_ post: Post) -> FoodPalette.Key {
        let keys = FoodPalette.Key.allCases
        return keys[abs(post.id) % keys.count]
    }
}
