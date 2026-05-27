import Foundation

/// Hashable destination type pushed onto `AppState.navigationPath` when
/// the user taps the bell in `TopPill`. Lives here (rather than next to
/// the bell that triggers it) so any screen can push a notifications
/// destination without re-importing nav-shell internals.
struct NotificationRoute: Hashable {}
