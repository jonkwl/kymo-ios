import SwiftUI

// MARK: HeartRateZone Utility
enum HeartRateZone: Int, CaseIterable {
    case zone1 = 1, zone2 = 2, zone3 = 3, zone4 = 4, zone5 = 5, none = 0
    
    var name: String {
        switch self {
        case .zone1: return "VERY LIGHT"
        case .zone2: return "LIGHT"
        case .zone3: return "MODERATE"
        case .zone4: return "HARD"
        case .zone5: return "MAXIMUM"
        default: return "WARMUP"
        }
    }
    
    var color: Color {
        switch self {
        case .zone1: return .gray
        case .zone2: return .blue
        case .zone3: return .green
        case .zone4: return .orange
        case .zone5: return .red
        default: return .secondary.opacity(0.5)
        }
    }
    
    static func current(bpm: Int, maxHR: Int) -> HeartRateZone {
        let percent = Double(bpm) / Double(maxHR)
        if percent >= 0.90 { return .zone5 }
        if percent >= 0.80 { return .zone4 }
        if percent >= 0.70 { return .zone3 }
        if percent >= 0.60 { return .zone2 }
        if percent >= 0.50 { return .zone1 }
        return .none
    }
}
