import SwiftUI

/// Pushed destination for the meal planner. Empty because — unlike
/// `CollectionRoute` — there is nothing to carry: the title is static and the
/// displayed week lives on the shared `MealPlannerViewModel`.
struct MealPlannerRoute: Hashable {}

/// W253: the planner header's copy, pure so it is testable.
enum MealPlannerCopy {
    /// "Nov 9 – 15 · 6 planned" under "This week"; just "6 planned" under a
    /// title that already is the range. A week that failed to load has no
    /// known count, so it shows the range alone (or nothing) rather than
    /// claiming "0 planned".
    static func weekSubtitle(title: String, range: String, plannedCount: Int, loadFailed: Bool) -> String {
        let showsRange = title != range
        if loadFailed, plannedCount == 0 {
            return showsRange ? range : ""
        }
        let planned = String(localized: "\(plannedCount) planned")
        return showsRange ? "\(range) · \(planned)" : planned
    }
}

/// The two faces of the planner.
enum PlannerTab: String, CaseIterable, Identifiable {
    case week
    case grocery

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .week: String(localized: "Week")
        case .grocery: String(localized: "Grocery")
        }
    }
}

/// Weekly meal planner: a Monday-Sunday week of planned recipes, and the
/// derived grocery checklist, under one shared week header.
///
/// The grocery list is a segmented face rather than a separate push because the
/// week header — `< Mar 2 - Mar 8 >` — governs both. A push would have to
/// duplicate the header and re-plumb prev/next, and either share this
/// ViewModel (making the push pointless) or refetch a week it already has.
struct MealPlannerView: View {
    @Environment(AppState.self) private var appState
    @Environment(MealPlannerViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A second instance, not the tray tab's: `MyTrayView`'s `@State` is not
    /// reachable from a root-stack destination. The picker only reads this, so
    /// hoisting it into the environment would be over-engineering.
    @State private var tray = MyTrayViewModel()
    @State private var tab: PlannerTab = .week
    @State private var pickerTarget: PlannerDay?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                weekHeader
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                tabPicker
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)

                switch tab {
                case .week:
                    PlannerWeekView(
                        viewModel: viewModel,
                        onAdd: { pickerTarget = $0 }
                    )
                case .grocery:
                    GroceryListView(viewModel: viewModel)
                }
            }
            // Pins the content width to the viewport so an async thumbnail's
            // natural size can never stretch the VStack (swiftui-layout-pitfalls).
            .containerRelativeFrame(.horizontal, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 116)
        }
        .background(Theme.background)
        .navigationTitle(String(localized: "Meal plan"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: tab)
        .modifier(MealPlannerSurface(
            viewModel: viewModel,
            tray: tray,
            tab: $tab,
            pickerTarget: $pickerTarget
        ))
    }

    /// More artboard: the rounded page title (the week's name) over its date
    /// range and planned count, with the week steppers as pill circles.
    private var weekHeader: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.weekRangeLabel)
                    .roundedFont(32, weight: .heavy, relativeTo: .largeTitle)
                    .tracking(-0.6)
                    .foregroundStyle(Theme.text)
                    .accessibilityAddTraits(.isHeader)
                Text(weekSubtitle)
                    .scaledFont(15, relativeTo: .subheadline)
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                weekStepButton(
                    systemImage: "chevron.left",
                    label: String(localized: "Previous week"),
                    action: viewModel.goToPreviousWeek
                )
                weekStepButton(
                    systemImage: "chevron.right",
                    label: String(localized: "Next week"),
                    action: viewModel.goToNextWeek
                )
            }
        }
    }

    /// "Nov 9 – 15 · 6 planned". The range repeats what a non-current week's
    /// title already says, so it shows only under "This week".
    private var weekSubtitle: String {
        MealPlannerCopy.weekSubtitle(
            title: viewModel.weekRangeLabel,
            range: viewModel.week.rangeLabel,
            plannedCount: viewModel.entries.count,
            loadFailed: viewModel.weekLoadFailed
        )
    }

    private func weekStepButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 46, height: 46)
                .background {
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        Circle().fill(Theme.pill)
                    }
                }
                .overlay(Circle().strokeBorder(Theme.hairlineStrong, lineWidth: 1))
                .shadow(color: Theme.shadow, radius: 12, y: 8)
                .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }

    private var tabPicker: some View {
        SegmentedPills(
            options: PlannerTab.allCases.map { .init(value: $0, title: $0.label) },
            selection: $tab
        )
        .accessibilityLabel(String(localized: "Meal plan"))
    }
}
