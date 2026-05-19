import SwiftUI

/// Editorial bottom tab bar — matches `IOSTabBar` from the Claude Design
/// handoff (design/handoff/trays-social/project/shared.jsx).
///
/// Five slots: Feed · Find · [+ amber FAB] · My Tray · Profile.
/// The center FAB triggers the Create sheet; everything else either
/// updates `selectedTray` or pushes onto the navigation path.
///
/// Background is a soft dark gradient + ultra-thin material, so the
/// feed content fades into it rather than getting a hard divider.
struct BottomBar: View {
    @Binding var selectedTray: AppState.TrayTab
    var onCreateTap: () -> Void
    var onProfileTap: () -> Void
    var profilePhotoURL: String?

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.feed, label: "Feed", icon: "house")
            tabButton(.find, label: "Find", icon: "magnifyingglass")
            createFab
            tabButton(.myTray, label: "My Tray", icon: "bookmark")
            profileButton
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(barBackground)
    }

    // MARK: - Background

    /// Soft dark gradient with blur — content fades into the bar rather
    /// than being cut off by a hard divider.
    private var barBackground: some View {
        LinearGradient(
            colors: [Theme.background.opacity(0), Theme.background.opacity(0.85), Theme.background],
            startPoint: .top,
            endPoint: .bottom
        )
        .background(.ultraThinMaterial)
    }

    // MARK: - Tab button

    @ViewBuilder
    private func tabButton(_ tray: AppState.TrayTab, label: String, icon: String) -> some View {
        let isActive = selectedTray == tray
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTray = tray
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isActive ? .semibold : .regular))
                Text(label)
                    .font(.system(size: 10, weight: isActive ? .semibold : .medium))
            }
            .foregroundStyle(isActive ? Theme.text : Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - Center FAB

    /// Golden Amber create button — reserved color in the design system
    /// for "do something delicious" moments, of which creating a recipe
    /// is the canonical one.
    private var createFab: some View {
        Button(action: onCreateTap) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(hex: 0x2A1C00))
                .frame(width: 52, height: 52)
                .background(Theme.accent)
                .clipShape(Circle())
                .shadow(color: Theme.accent.opacity(0.35), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Create recipe")
    }

    // MARK: - Profile

    private var profileButton: some View {
        Button(action: onProfileTap) {
            VStack(spacing: 4) {
                avatar
                Text("Profile")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Profile")
    }

    private var avatar: some View {
        Group {
            if let urlString = profilePhotoURL, let url = urlString.asBackendURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(.systemGray4))
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                // Force SwiftUI to invalidate AsyncImage identity when the
                // URL changes (e.g. after the user uploads a new profile
                // photo). Without this, AsyncImage's internal URLCache
                // hit path can keep displaying the previous image even
                // though the parent passed a new URL string. (D34.)
                .id(url)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24, height: 24)
            }
        }
    }
}
