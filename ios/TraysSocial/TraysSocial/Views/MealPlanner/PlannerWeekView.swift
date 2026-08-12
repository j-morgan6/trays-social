import SwiftUI

/// The seven day sections of the displayed week, Monday first.
///
/// A vertical list of days rather than a 7-column grid: a day holds a
/// variable number of recipe rows with real titles, and seven columns on a
/// phone leaves each about 50pt wide.
struct PlannerWeekView: View {
    let viewModel: MealPlannerViewModel
    let onAdd: (PlannerDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(viewModel.days) { day in
                PlannerDaySection(
                    day: day,
                    entries: viewModel.entries(on: day),
                    onAdd: { onAdd(day) },
                    onRemove: { viewModel.removeEntry(id: $0) }
                )
            }
        }
        .padding(.horizontal, 20)
    }
}

/// One day: a header line, its planned recipes, and an add control.
private struct PlannerDaySection: View {
    @Environment(\.colorScheme) private var colorScheme

    let day: PlannerDay
    let entries: [MealPlanEntry]
    let onAdd: () -> Void
    let onRemove: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            ForEach(entries) { entry in
                PlannedRecipeRow(entry: entry, onRemove: { onRemove(entry.id) })
            }

            // Renders for locked users too: hiding it would remove the
            // moment-of-need trigger from exactly the people it exists to
            // convert. PlusGate works here (unlike in a .contextMenu) because
            // its own paywall sheet lives in a hierarchy that survives.
            PlusGate(.mealPlanner, action: onAdd) {
                addLabel
            }
            .buttonStyle(.borderless)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(day.weekdayLabel)
                .font(.system(size: 13, weight: .bold))
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundStyle(
                    day.isToday
                        ? Theme.accentInk(for: colorScheme)
                        : Theme.muted(for: colorScheme)
                )
            Text(day.dayNumberLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.muted(for: colorScheme))
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var addLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .bold))
            Text("Add a recipe")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(Theme.accentInk(for: colorScheme))
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.accent.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    Theme.accent.opacity(colorScheme == .dark ? 0.34 : 0.4),
                    style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
                )
        )
        .contentShape(Rectangle())
    }
}

/// One planned recipe: thumbnail, title, cooking time, and a remove button.
private struct PlannedRecipeRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let entry: MealPlanEntry
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Photo(key: photoKey, url: entry.post.thumbURL)
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.post.title)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let minutes = entry.post.cookingTimeMinutes {
                    Text("\(minutes) min")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted(for: colorScheme))
                }
            }

            Spacer(minLength: 0)

            // Removal is never gated server-side — a lapsed subscriber can
            // still prune their plan.
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.muted(for: colorScheme))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(localized: "Remove from plan"))
            // A pending row has a negative id; DELETE /meal-plan/entries/-1 is a 404.
            .disabled(entry.isPending)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
        )
        .opacity(entry.isPending ? 0.6 : 1)
    }

    /// Same stable-key trick as `MyTrayView.photoKey(for:)` — a recipe with no
    /// thumbnail always draws the same gradient rather than flickering.
    private var photoKey: FoodPalette.Key {
        let keys = FoodPalette.Key.allCases
        return keys[abs(entry.post.id) % keys.count]
    }
}
