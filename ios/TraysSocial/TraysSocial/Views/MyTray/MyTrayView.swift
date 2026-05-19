import SwiftUI

/// Editorial My Tray — matches `IOSMyTray` from the Claude Design
/// handoff (design/handoff/trays-social/project/ios-screens.jsx).
///
/// Horizontal collections row (only "All saved" wired today — custom
/// collections need a schema) + a list of saved recipes as horizontal
/// cards with a 110pt thumbnail.
struct MyTrayView: View {
    @State private var viewModel = MyTrayViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                collectionsRow
                    .padding(.bottom, 14)

                if viewModel.posts.isEmpty, !viewModel.isLoading {
                    emptyState
                } else {
                    savedList
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .overlay {
            if viewModel.isLoading, viewModel.posts.isEmpty {
                VStack(spacing: 10) {
                    ForEach(0 ..< 4, id: \.self) { _ in
                        SkeletonListRow()
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 140)
                .allowsHitTesting(false)
                .skeletonGroup(label: "Loading saved recipes")
            }
        }
        .refreshable { await viewModel.refresh() }
        .task {
            if viewModel.posts.isEmpty {
                await viewModel.load()
            }
        }
    }

    // MARK: - Collections row

    /// Horizontal scroll strip — "All saved" is the only wired
    /// collection today. The dashed "+ New collection" tile is a
    /// placeholder; collections need a schema before they can be wired.
    private var collectionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                collectionTile(name: "All saved", count: viewModel.posts.count, isActive: true)
                newCollectionTile
            }
            .padding(.horizontal, 20)
        }
    }

    private func collectionTile(name: String, count: Int, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo placeholder — eventually a representative recipe
            // from the collection.
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0xD8B178), Color(hex: 0x8A5A32)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .frame(height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.serif(13))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text("\(count) RECIPES")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(width: 124)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Theme.secondary : Color.white.opacity(0.08), lineWidth: isActive ? 1.5 : 1)
        )
    }

    private var newCollectionTile: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 16))
                .foregroundStyle(Theme.textSecondary)
            Text("New collection")
                .font(.serifItalic(11))
                .foregroundStyle(Theme.textSecondary)
            Text("SOON")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Theme.textSecondary.opacity(0.6))
        }
        .frame(width: 124, height: 122)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Color.white.opacity(0.15))
        )
    }

    // MARK: - Saved list

    private var savedList: some View {
        VStack(spacing: 12) {
            ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                NavigationLink(value: post) {
                    savedCard(post)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.removeBookmark(at: index)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    /// Horizontal saved-recipe card — 110pt thumb left + content right
    /// with byline, serif title, meta line, and a Mint Whisper
    /// collection chip. Matches IOSMyTray's row.
    private func savedCard(_ post: Post) -> some View {
        HStack(alignment: .top, spacing: 0) {
            if let url = post.thumbURL ?? post.primaryPhotoURL {
                AsyncImage(url: url.asBackendURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
                .frame(width: 110, height: 110)
                .clipped()
            } else {
                Rectangle().fill(Color(.systemGray5)).frame(width: 110, height: 110)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(post.user.username)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)

                Text(savedTitle(post))
                    .font(.serif(17))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(savedMeta(post))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.bottom, 2)

                Text("ALL SAVED")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Theme.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.secondary.opacity(0.16))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Spacer(minLength: 0)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func savedTitle(_ post: Post) -> String {
        let raw = (post.caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "Recipe" }
        let candidate = raw.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? raw
        return candidate.isEmpty ? "Recipe" : candidate
    }

    private func savedMeta(_ post: Post) -> String {
        var parts: [String] = []
        if let time = post.cookingTimeMinutes {
            let hours = time / 60
            let mins = time % 60
            if hours == 0 { parts.append("\(mins) min") }
            else if mins == 0 { parts.append("\(hours)h") }
            else { parts.append("\(hours)h \(mins)m") }
        }
        if !post.ingredients.isEmpty {
            parts.append("\(post.ingredients.count) ingredients")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Nothing saved yet.")
                .font(.serifItalic(18))
                .foregroundStyle(Theme.text)
            Text("Tap the bookmark on any recipe to save it here.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
        .padding(.top, 40)
    }
}
