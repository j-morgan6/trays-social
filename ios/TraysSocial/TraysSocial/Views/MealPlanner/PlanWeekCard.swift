import SwiftUI

/// W245: the planner card's look (My Tray artboard, "Plan your week"), driven
/// by plain values so previews and tests need no view model. `.open` shows
/// the week as 96pt day cells; `.gated` shows ghost days and the Plus offer.
struct PlanWeekCard: View {
    struct Day: Identifiable, Equatable {
        let id: String
        let label: String
        let isToday: Bool
        var title: String?
        var photoURL: URL?
    }

    let mode: PlannerEntryMode
    let days: [Day]
    let onOpen: () -> Void

    static let dayWidth: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            switch mode {
            case .open: openBody
            case .gated: lockedBody
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
        .cardSurface(cornerRadius: 24)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Plan your week")
                .roundedFont(18, weight: .bold, relativeTo: .headline)
                .foregroundStyle(Theme.text)
            Text("Plus")
                .scaledFont(11, weight: .bold, relativeTo: .caption2)
                .tracking(0.44)
                .foregroundStyle(Theme.inkOnAccent)
                .padding(.vertical, 4)
                .padding(.horizontal, 9)
                .background(Capsule(style: .continuous).fill(Theme.accent))
            Spacer(minLength: 8)
            if mode == .open {
                Button(action: onOpen) {
                    Text("Open planner")
                        .scaledFont(14.5, weight: .semibold, relativeTo: .subheadline)
                        .foregroundStyle(Theme.primaryInk)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 32)
    }

    private var plannedCount: Int {
        days.count(where: { $0.title != nil })
    }

    private var openBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(MyTrayCopy.planSummary(plannedDays: plannedCount, totalDays: days.count))
                .scaledFont(14, relativeTo: .subheadline)
                .foregroundStyle(Theme.muted)
                .padding(.top, 2)
                .padding(.bottom, 14)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(days) { day in
                        Button(action: onOpen) { PlanDayCell(day: day) }
                            .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
            }
            .padding(.horizontal, -16)
        }
    }

    private var lockedBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(ghostLabels, id: \.self) { label in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(label)
                                .scaledFont(12, weight: .bold, relativeTo: .caption)
                                .foregroundStyle(Theme.muted)
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.lift)
                                .frame(width: Self.dayWidth, height: Self.dayWidth)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
            .scrollDisabled(true)
            .opacity(0.7)
            .padding(.top, 14)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 14) {
                Text("Plan the week once, and stop deciding what's for dinner every night.")
                    .roundedFont(17, weight: .semibold, relativeTo: .body)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onOpen) {
                    Text("Try Trays Plus")
                }
                .buttonStyle(.trayAccent)
            }
            .padding(.top, 18)
        }
    }

    /// Day labels for the ghost row: the real week when it has loaded, else
    /// seven blanks of the right shape.
    private var ghostLabels: [String] {
        days.isEmpty ? (0 ..< 7).map { String(repeating: " ", count: $0 + 1) } : days.map(\.label)
    }
}

/// One day of the open week: label, a square photo (or a dashed empty
/// square), and the dinner's name reserving two lines.
private struct PlanDayCell: View {
    let day: PlanWeekCard.Day

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(day.label)
                .scaledFont(12, weight: .bold, relativeTo: .caption)
                .foregroundStyle(day.isToday ? Theme.text : Theme.muted)
                .lineLimit(1)
            square
            if let title = day.title {
                Text(title)
                    .scaledFont(13, weight: .semibold, relativeTo: .footnote)
                    .foregroundStyle(Theme.text)
                    .lineLimit(2, reservesSpace: true)
            } else {
                Text("Not planned")
                    .scaledFont(13, relativeTo: .footnote)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2, reservesSpace: true)
            }
        }
        .frame(width: PlanWeekCard.dayWidth, alignment: .leading)
        .multilineTextAlignment(.leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var square: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        Group {
            if day.title != nil {
                PhotoSlot(url: day.photoURL, cornerRadius: 14)
            } else {
                shape
                    .strokeBorder(Theme.hairlineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                    }
            }
        }
        .frame(width: PlanWeekCard.dayWidth, height: PlanWeekCard.dayWidth)
        .overlay {
            if day.isToday {
                RoundedRectangle(cornerRadius: 18.5, style: .continuous)
                    .strokeBorder(Theme.accent, lineWidth: 2.5)
                    .padding(-4.5)
            }
        }
    }
}

private let previewWeek: [PlanWeekCard.Day] = [
    .init(id: "1", label: "Today", isToday: true, title: "Sesame chicken thighs"),
    .init(id: "2", label: "Fri", isToday: false, title: "Weeknight dal with a long name"),
    .init(id: "3", label: "Sat", isToday: false),
    .init(id: "4", label: "Sun", isToday: false, title: "Harissa chickpea stew"),
]

#Preview("Plan your week · open") {
    PlanWeekCard(mode: .open, days: previewWeek, onOpen: {}).padding().background(Theme.background)
}

#Preview("Plan your week · open dark") {
    PlanWeekCard(mode: .open, days: previewWeek, onOpen: {})
        .padding()
        .background(Theme.background)
        .preferredColorScheme(.dark)
}

#Preview("Plan your week · open largest text") {
    PlanWeekCard(mode: .open, days: previewWeek, onOpen: {})
        .padding()
        .background(Theme.background)
        .dynamicTypeSize(.accessibility5)
}

#Preview("Plan your week · locked") {
    PlanWeekCard(mode: .gated, days: [], onOpen: {}).padding().background(Theme.background)
}

#Preview("Plan your week · locked dark") {
    PlanWeekCard(mode: .gated, days: [], onOpen: {})
        .padding()
        .background(Theme.background)
        .preferredColorScheme(.dark)
}
