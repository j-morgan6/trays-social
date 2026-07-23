import Foundation

/// W158: wire model for a native ad slot inside a feed-shaped list.
/// The server sends only targeting metadata — the creative itself is
/// resolved client-side through `AdProvider` (house ad for now).
struct AdSlot: Codable, Hashable, Sendable {
    let slot: Int
    let placement: String

    /// Report target id that stays unique across placements sharing slot
    /// indices (feed slot 0, find slot 0, and the cook-mode finish card are
    /// different ads; the server dedups open reports on this integer).
    var reportTargetID: Int {
        let base: Int
        switch placement {
        case "feed": base = 0
        case "find": base = 10_000
        case "cook_mode_finish": base = 20_000
        default: base = 90_000
        }
        return base + slot
    }
}

/// W158: root-level ad configuration attached to feed-shaped responses.
/// `enabled` gates every ad surface client-side (Cook Mode reads it via
/// `AdSettings`); `frequency` is the server's card interval (informational
/// on the client — the server already interleaves the items).
struct AdConfig: Decodable, Sendable {
    let enabled: Bool
    let frequency: Int
}

/// W158: discriminated-union feed element. The server tags items as
/// `{"type":"post","post":{...}}` / `{"type":"ad","ad":{...}}` when ads
/// are enabled, and falls back to legacy flat `Post` objects when not.
///
/// Decoding rules:
///   * An object containing a nested `post` or `ad` container is a tagged
///     item; the `type` string picks the case, and any unrecognized tag
///     decodes as `.unknown` instead of throwing (forward compatibility).
///   * Anything else decodes as a legacy flat `Post`. The flat/tagged split
///     deliberately keys on the presence of the nested containers, NOT the
///     `type` value — a flat `Post` carries its own `type` field whose value
///     can be "post", which would otherwise alias the tagged discriminator.
///   * Ad identity is a fresh client-side UUID: server slot indices repeat
///     per page, so reusing them would produce duplicate `ForEach` ids.
enum FeedItem: Identifiable, Hashable, Sendable {
    case post(Post)
    case ad(id: UUID, slot: AdSlot)
    case unknown(id: UUID)

    var id: String {
        switch self {
        case let .post(post): "post-\(post.id)"
        case let .ad(id, _): "ad-\(id.uuidString)"
        case let .unknown(id): "unknown-\(id.uuidString)"
        }
    }

    /// The wrapped post, when this item is one. Ad and unknown slots
    /// return nil, which lets list mutation helpers skip them naturally.
    var post: Post? {
        if case let .post(post) = self { return post }
        return nil
    }
}

extension FeedItem: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type
        case post
        case ad
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.post) || container.contains(.ad) {
            // Tagged union item.
            let type = try container.decodeIfPresent(String.self, forKey: .type)
            switch type {
            case "post":
                self = .post(try container.decode(Post.self, forKey: .post))
            case "ad":
                self = .ad(id: UUID(), slot: try container.decode(AdSlot.self, forKey: .ad))
            default:
                // Forward compatible: a tag this build doesn't know about
                // must not sink the whole page.
                self = .unknown(id: UUID())
            }
        } else {
            // Legacy flat Post object (ads disabled on the server).
            self = .post(try Post(from: decoder))
        }
    }
}
