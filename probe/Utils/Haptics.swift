import SwiftUI

struct Haptics {
    static func play(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard UserDefaults.standard.bool(forKey: "hapticsEnabled") else { return }
        
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}
