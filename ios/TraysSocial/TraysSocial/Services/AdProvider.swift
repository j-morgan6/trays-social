import SwiftUI

/// W158: the creative rendered inside a sponsored card or tile.
struct AdCreative {
    let title: String
    let body: String
}

/// W158: provider seam for ad creatives. The views only ever talk to this
/// protocol, so swapping the stubbed house ad for a real network requires
/// no view changes.
@MainActor
protocol AdProviding {
    func creative(for slot: AdSlot) -> AdCreative
}

/// Stubbed first-party house ad. Same creative for every slot for now;
/// the slot is part of the signature so a real provider can target.
struct HouseAdProvider: AdProviding {
    func creative(for slot: AdSlot) -> AdCreative {
        AdCreative(
            title: String(localized: "Cook more with Trays"),
            body: String(localized: "Discover trending recipes from home cooks on Trays.")
        )
    }
}

/// W158: the single mutation point for the ad stack. When AdMob (or any
/// real network) lands, it replaces ONLY `HouseAdProvider` behind this
/// seam — `SponsoredCardView` / `SponsoredTileView` and the feed decoding
/// pipeline stay untouched.
@MainActor
enum AdProvider {
    static var current: any AdProviding = HouseAdProvider()
}

/// W158: process-wide snapshot of the server's `ad_config`. Feed and Find
/// ViewModels write it after each load; surfaces that don't own a feed
/// response (Cook Mode's completion screen) read it to decide whether to
/// show a sponsored card.
@MainActor
@Observable
final class AdSettings {
    static let shared = AdSettings()

    var config: AdConfig?
}
