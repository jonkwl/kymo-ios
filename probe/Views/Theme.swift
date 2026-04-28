import SwiftUI

// MARK: App Branding
extension Color {
    static let proAccent = Color.blue
    static let proSuccess = Color.green
    static let proWarning = Color.orange
    static let proDanger = Color.red
    static let proBackground = Color(.systemGroupedBackground)
    static let proSecondaryBackground = Color(.secondarySystemGroupedBackground)
}

enum Theme {
    struct ClickyButtonStyle: ButtonStyle {
        let hapticWeight: UIImpactFeedbackGenerator.FeedbackStyle
        let cornerRadius: CGFloat
        let isClicky: Bool

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .scaleEffect(isClicky && configuration.isPressed ? 0.94 : 1.0)
                .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.6, blendDuration: 0), value: configuration.isPressed)
                .onChange(of: configuration.isPressed) { oldValue, newValue in
                    if newValue {
                        UIImpactFeedbackGenerator(style: hapticWeight).impactOccurred()
                    }
                }
        }
    }
    
    struct TelemetryCardStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.proSecondaryBackground)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: Global Components
struct SensorBatteryBadge: View {
    let batteryLevel: Int
    var showSensorIcon: Bool = false
    
    var body: some View {
        HStack(spacing: 6) {
            if showSensorIcon {
                Image(systemName: "sensor.tag.radiowaves.forward")
                    .font(.system(size: 10, weight: .bold))
            }
            
            HStack(spacing: 4) {
                Text("\(batteryLevel)%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                
                let iconName = batteryLevel > 80 ? "battery.100" :
                               batteryLevel > 50 ? "battery.75" :
                               batteryLevel > 20 ? "battery.50" : "battery.25"
                               
                Image(systemName: iconName)
                    .font(.system(size: 10))
            }
        }
        .foregroundColor(batteryLevel > 20 ? .proSuccess : .proDanger)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((batteryLevel > 20 ? Color.proSuccess : Color.proDanger).opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: View Extensions
extension View {
    func telemetryCard() -> some View {
        self.modifier(Theme.TelemetryCardStyle())
    }
    
    func clickyButton(weight: UIImpactFeedbackGenerator.FeedbackStyle = .light, cornerRadius: CGFloat = 18, isClicky: Bool = true) -> some View {
        self.buttonStyle(Theme.ClickyButtonStyle(hapticWeight: weight, cornerRadius: cornerRadius, isClicky: isClicky))
    }
}
