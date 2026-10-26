import Foundation
import Testing
@testable import TVCore

@Test @MainActor func sourceOrderPersistsAndKeepsSourcesItDoesNotList() throws {
    let suite = "order." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let origin = URL(string: "https://example.com/sub")!
    let config = try Subscription.parse(Data(#"{"sites":[{"key":"a","name":"A","type":1,"api":"https://example.com/a"},{"key":"b","name":"B","type":1,"api":"https://example.com/b"},{"key":"c","name":"C","type":1,"api":"https://example.com/c"},{"key":"d","name":"D","type":1,"api":"https://example.com/d"}]}"#.utf8), origin: origin)
    let sites = config.sites
    let order = SourceOrder(defaults: defaults)
    #expect(order.isEmpty && !order.enabled)
    #expect(order.arrange(sites, origin: origin).map(\.key) == ["a", "b", "c", "d"])
    order.save([sites[2], sites[0], sites[1]], origin: origin)
    order.enabled = true
    // "d" is new: it follows, in the order given.
    #expect(order.arrange(sites, origin: origin).map(\.key) == ["c", "a", "b", "d"])
    let reloaded = SourceOrder(defaults: defaults)
    #expect(reloaded.enabled)
    #expect(reloaded.arrange(sites, origin: origin).map(\.key) == ["c", "a", "b", "d"])
    // Saving only some sources (another subscription turned off) keeps the rest after them.
    reloaded.save([sites[1], sites[0]], origin: origin)
    #expect(reloaded.arrange(sites, origin: origin).map(\.key) == ["b", "a", "c", "d"])
    // Keys are subscription-qualified: another subscription's "a" is not this one's.
    #expect(reloaded.arrange(sites, origin: URL(string: "https://other.example/sub")!).map(\.key) == ["a", "b", "c", "d"])
}

@Test @MainActor func sourceOrderArrangesEachGroup() throws {
    let suite = "order." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let origin = URL(string: "https://example.com/sub")!
    let config = try Subscription.parse(Data(#"{"sites":[{"key":"a","name":"A","type":1,"api":"https://example.com/a"},{"key":"b","name":"B","type":1,"api":"https://example.com/b"},{"key":"c","name":"C","type":1,"api":"https://example.com/c"},{"key":"d","name":"D","type":1,"api":"https://example.com/d"}]}"#.utf8), origin: origin)
    let sites = config.sites
    let groups = [
        SourceGroup(kind: .pinned, title: "Pinned Group", sites: [sites[0], sites[1]]),
        SourceGroup(kind: .subscription("https://example.com/sub"), title: "Sub", sites: [sites[2], sites[3]]),
    ]
    let order = SourceOrder(defaults: defaults)
    // Moving "d" to the top of the whole order moves it to the top of its own group; groups keep their places.
    order.save([sites[3], sites[1], sites[0], sites[2]], origin: origin)
    let arranged = order.arrange(groups, origin: origin)
    #expect(arranged.map(\.id) == ["pinned", "https://example.com/sub"])
    #expect(arranged.map { $0.sites.map(\.key) } == [["b", "a"], ["d", "c"]])
}
