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

struct StartButton: View {
    let isConnected: Bool
    let selectedSportIcon: String
    let selectedSportName: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            TimelineView(.animation) { context in
                
                let time = context.date.timeIntervalSinceReferenceDate
                
                // Smooth floating motion (-1.5 → +1.5)
                let float = sin(time * 1.6) * 2
                
                // Smooth breathing glow
                let glowScale = 1 + (sin(time * 1.2) * 0.04)
                
                ZStack {
                    
                    // MARK: - Glow (alive)
                    Circle()
                        .fill(Color.blue.opacity(0.22))
                        .frame(width: 290, height: 290)
                        .blur(radius: 38)
                        .scaleEffect(glowScale)
                        .opacity(isConnected ? 1 : 0)
                    
                    // MARK: - Main Button (dark-mode friendly)
                    Circle()
                        .fill(
                            isConnected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.95),
                                        Color.cyan.opacity(0.9)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(Color(.tertiarySystemFill))
                        )
                        .frame(width: 230, height: 230)
                        .shadow(
                            color: isConnected
                                ? Color.black.opacity(0.25)
                                : .clear,
                            radius: isPressed ? 10 : 26,
                            x: 0,
                            y: isPressed ? 4 : 16
                        )
                        .scaleEffect(
                            isConnected
                            ? (isPressed ? 0.94 : 1.0)
                            : 0.96
                        )
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isPressed)
                    
                    // MARK: - Content (floating smoothly)
                    VStack(spacing: 12) {
                        Image(systemName: selectedSportIcon)
                            .font(.system(size: 58, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .offset(y: float)
                        
                        VStack(spacing: 2) {
                            Text("START")
                                .font(.system(.title2, design: .rounded).weight(.bold))
                            
                            Text(selectedSportName.uppercased())
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(
                                    isConnected
                                    ? .white.opacity(0.85)
                                    : .secondary
                                )
                        }
                    }
                    .foregroundColor(isConnected ? .white : .secondary)
                }
            }
        }
        .disabled(!isConnected)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .scaleEffect(isConnected ? 1.0 : 0.96)
        .animation(.snappy(duration: 0.35, extraBounce: 0.1), value: isConnected)
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
