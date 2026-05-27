import Foundation

extension Date {
    /// Compact relative-time string used across feed/notification/comment
    /// rows: "now", "5m", "3h", "2d", "4w". Truncates rather than
    /// pluralizes — matches the prototype's terse "@author · 2h" style.
    func timeAgo() -> String {
        let seconds = -timeIntervalSinceNow
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h" }
        if seconds < 604_800 { return "\(Int(seconds / 86400))d" }
        return "\(Int(seconds / 604_800))w"
    }
}
