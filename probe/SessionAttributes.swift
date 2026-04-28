import Foundation
import ActivityKit

public struct SessionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentBpm: Int
        var elapsedTime: TimeInterval
    }

    var sessionName: String
}
