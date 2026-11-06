import Foundation

struct Video: Identifiable, Hashable {
    let id: String
    let title: String
    let thumbnail: URL?
    let duration: String?
    let channel: String?
    let avatar: URL?
    let views: String?
    let published: String?
    let live: Bool

    init?(renderer v: JSON) {
        guard let id = v["videoId"].string, let title = v["title"].text else { return nil }
        self.id = id
        self.title = title
        thumbnail = v["thumbnail"].image
        duration = v["lengthText"].text
        channel = (v["ownerText"].exists ? v["ownerText"] : v["longBylineText"]).text
        avatar = v["channelThumbnailSupportedRenderers"]["channelThumbnailWithLinkRenderer"]["thumbnail"].image
            ?? v["avatar"]["decoratedAvatarViewModel"]["avatar"]["avatarViewModel"]["image"].image
        views = (v["shortViewCountText"].exists ? v["shortViewCountText"] : v["viewCountText"]).text
        published = v["publishedTimeText"].text
        live = v["badges"].array.contains { $0["metadataBadgeRenderer"]["style"].string == "BADGE_STYLE_TYPE_LIVE_NOW" }
            || v["thumbnailOverlays"].array.contains { $0["thumbnailOverlayTimeStatusRenderer"]["style"].string == "LIVE" }
    }

    init?(lockup l: JSON) {
        let meta = l["metadata"]["lockupMetadataViewModel"]
        guard l["contentType"].string == "LOCKUP_CONTENT_TYPE_VIDEO", let id = l["contentId"].string,
              let title = meta["title"].text else { return nil }
        self.id = id
        self.title = title
        let image = l["contentImage"]["thumbnailViewModel"]
        thumbnail = image["image"].image
        let badge = image["overlays"].array
            .flatMap { $0["thumbnailBottomOverlayViewModel"]["badges"].array }
            .map { $0["thumbnailBadgeViewModel"] }
            .first
        live = badge?["badgeStyle"].string == "THUMBNAIL_OVERLAY_BADGE_STYLE_LIVE"
        duration = live ? nil : badge?["text"].string
        avatar = meta["image"]["decoratedAvatarViewModel"]["avatar"]["avatarViewModel"]["image"].image
        let rows = meta["metadata"]["contentMetadataViewModel"]["metadataRows"].array
            .map { $0["metadataParts"].array.compactMap { $0["text"].text } }
            .filter { !$0.isEmpty }
        let stats = rows.count > 1 ? rows[1] : rows.first ?? []
        channel = rows.count > 1 ? rows[0].first : nil
        views = stats.first
        published = stats.count > 1 ? stats[1] : nil
    }

    var byline: String {
        [channel, views, published].compactMap { $0 }.joined(separator: " · ")
    }
}
