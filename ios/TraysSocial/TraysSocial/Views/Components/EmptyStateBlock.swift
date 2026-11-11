import SwiftUI

/// Empty-state block (W239, redesign canvas "Empty-state block"): one
/// rounded headline, one plain sentence, at most one action. Sits on a
/// cream card in light mode (lift in dark). Search empties should sit
/// directly on the background with `chrome: .plain`; the Search screen
/// task (W243) switches its call sites over.
///
/// Used for empty lists, no results and zero-state screens. Pre-empts
/// ad-hoc `Text("No X")` calls that would drift visually over time.
struct EmptyStateBlock: View {
    enum Chrome {
        case card
        case plain
    }

    struct Action {
        let title: String
        var systemImage: String?
        var isPrimary = false
        let perform: () -> Void
    }

    let title: String
    var subtitle: String?
    var topPadding: CGFloat = 60
    var chrome: Chrome = .card
    var action: Action?

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.top, topPadding)
    }

    @ViewBuilder
    private var content: some View {
        switch chrome {
        case .card:
            stack
                .padding(.vertical, 32)
                .padding(.horizontal, 22)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.creamOrLift))
                .padding(.horizontal, 18)
        case .plain:
            stack.padding(.horizontal, 22)
        }
    }

    private var stack: some View {
        VStack(spacing: 10) {
            Text(title)
                .roundedFont(.emptyHeadline)
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .scaledFont(15, relativeTo: .subheadline)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            if let action {
                actionButton(action)
                    .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private func actionButton(_ action: Action) -> some View {
        let button = Button(action: action.perform) {
            if let systemImage = action.systemImage {
                Label(action.title, systemImage: systemImage)
            } else {
                Text(action.title)
            }
        }
        if action.isPrimary {
            button.buttonStyle(.trayPrimary)
        } else {
            button.buttonStyle(.traySecondary)
        }
    }
}

/// Legacy name kept so existing call sites compile; the last screen task
/// of the redesign removes it.
typealias EditorialEmptyState = EmptyStateBlock

#Preview("EmptyStateBlock · light") {
    VStack(spacing: 0) {
        EmptyStateBlock(
            title: "Nothing saved yet.",
            subtitle: "Save a recipe from Search or a friend's tray and it waits here.",
            topPadding: 24,
            action: .init(title: "Find recipes in Search", systemImage: "magnifyingglass") {}
        )
        EmptyStateBlock(
            title: "No results yet.",
            subtitle: "Try a different recipe, ingredient, or cook.",
            topPadding: 24,
            chrome: .plain
        )
    }
    .background(Theme.background)
    .preferredColorScheme(.light)
}

#Preview("EmptyStateBlock · dark") {
    EmptyStateBlock(
        title: "Nothing saved yet.",
        subtitle: "Save a recipe from Search or a friend's tray and it waits here.",
        topPadding: 24,
        action: .init(title: "Find recipes in Search", systemImage: "magnifyingglass") {}
    )
    .background(Theme.background)
    .preferredColorScheme(.dark)
}

#Preview("EmptyStateBlock · largest text") {
    EmptyStateBlock(
        title: "Nothing saved yet.",
        subtitle: "Save a recipe from Search or a friend's tray and it waits here.",
        topPadding: 24,
        action: .init(title: "Find recipes in Search", systemImage: "magnifyingglass") {}
    )
    .background(Theme.background)
    .dynamicTypeSize(.accessibility5)
}
