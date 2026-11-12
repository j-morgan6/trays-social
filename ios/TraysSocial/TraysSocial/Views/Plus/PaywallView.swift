import SwiftUI

/// The single paywall surface for Trays Plus.
///
/// Presented from exactly two places, both user-initiated:
///   1. the "Trays Plus" row in Settings (`PlusSettingsSection`)
///   2. a moment-of-need tap on a gated feature (`PlusGate`)
///
/// It is NEVER presented on launch, on a timer, after N actions, as a banner or
/// as a badge. That is a hard product constraint, not a preference.
///
/// Every message is rendered inline rather than via `Toast`: the paywall is a
/// sheet presented from Settings (itself a sheet), and the root `ErrorToast`
/// does not layer above modal presentations.
struct PaywallView: View {
    /// Which gated feature the user tapped, when they arrived via `PlusGate`.
    /// `nil` when opened from Settings, where no context line is warranted.
    let context: PlusFeature?

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PaywallViewModel
    @State private var showTerms = false
    @State private var showPrivacy = false

    init(context: PlusFeature? = nil, viewModel: PaywallViewModel = PaywallViewModel()) {
        self.context = context
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            ScrollView {
                VStack(spacing: 24) {
                    header(topInset: topInset)
                    VStack(spacing: 24) {
                        if let context {
                            contextLine(context)
                        }
                        featureList
                        planSection
                        if let message = viewModel.statusMessage {
                            statusBanner(message)
                        }
                        VStack(spacing: 4) {
                            primaryCTA
                            restoreButton
                        }
                        legalFooter
                    }
                    // The canvas's 520pt body column, so iPad lines stay short.
                    .frame(maxWidth: 520)
                }
                .padding(.bottom, 32)
            }
            .scrollBounceBehavior(.basedOnSize)
            .ignoresSafeArea(.container, edges: .top)
            .background {
                // Emerald behind the status bar and the top overscroll, the
                // page background below (the same seamless split as AuthScreen).
                VStack(spacing: 0) {
                    Theme.primary.frame(height: topInset + 200)
                    Theme.background
                }
                .ignoresSafeArea()
            }
            .overlay(alignment: .topLeading) {
                PaywallCloseButton { dismiss() }
                    .padding(.leading, 16)
                    .padding(.top, 12)
            }
            .sheet(isPresented: $showTerms) {
                SafariView(url: URL(string: Configuration.apiBaseURL + "/terms")!)
            }
            .sheet(isPresented: $showPrivacy) {
                SafariView(url: URL(string: Configuration.apiBaseURL + "/privacy")!)
            }
        }
        .presentationDragIndicator(.visible)
        // One dismissal rule, driven off server truth. This covers purchase
        // success, restore success, and a renewal landing via the background
        // Transaction.updates listener while the sheet happens to be open.
        .task {
            guard !appState.isPlus else {
                dismiss()
                return
            }
            await viewModel.load()
        }
        .onChange(of: appState.isPlus) { _, isPlus in
            if isPlus {
                dismiss()
            }
        }
    }

    // MARK: - Header

    /// More artboard, "Plus upgrade": the same emerald band as sign-in, with
    /// the handles logo, a "Trays Plus" wordmark (Plus in gold) and one line.
    /// The canvas's own headline copy is not used: this screen keeps the
    /// approved "Recipes stay free" positioning (monetization north star).
    private func header(topInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Image("Logo-dark")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 60)
                .accessibilityHidden(true)

            Text(Self.wordmark)
                .roundedFont(34, weight: .black, relativeTo: .largeTitle)
                .tracking(-0.5)
                .foregroundStyle(Theme.cream)
                .padding(.top, 12)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "Everything you cook, organized."))
                .scaledFont(15.5, relativeTo: .subheadline)
                .foregroundStyle(Theme.cream.opacity(0.9))
                .padding(.top, 6)
            Text(String(localized: "Recipes stay free. Plus adds the tools around them."))
                .scaledFont(13.5, relativeTo: .footnote)
                .foregroundStyle(Theme.cream.opacity(0.8))
                .padding(.top, 4)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, topInset + 64)
        .padding(.bottom, 30)
        .background(Theme.primary)
        .accessibilityElement(children: .combine)
    }

    /// "Trays Plus" with Plus in gold. A product name, so not localized.
    private static let wordmark: AttributedString = {
        var mark = AttributedString("Trays Plus")
        if let range = mark.range(of: "Plus") {
            mark[range].foregroundColor = Theme.gold
        }
        return mark
    }()

    private func contextLine(_ feature: PlusFeature) -> some View {
        Text(feature.paywallContext)
            .scaledFont(15, weight: .medium, relativeTo: .subheadline)
            .foregroundStyle(Theme.text)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
    }

    // MARK: - Features

    /// Exactly the four v1 Plus capabilities. Recipe scaling and offline access
    /// are deferred to W164/W165 and must not be advertised here.
    private var featureList: some View {
        VStack(alignment: .leading, spacing: 4) {
            PaywallFeatureRow(title: String(localized: "No ads, anywhere"), systemImage: "eye.slash")
            PaywallFeatureRow(title: String(localized: "Custom collections"), systemImage: "square.stack")
            PaywallFeatureRow(title: String(localized: "Weekly meal planner"), systemImage: "calendar")
            PaywallFeatureRow(title: String(localized: "Automatic grocery list"), systemImage: "checklist")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    // MARK: - Plans

    @ViewBuilder
    private var planSection: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            VStack(spacing: 10) {
                SkeletonShape(height: 78, cornerRadius: 20)
                SkeletonShape(height: 78, cornerRadius: 20)
            }
            .padding(.horizontal, 24)
        case let .loaded(plans):
            VStack(spacing: 10) {
                ForEach(plans) { plan in
                    PaywallPlanCard(plan: plan, isSelected: plan.id == viewModel.selectedPlanID) {
                        viewModel.selectedPlanID = plan.id
                    }
                }
            }
            .padding(.horizontal, 24)
        case .unavailable:
            // D95: a failed catalog read is logged by the view model and shown
            // here inline, never toasted.
            TrayLoadErrorView(
                title: String(localized: "Plans aren't available right now."),
                subtitle: "",
                onRetry: { Task { await viewModel.retry() } }
            )
            .padding(.top, -40)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Status, CTA, restore, legal

    private func statusBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(message)
                .scaledFont(14, relativeTo: .footnote)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            // Only where dismissing actually does something. The waiting states
            // clear themselves when server truth lands.
            if viewModel.isStatusDismissible {
                Button {
                    viewModel.dismissMessage()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .padding(-14)
                .accessibilityLabel(String(localized: "Dismiss"))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.lift))
        .padding(.horizontal, 24)
    }

    private var primaryCTA: some View {
        Button {
            Task { await viewModel.purchaseSelected(appState: appState) }
        } label: {
            Group {
                if viewModel.actionState.isBusy {
                    ProgressView()
                        .tint(Theme.inkOnAccent)
                        .accessibilityLabel(viewModel.primaryButtonTitle)
                } else {
                    Text(viewModel.primaryButtonTitle)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(AccentButtonStyle(fillsWidth: true))
        .disabled(!viewModel.canPurchase)
        .padding(.horizontal, 24)
    }

    /// Required by App Store review. Stays enabled during `.awaitingEntitlement`
    /// and `.pendingApproval`: it is the user's manual recovery when the server
    /// refresh never landed.
    private var restoreButton: some View {
        Button {
            Task { await viewModel.restore(appState: appState) }
        } label: {
            Text(String(localized: "Restore purchases"))
                .scaledFont(14.5, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(Theme.primaryInk)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.actionState.isBusy)
        .padding(.horizontal, 24)
    }

    /// Guideline 3.1.2 requires the renewal disclosure plus functional Terms and
    /// Privacy links on the purchase surface.
    private var legalFooter: some View {
        VStack(spacing: 4) {
            Text(String(localized: "Subscriptions renew automatically until cancelled. Cancel anytime in Settings."))
                .scaledFont(12, relativeTo: .caption)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                Button(String(localized: "Terms of Service")) { showTerms = true }
                    .frame(minHeight: 44)
                Button(String(localized: "Privacy Policy")) { showPrivacy = true }
                    .frame(minHeight: 44)
            }
            .scaledFont(12.5, weight: .semibold, relativeTo: .caption)
            .foregroundStyle(Theme.primaryInk)
        }
        .padding(.horizontal, 24)
    }
}

/// More artboard: a pill circle with a close mark over the band.
private struct PaywallCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 46, height: 46)
                .background {
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        Circle().fill(Theme.pill)
                    }
                }
                .overlay(Circle().strokeBorder(Theme.hairlineStrong, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Not now"))
    }
}

/// A mint-tint icon tile beside the feature name.
private struct PaywallFeatureRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.primaryInk)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.mintTint))
                .accessibilityHidden(true)
            Text(title)
                .scaledFont(15.5, weight: .bold, relativeTo: .body)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
