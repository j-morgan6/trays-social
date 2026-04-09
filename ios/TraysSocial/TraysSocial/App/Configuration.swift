import Foundation

enum Configuration {
    static var apiBaseURL: String {
        guard let url = Bundle.main.infoDictionary?["API_BASE_URL"] as? String else {
            fatalError("API_BASE_URL not set in Info.plist")
        }
        return url
    }
}
