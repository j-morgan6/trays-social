import Foundation

/// W241: the greeting above Home ("Thursday evening" / "What are you
/// cooking, ren?"). Pure so it can be tested with a fixed calendar.
enum HomeGreeting {
    enum DayPart: Equatable {
        case morning
        case afternoon
        case evening
        case night

        /// Morning 5-11, afternoon 12-16, evening 17-21, night otherwise.
        static func of(hour: Int) -> DayPart {
            switch hour {
            case 5 ... 11: .morning
            case 12 ... 16: .afternoon
            case 17 ... 21: .evening
            default: .night
            }
        }
    }

    /// Weekday and part of day in the calendar's locale and time zone,
    /// with the first letter capitalised ("Thursday evening").
    static func kicker(now: Date, calendar: Calendar = .current) -> String {
        let weekdayIndex = calendar.component(.weekday, from: now) - 1
        let weekday = calendar.weekdaySymbols[weekdayIndex]
        let phrase =
            switch DayPart.of(hour: calendar.component(.hour, from: now)) {
            case .morning: String(localized: "\(weekday) morning")
            case .afternoon: String(localized: "\(weekday) afternoon")
            case .evening: String(localized: "\(weekday) evening")
            case .night: String(localized: "\(weekday) night")
            }
        return phrase.prefix(1).uppercased() + phrase.dropFirst()
    }

    static func question(username: String?) -> String {
        guard let username, !username.isEmpty else {
            return String(localized: "What are you cooking?")
        }
        return String(localized: "What are you cooking, \(username)?")
    }
}

/// W241: a recipe posted within the last day carries the "New" badge on
/// Home's new-from-follows row. Future timestamps (clock skew) count as new.
enum RecipeFreshness {
    static let newWindow: TimeInterval = 24 * 60 * 60

    static func isNew(insertedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(insertedAt) < newWindow
    }
}

/// W241: the cook time shown on recipe cards, in the canvas format
/// ("25 min", "1 hr", "1 hr 30 min"). Nil when there is no positive time.
enum CookTime {
    static func label(minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else { return nil }
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 {
            return String(localized: "\(rest) min")
        }
        if rest == 0 {
            return String(localized: "\(hours) hr")
        }
        return String(localized: "\(hours) hr \(rest) min")
    }
}
