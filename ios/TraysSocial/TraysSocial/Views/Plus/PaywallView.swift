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
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel: PaywallViewModel
    @State private var showTerms = false
    @State private var showPrivacy = false

    init(context: PlusFeature? = nil, viewModel: PaywallViewModel = PaywallViewModel()) {
        self.context = context
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    if let context {
                        contextLine(context)
                    }
                    featureList
                    planSection
                    if let message = viewModel.statusMessage {
                        statusBanner(message)
                    }
                    primaryCTA
                    restoreButton
                    legalFooter
                }
                .padding(.bottom, 32)
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Not now")) { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
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

    // ART: this header is type-only, matching WelcomeView (which draws its
    // wordmark from type and native shapes and ships no image assets). A Trays
    // Plus lockup could replace the eyebrow if one is designed — see the task
    // completion notes for the two open art slots.
    private var header: some View {
        VStack(spacing: 8) {
            Text(String(localized: "TRAYS PLUS"))
                .font(.system(size: 12, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(Theme.gold)
            Text(String(localized: "Everything you cook, organized."))
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.cream)
                .multilineTextAlignment(.center)
            Text(String(localized: "Recipes stay free. Plus adds the tools around them."))
                .font(.subheadline)
                .foregroundStyle(Theme.cream.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(Theme.primary)
        .accessibilityElement(children: .combine)
    }

    private func contextLine(_ feature: PlusFeature) -> some View {
        Text(feature.paywallContext)
            .font(.subheadline.weight(.medium))
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
        VStack(alignment: .leading, spacing: 12) {
            featureRow(String(localized: "No ads, anywhere"))
            featureRow(String(localized: "Custom collections"))
            featureRow(String(localized: "Weekly meal planner"))
            featureRow(String(localized: "Automatic grocery list"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private func featureRow(_ title: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(Theme.accentInk(for: colorScheme))
                .accessibilityHidden(true)
            Text(title)
                .font(.body)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Plans

    @ViewBuilder
    private var planSection: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            VStack(spacing: 12) {
                SkeletonShape(height: 78, cornerRadius: 12)
                SkeletonShape(height: 78, cornerRadius: 12)
            }
            .padding(.horizontal, 24)
        case let .loaded(plans):
            VStack(spacing: 12) {
                ForEach(plans) { plan in
                    PaywallPlanCard(plan: plan, isSelected: plan.id == viewModel.selectedPlanID) {
                        viewModel.selectedPlanID = plan.id
                    }
                }
            }
            .padding(.horizontal, 24)
        case .unavailable:
            unavailableSurface
        }
    }

    private var unavailableSurface: some View {
        VStack(spacing: 12) {
            EditorialEmptyState(
                title: String(localized: "Plans aren't available right now."),
                topPadding: 12
            )
            Button {
                Task { await viewModel.retry() }
            } label: {
                Text(String(localized: "Retry"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.inkOnAccent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }
            .accessibilityLabel(String(localized: "Retry loading plans"))
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Status, CTA, restore, legal

    private func statusBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button {
                viewModel.dismissMessage()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .accessibilityLabel(String(localized: "Dismiss"))
        }
        .padding(12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.hairline(for: colorScheme), lineWidth: 1)
        )
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
                        .font(.headline)
                        .foregroundStyle(Theme.inkOnAccent)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(viewModel.canPurchase ? Theme.accent : Theme.accentMuted)
            .clipShape(Capsule())
        }
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
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .disabled(viewModel.actionState.isBusy)
    }

    /// Guideline 3.1.2 requires the renewal disclosure plus functional Terms and
    /// Privacy links on the purchase surface.
    private var legalFooter: some View {
        VStack(spacing: 10) {
            Text(String(localized: "Subscriptions renew automatically until cancelled. Cancel anytime in Settings."))
                .font(.footnote)
                .foregroundStyle(Theme.muted(for: colorScheme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                Button(String(localized: "Terms of Service")) { showTerms = true }
                Button(String(localized: "Privacy Policy")) { showPrivacy = true }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.accentInk(for: colorScheme))
        }
        .padding(.horizontal, 24)
    }
}
