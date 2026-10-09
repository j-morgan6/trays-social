import OSLog
import SwiftUI

@MainActor
@Observable
final class HomeViewModel {
    private(set) var payload: HomePayload?
    private(set) var isLoading = false

    private static let log = Logger(subsystem: "com.trays.social", category: "home")

    func load(now: Date = Date()) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: DataResponse<HomePayload> = try await APIClient.shared.get(
                path: "/home",
                queryItems: [.init(name: "today", value: Self.dayKey(for: now))]
            )
            payload = response.data
        } catch {
            // D95: read-path failures stay silent; keep showing the last Home.
            Self.log.error("home load failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// The user's local calendar day as `YYYY-MM-DD`, so Tonight matches
    /// their evening rather than the server's UTC date.
    static func dayKey(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
