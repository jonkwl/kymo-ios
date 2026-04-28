import SwiftUI

enum Theme {
    
    struct TelemetryCardStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
                )
        }
    }
    
    struct PrimaryButtonStyle: ViewModifier {
        var isEnabled: Bool
        
        func body(content: Content) -> some View {
            content
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isEnabled ? Color.blue : Color(.systemGray4))
                .cornerRadius(12)
        }
    }
}

// MARK: View Extensions
extension View {
    func telemetryCard() -> some View {
        self.modifier(Theme.TelemetryCardStyle())
    }
    
    func primaryButton(isEnabled: Bool = true) -> some View {
        self.modifier(Theme.PrimaryButtonStyle(isEnabled: isEnabled))
    }
}
