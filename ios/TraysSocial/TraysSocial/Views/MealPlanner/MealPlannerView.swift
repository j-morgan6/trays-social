import SwiftUI

/// Pushed destination for the meal planner. Empty because — unlike
/// `CollectionRoute` — there is nothing to carry: the title is static and the
/// displayed week lives on the shared `MealPlannerViewModel`.
struct MealPlannerRoute: Hashable {}

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
    @Environment(\.colorScheme) private var colorScheme

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
        .animation(.easeInOut(duration: 0.18), value: tab)
        .modifier(MealPlannerSurface(
            viewModel: viewModel,
            tray: tray,
            tab: $tab,
            pickerTarget: $pickerTarget
        ))
    }

    private var weekHeader: some View {
        HStack(spacing: 12) {
            weekStepButton(
                systemImage: "chevron.left",
                label: String(localized: "Previous week"),
                action: viewModel.goToPreviousWeek
            )

            Text(viewModel.weekRangeLabel)
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            weekStepButton(
                systemImage: "chevron.right",
                label: String(localized: "Next week"),
                action: viewModel.goToNextWeek
            )
        }
    }

    private func weekStepButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accentInk(for: colorScheme))
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }

    private var tabPicker: some View {
        Picker(String(localized: "Meal plan"), selection: $tab) {
            ForEach(PlannerTab.allCases) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
