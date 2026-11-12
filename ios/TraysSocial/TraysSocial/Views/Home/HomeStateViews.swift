import SwiftUI

/// W241: brand-new user (empty tray, follows no one). Cream block with the
/// two first steps, then cooks worth following.
struct HomeWelcomeBlock: View {
    let cooks: [SuggestedCook]
    let onCreateRecipe: () -> Void
    let onOpenSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Welcome to Trays")
                .scaledFont(15, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(Theme.muted)
            Text("Your tray starts here.")
                .roundedFont(32, weight: .heavy, relativeTo: .largeTitle)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            Text("Post a recipe you already love, or save a few from other cooks. It fills up as you cook.")
                .scaledFont(15, relativeTo: .subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            VStack(spacing: 10) {
                Button(action: onCreateRecipe) {
                    Label("Post your first recipe", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle(fillsWidth: true))
                Button(action: onOpenSearch) {
                    Label("Find recipes in Search", systemImage: "magnifyingglass")
                }
                .buttonStyle(SecondaryButtonStyle(fillsWidth: true))
            }
            .padding(.top, 18)
            if !cooks.isEmpty {
                HomeCooksCard(cooks: cooks, title: String(localized: "Cooks to follow"))
                    .padding(.top, 24)
            }
        }
        .padding(.top, 26)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.creamOrLift))
        .padding(.horizontal, HomeMetrics.inset)
    }
}

/// Suggested cooks as tappable rows that open each cook's tray. Rows set
/// their own text colour because `.borderless` NavigationLinks tint labels.
struct HomeCooksCard: View {
    let cooks: [SuggestedCook]
    /// Heading drawn inside the card surface (welcome block). Elsewhere the
    /// section heading sits above the card instead.
    var title: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .roundedFont(.section)
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
            }
            ForEach(Array(cooks.enumerated()), id: \.element.id) { index, cook in
                if index > 0 {
                    Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 70)
                }
                NavigationLink(value: cook.username) {
                    row(cook)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
        .cardSurface(cornerRadius: 22)
    }

    private func row(_ cook: SuggestedCook) -> some View {
        HStack(spacing: 12) {
            AvatarSlot(url: cook.profilePhotoUrl?.asBackendURL, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(cook.username)
                    .scaledFont(15, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text("\(cook.recipeCount) recipes")
                    .scaledFont(13, relativeTo: .footnote)
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Skeleton that mirrors each Home section's shape. No spinners.
struct HomeLoadingView: View {
    var body: some View {
        SkeletonFade {
            VStack(alignment: .leading, spacing: 0) {
                SkeletonShape(width: 120, height: 14, cornerRadius: 6)
                SkeletonShape(height: 38, cornerRadius: 10)
                    .padding(.trailing, 80)
                    .padding(.top, 8)
                headingBar
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    ForEach(0 ..< 6, id: \.self) { _ in SkeletonRecipeCard() }
                }
                SkeletonShape(height: 56, cornerRadius: 28).padding(.top, 20)
                headingBar
                row(spacing: 12) {
                    ForEach(0 ..< 6, id: \.self) { _ in
                        VStack(spacing: 7) {
                            SkeletonCircle(size: 64)
                            SkeletonShape(width: 44, height: 11, cornerRadius: 6)
                        }
                    }
                }
                headingBar
                row(spacing: 12) {
                    ForEach(0 ..< 4, id: \.self) { _ in
                        SkeletonRecipeCard(photoAspectRatio: 4.0 / 5.0).frame(width: HomeMetrics.rowCardWidth)
                    }
                }
            }
            .padding(.horizontal, HomeMetrics.inset)
        }
        .skeletonGroup(label: String(localized: "Loading home"))
    }

    private var headingBar: some View {
        SkeletonShape(width: 140, height: 16, cornerRadius: 6)
            .padding(.top, 30)
            .padding(.bottom, 12)
    }

    /// A row that may run past the screen edge without widening the column.
    private func row(spacing: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing, content: content)
        }
        .scrollDisabled(true)
    }
}

/// First load failed and there is nothing cached to show.
struct HomeErrorView: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Circle()
                .fill(Theme.lift)
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                .accessibilityHidden(true)
            EmptyStateBlock(
                title: String(localized: "Couldn't load Home"),
                subtitle: String(localized: "Check your connection and try again."),
                topPadding: 0,
                chrome: .plain,
                action: .init(title: String(localized: "Try again"), isPrimary: true, perform: onRetry)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }
}
