import SwiftUI

/// My Tray screen ported from the Pass 1 prototype's TabMyTray +
/// TrayEmpty (prototype.jsx lines 467-555).
///
/// Two states:
/// - **populated** — 28pt bold "Your tray" + a muted count line, plus
///   up to two `SectionHeader`-led 2-column `GridCard` grids ("Recipes"
///   and "Saved posts"). A section with zero items hides entirely so
///   the screen never shows a "Recipes · 0" header.
/// - **empty** — a dashed amber-bordered container with an arrow icon,
///   title + body copy locked to the spec, and three amber chevrons
///   that animate twice then settle static (or stay static under
///   Reduce Motion).
struct MyTrayView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = MyTrayViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isEmpty, !viewModel.isLoading {
                    TrayEmptyView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else {
                    populatedHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 18)

                    if !viewModel.savedRecipes.isEmpty {
                        SectionHeader(label: "Recipes", count: viewModel.savedRecipes.count)
                        gridSection(viewModel.savedRecipes)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                    }

                    if !viewModel.savedPosts.isEmpty {
                        SectionHeader(label: "Saved posts", count: viewModel.savedPosts.count)
                        gridSection(viewModel.savedPosts)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                    }
                }
            }
            .padding(.top, 116)
            .padding(.bottom, 116)
        }
        .overlay {
            if viewModel.isLoading, viewModel.isEmpty {
                // D93: match the loaded gridSection layout — a
                // SectionHeader skeleton above a 2-col grid of
                // GridCard-shaped tiles for each of Recipes /
                // Saved posts. Replaces the pre-W127 list-row
                // skeleton that snapped to a grid on load.
                VStack(alignment: .leading, spacing: 16) {
                    SkeletonSectionHeader()
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        ForEach(0 ..< 4, id: \.self) { _ in
                            SkeletonGridTile()
                        }
                    }
                    .padding(.horizontal, 20)

                    SkeletonSectionHeader()
                        .padding(.top, 8)
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        ForEach(0 ..< 2, id: \.self) { _ in
                            SkeletonGridTile()
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
                .padding(.top, 140)
                .allowsHitTesting(false)
                .skeletonGroup(label: "Loading saved recipes")
            }
        }
        .refreshable { await viewModel.refresh() }
        .task {
            // D94: previously gated on viewModel.posts.isEmpty so the
            // first cold visit loaded. With the .onReceive bookmark
            // sync below we still need a periodic refresh on tab re-
            // entry to pick up saves that happened before the app
            // launched (no in-flight notification) — load() guards on
            // isLoading so a double-fire is a no-op.
            await viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .postUpdated)) { notification in
            if let updated = notification.userInfo?["post"] as? Post {
                viewModel.applyPostUpdate(updated)
            }
        }
    }

    private var populatedHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your tray")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.7)
                .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)

            Text(headerSubtitle)
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted(for: colorScheme))
        }
    }

    private var headerSubtitle: String {
        let recipes = viewModel.savedRecipes.count
        let posts = viewModel.savedPosts.count
        let recipesLabel = "\(recipes) \(recipes == 1 ? "recipe" : "recipes")"
        let postsLabel = "\(posts) \(posts == 1 ? "post" : "posts")"
        return "\(recipesLabel) and \(postsLabel) you've kept."
    }

    private func gridSection(_ items: [Post]) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
            spacing: 10
        ) {
            ForEach(items) { post in
                NavigationLink(value: post) {
                    GridCard(
                        photoKey: photoKey(for: post),
                        title: gridTitle(for: post),
                        url: post.primaryPhotoURL?.asBackendURL
                    )
                }
                .buttonStyle(.borderless)
            }
        }
    }

    /// Maps a post's id onto a stable `FoodPalette.Key`. Real photos
    /// land in a later Goal; until then the prototype's gradient
    /// placeholder is what users see, and we want the same post to
    /// always render the same color rather than flickering on reload.
    private func photoKey(for post: Post) -> FoodPalette.Key {
        let keys = FoodPalette.Key.allCases
        return keys[abs(post.id) % keys.count]
    }

    /// Extracts a short title from the post caption — first sentence
    /// up to a terminator, trimmed. Mirrors the existing legacy
    /// savedTitle helper's logic so card titles stay consistent.
    private func gridTitle(for post: Post) -> String {
        let raw = (post.caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "Untitled" }
        let candidate = raw.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? raw
        return candidate.isEmpty ? "Untitled" : candidate
    }
}

/// Empty state — dashed amber container with arrow icon, title + body,
/// and three animated chevrons. Lifted into its own struct to keep
/// MyTrayView body under the 200-line ceiling.
private struct TrayEmptyView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animationToken = 0

    var body: some View {
        VStack(spacing: 0) {
            arrowBadge
                .padding(.bottom, 16)
            Text("Your tray is empty")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
                .padding(.bottom, 8)
            bodyCopy
                .padding(.bottom, 18)
            chevronRow
        }
        .padding(.horizontal, 22)
        .padding(.top, 34)
        .padding(.bottom, 28)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.accent.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    dashedBorderColor,
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
        )
        .padding(.horizontal, 32)
        .onAppear {
            guard !reduceMotion else { return }
            animationToken += 1
        }
    }

    private var dashedBorderColor: Color {
        colorScheme == .dark
            ? Color(red: 255 / 255, green: 179 / 255, blue: 0 / 255, opacity: 0.42)
            : Color(red: 255 / 255, green: 143 / 255, blue: 0 / 255, opacity: 0.55)
    }

    private var arrowBadge: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(colorScheme == .dark ? 0.18 : 0.16))
                .frame(width: 52, height: 52)
            Image(systemName: "arrow.up")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.accentInk(for: colorScheme))
        }
    }

    private var bodyCopy: some View {
        let plus = Text("+")
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundColor(Theme.accentInk(for: colorScheme))
        let prefix = Text("Swipe right to find recipes, or tap ")
        let suffix = Text(" to create your first.")
        return (prefix + plus + suffix)
            .font(.system(size: 13.5))
            .foregroundStyle(Theme.muted(for: colorScheme))
            .multilineTextAlignment(.center)
            .lineSpacing(2)
    }

    private var chevronRow: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 3, id: \.self) { i in
                ChevronHintGlyph(
                    index: i,
                    reduceMotion: reduceMotion,
                    token: animationToken,
                    tint: Theme.accentInk(for: colorScheme)
                )
            }
        }
    }
}

/// One amber chevron-right that fades-and-slides through two cycles
/// when `token` changes, then settles at the static rest opacity. The
/// `index`-based delay (180ms per slot) gives the row its swipe-hint
/// rhythm. Reduce Motion bypasses the animation entirely.
private struct ChevronHintGlyph: View {
    let index: Int
    let reduceMotion: Bool
    let token: Int
    let tint: Color

    @State private var animatedOpacity: Double = 0.55
    @State private var animatedOffset: CGFloat = 0

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(tint)
            .opacity(reduceMotion ? 0.65 : animatedOpacity)
            .offset(x: reduceMotion ? 0 : animatedOffset)
            .onChange(of: token) { _, _ in
                guard !reduceMotion else { return }
                animatedOpacity = 0.2
                animatedOffset = -3
                withAnimation(
                    .easeInOut(duration: 1.1)
                        .delay(Double(index) * 0.18)
                        .repeatCount(4, autoreverses: true)
                ) {
                    animatedOpacity = 0.85
                    animatedOffset = 3
                }
            }
    }
}
