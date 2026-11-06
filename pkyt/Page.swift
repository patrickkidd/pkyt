import Foundation

struct Page: Equatable {
    var videos: [Video] = []
    var next: String?

    init(videos: [Video], next: String?) {
        self.videos = videos
        self.next = next
    }

    init(_ json: JSON) throws {
        let tab = json["contents"]["twoColumnBrowseResultsRenderer"]["tabs"].array
            .first { $0["tabRenderer"]["selected"].value as? Bool == true }
        let lists = [
            tab?["tabRenderer"]["content"]["richGridRenderer"]["contents"],
            json["contents"]["twoColumnSearchResultsRenderer"]["primaryContents"]["sectionListRenderer"]["contents"],
        ].compactMap { $0 } + (json["onResponseReceivedActions"].array + json["onResponseReceivedCommands"].array)
            .flatMap { [$0["appendContinuationItemsAction"], $0["reloadContinuationItemsCommand"]] }
            .map { $0["continuationItems"] }
        let found = lists.filter(\.exists)
        guard !found.isEmpty else { throw FeedError.shape(json.keys.sorted()) }
        found.forEach { add($0.array) }
    }

    private mutating func add(_ items: [JSON]) {
        for item in items {
            let x = item["richItemRenderer"].exists ? item["richItemRenderer"]["content"] : item
            if let v = Video(renderer: x["videoRenderer"]) ?? Video(lockup: x["lockupViewModel"]) {
                videos.append(v)
            } else if x["itemSectionRenderer"].exists {
                add(x["itemSectionRenderer"]["contents"].array)
            } else if let t = x["continuationItemRenderer"]["continuationEndpoint"]["continuationCommand"]["token"].string {
                next = t
            }
        }
    }
}
