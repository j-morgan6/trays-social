import Foundation

/// W175: decoded body of `POST /api/v1/subscriptions/verify` (server side is W174).
///
/// This is a *receipt of what the server decided*, never something the client
/// acts on to unlock a feature directly. `AppState.isPlus` reads
/// `currentUser.isSubscriber` after a `/auth/me` refresh; nothing on this type
/// writes entitlement state. That indirection is what makes graceful re-lock
/// work — when a subscription lapses the server flips `is_subscriber` to false
/// and the next `/auth/me` re-locks the UI, with no data deleted.
struct SubscriptionVerification: Decodable, Sendable {
    let isSubscriber: Bool
    let productId: String?
    let environment: String?
    let originalTransactionId: String?

    // The server also returns `expires_at`. It is deliberately NOT decoded.
    //
    // W174 builds that value with `DateTime.from_unix(ms, :millisecond)`, which
    // serializes WITH fractional seconds ("2026-08-06T07:06:40.123Z"). The
    // shared APIClient decoder uses `.iso8601`, which rejects fractional
    // seconds. Decoding it as a `Date` would therefore throw on an HTTP *200* —
    // the purchase would succeed server-side, the client would treat it as a
    // failure, `transaction.finish()` would never run, and StoreKit would
    // redeliver that transaction forever.
    //
    // `Decodable` ignores unknown keys, so omitting it is safe. If a real expiry
    // is ever needed client-side, add a custom per-field decode here against
    // `.iso8601WithFractionalSeconds` — do not change the shipped W174 response
    // shape, which other clients may already depend on.
}
