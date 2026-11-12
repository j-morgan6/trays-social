import SwiftUI

/// The seven days of the displayed week, Monday first (More artboard,
/// "Planner · week").
///
/// A vertical list of days rather than a 7-column grid: a day holds a
/// variable number of recipe cards with real titles, and seven columns on a
/// phone leaves each about 50pt wide. Each day is a label column (weekday and
/// date, "Today" on today) beside its soft cards; an open day is a dashed
/// "Plan Monday" slot.
struct PlannerWeekView: View {
    let viewModel: MealPlannerViewModel
    let onAdd: (PlannerDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.weekLoadFailed, viewModel.entries.isEmpty {
                // D95: the failure is logged by the view model; never toasted.
                TrayLoadErrorView(
                    title: String(localized: "Your week didn't load"),
                    onRetry: { Task { await viewModel.reload() } }
                )
            } else {
                ForEach(viewModel.days) { day in
                    PlannerDayRow(
                        day: day,
                        entries: viewModel.entries(on: day),
                        onAdd: { onAdd(day) },
                        onRemove: { viewModel.removeEntry(id: $0) }
                    )
                }

                if viewModel.hasLoadedOnce, viewModel.entries.isEmpty {
                    Text(String(localized: "Tap a day to pick a dinner from your tray."))
                        .scaledFont(14, relativeTo: .subheadline)
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.mintTint))
                        .padding(.top, 8)
                }
            }
        }
        .padding(.horizontal, 18)
    }
}

/// One day: the label column, its planned recipes, and the add control.
private struct PlannerDayRow: View {
    let day: PlannerDay
    let entries: [MealPlanEntry]
    let onAdd: () -> Void
    let onRemove: (Int) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PlannerDayLabel(day: day)
                .frame(minHeight: 76)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(entries) { entry in
                    PlannedRecipeCard(entry: entry, isToday: day.isToday, onRemove: { onRemove(entry.id) })
                }

                // Renders for locked users too: hiding it would remove the
                // moment-of-need trigger from exactly the people it exists to
                // convert. PlusGate works here (unlike in a .contextMenu) because
                // its own paywall sheet lives in a hierarchy that survives.
                PlusGate(.mealPlanner, action: onAdd) {
                    if entries.isEmpty {
                        PlanDaySlot(weekday: day.fullWeekdayName)
                    } else {
                        addAnotherLabel
                    }
                }
                .buttonStyle(.borderless)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// A day can hold more than one recipe; once it has one, the add control
    /// shrinks to a quiet link so the day reads as planned.
    private var addAnotherLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .bold))
                .accessibilityHidden(true)
            Text(String(localized: "Add another"))
                .scaledFont(14.5, weight: .semibold, relativeTo: .subheadline)
        }
        .foregroundStyle(Theme.primaryInk)
        .frame(minHeight: 44)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .accessibilityLabel(String(localized: "Add another recipe to \(day.fullWeekdayName)"))
    }
}

/// The 46pt column: weekday (or "Today") over the rounded date number.
private struct PlannerDayLabel: View {
    let day: PlannerDay

    var body: some View {
        VStack(spacing: 1) {
            Text(day.isToday ? String(localized: "Today") : day.weekdayLabel)
                .scaledFont(12, weight: .bold, relativeTo: .caption)
                .tracking(0.7)
                .textCase(.uppercase)
                .foregroundStyle(day.isToday ? Theme.text : Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(day.dayNumberLabel)
                .roundedFont(20, weight: .heavy, relativeTo: .title3)
                .foregroundStyle(Theme.text)
        }
        .frame(width: 46)
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The dashed open-day slot: "Plan Monday".
private struct PlanDaySlot: View {
    let weekday: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .bold))
                .accessibilityHidden(true)
            Text(String(localized: "Plan \(weekday)"))
                .scaledFont(15, weight: .semibold, relativeTo: .body)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Theme.primaryInk)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 76)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.hairlineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// One planned recipe: photo, rounded title, cooking time, and remove.
/// Today's card carries the amber ring.
private struct PlannedRecipeCard: View {
    let entry: MealPlanEntry
    let isToday: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            PhotoSlot(url: entry.post.thumbURL, cornerRadius: 13)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.post.title)
                    .roundedFont(RoundedHeading.cardTitle.size, weight: .heavy, relativeTo: .subheadline)
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let minutes = entry.post.cookingTimeMinutes {
                    Text(String(localized: "\(minutes) min"))
                        .scaledFont(12.5, relativeTo: .caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Removal is never gated server-side — a lapsed subscriber can
            // still prune their plan.
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(localized: "Remove from plan"))
            // A pending row has a negative id; DELETE /meal-plan/entries/-1 is a 404.
            .disabled(entry.isPending)
        }
        .padding(8)
        .cardSurface(cornerRadius: 20)
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Theme.accent, lineWidth: 2.5)
            }
        }
        .opacity(entry.isPending ? 0.6 : 1)
    }
}

private extension PlannerDay {
    /// GMT, like `PlannerWeek`'s own label styles: `date` is GMT midnight, so a
    /// device-zone format would name the previous day west of Greenwich.
    static let fullWeekdayStyle = Date.FormatStyle(date: .omitted, time: .omitted, timeZone: .gmt)
        .weekday(.wide)

    /// "Monday", for the open-day slot and its VoiceOver label.
    var fullWeekdayName: String {
        date.formatted(Self.fullWeekdayStyle)
    }
}
