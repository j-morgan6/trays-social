import SwiftUI

/// Editorial Find — matches `IOSFind` from the Claude Design handoff
/// (design/handoff/trays-social/project/ios-screens.jsx).
///
/// Layout: dark search pill with mono match count, horizontal chip
/// strip, serif "N recipes" heading, hero result card + smaller result
/// rows. Trending lives in `trendingView` for the empty (pre-search)
/// state.
struct FindView: View {
    @State private var viewModel = FindViewModel()
    @FocusState private var isSearchFocused: Bool

    private let filterChips = [
        "Under 30 min", "Breakfast", "Dinner", "Vegetarian", "Dessert", "Vegan",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                searchPill
                    .padding(.horizontal, 20)

                chipStrip

                if viewModel.showSearchResults {
                    searchResultsHeader
                        .padding(.horizontal, 20)
                    searchResultsView
                } else {
                    trendingView
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 110)
        }
        .scrollDismissesKeyboard(.interactively)
        .task {
            await viewModel.loadTrending()
        }
        .onDisappear {
            viewModel.cancelInFlight()
        }
    }

    // MARK: - Search pill

    private var searchPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)

            TextField("", text: $viewModel.searchText, prompt: Text("chickpeas, lemon").foregroundStyle(Theme.textSecondary))
                .focused($isSearchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .font(.system(size: 14))
                .foregroundStyle(Theme.text)
                .onChange(of: viewModel.searchText) { _, _ in
                    viewModel.search()
                }

            if !viewModel.searchText.isEmpty {
                // Mono match count — same place the design puts the
                // total result number while typing.
                Text("\(viewModel.posts.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Theme.textSecondary)

                Button {
                    viewModel.clearSearch()
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Theme.surface)
        .clipShape(Capsule())
    }

    // MARK: - Chip strip

    private var chipStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filterChips, id: \.self) { chip in
                    Button {
                        viewModel.toggleFilter(chip)
                    } label: {
                        let isActive = viewModel.activeFilter == chip
                        Text(chip)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isActive ? Color(hex: 0x0F2611) : Theme.text)
                            .padding(.horizontal, 14)
                            .frame(height: 32)
                            .background(isActive ? Theme.secondary : Theme.surface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(
                                    isActive ? Color.clear : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Results header

    private var searchResultsHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(viewModel.posts.count) \(viewModel.posts.count == 1 ? "recipe" : "recipes")")
                .font(.serif(22))
                .foregroundStyle(Theme.text)
            Text("SORTED · NEWEST")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Search Results

    @ViewBuilder
    private var searchResultsView: some View {
        if viewModel.isSearching {
            VStack(spacing: 10) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    SkeletonGridTile()
                }
            }
            .padding(.horizontal, 20)
            .skeletonGroup(label: "Searching")
        } else {
            VStack(alignment: .leading, spacing: 14) {
                if let hero = viewModel.posts.first {
                    NavigationLink(value: hero) {
                        ResultHeroCard(post: hero)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .padding(.horizontal, 20)
                }

                if viewModel.posts.count > 1 {
                    VStack(spacing: 0) {
                        ForEach(viewModel.posts.dropFirst()) { post in
                            NavigationLink(value: post) {
                                ResultRow(post: post)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            Divider().background(Color.white.opacity(0.08))
                        }
                    }
                    .padding(.horizontal, 20)
                }

                if !viewModel.users.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COOKS")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 20)

                        ForEach(viewModel.users) { user in
                            NavigationLink(value: user.username) {
                                cookRow(user)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.top, 10)
                }

                if viewModel.posts.isEmpty, viewModel.users.isEmpty {
                    VStack(spacing: 6) {
                        Text("Nothing matches that yet.")
                            .font(.serifItalic(17))
                            .foregroundStyle(Theme.text)
                        Text("Try fewer chips, a different ingredient, or a cook's name.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    .padding(.horizontal, 30)
                }
            }
        }
    }

    private func cookRow(_ user: User) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Theme.primary)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(user.username.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .overlay(alignment: .center) {
                    if let urlString = user.profilePhotoUrl, let url = urlString.asBackendURL {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.clear
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                if let bio = user.bio {
                    Text(bio)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Trending

    @ViewBuilder
    private var trendingView: some View {
        if viewModel.isLoadingTrending {
            VStack(spacing: 10) {
                ForEach(0 ..< 4, id: \.self) { _ in
                    SkeletonGridTile()
                }
            }
            .padding(.horizontal, 20)
            .skeletonGroup(label: "Loading trending recipes")
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Popular this week")
                        .font(.serif(22))
                        .foregroundStyle(Theme.text)
                    Spacer()
                }
                .padding(.horizontal, 20)

                if let hero = viewModel.trendingPosts.first {
                    NavigationLink(value: hero) {
                        ResultHeroCard(post: hero)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .padding(.horizontal, 20)
                }

                if viewModel.trendingPosts.count > 1 {
                    VStack(spacing: 0) {
                        ForEach(viewModel.trendingPosts.dropFirst()) { post in
                            NavigationLink(value: post) {
                                ResultRow(post: post)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            Divider().background(Color.white.opacity(0.08))
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

// MARK: - Result hero card

/// Larger result card with photo + serif title + byline. Used at the
/// top of the search/trending list (matches IOSFind's hero result).
struct ResultHeroCard: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let url = post.primaryPhotoURL {
                AsyncImage(url: url.asBackendURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
                .frame(height: 200)
                .clipped()
            } else {
                Rectangle().fill(Color(.systemGray5)).frame(height: 200)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.serif(20))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)

                let metaLine = byline
                if !metaLine.isEmpty {
                    Text(metaLine)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var title: String {
        let raw = (post.caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "Untitled recipe" }
        let candidate = raw.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? raw
        return candidate.isEmpty ? "Untitled recipe" : candidate
    }

    private var byline: String {
        var parts: [String] = [post.user.username]
        if let time = post.cookingTimeMinutes { parts.append("\(time) min") }
        if !post.ingredients.isEmpty {
            parts.append("\(post.ingredients.count) ingredients")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Result row

/// Compact 80pt-thumbnail row used for non-hero search results.
struct ResultRow: View {
    let post: Post

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if let url = post.primaryPhotoURL {
                AsyncImage(url: url.asBackendURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.serif(17))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                Text(byline)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    private var title: String {
        let raw = (post.caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "Untitled recipe" }
        let candidate = raw.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? raw
        return candidate.isEmpty ? "Untitled recipe" : candidate
    }

    private var byline: String {
        var parts: [String] = [post.user.username]
        if let time = post.cookingTimeMinutes { parts.append("\(time) min") }
        return parts.joined(separator: " · ")
    }
}
