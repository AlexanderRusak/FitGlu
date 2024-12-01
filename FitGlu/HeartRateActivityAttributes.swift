import ActivityKit

struct HeartRateActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var heartRate: Int
        var trainingType: String
    }

    var name: String
}
