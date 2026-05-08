import SwiftUI

enum AppTheme: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2
    
    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

struct SettingsView: View {
    @Environment(\.openURL) private var openURL

    @AppStorage("userMaxHR") private var userMaxHR: Int = 190
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    
    @AppStorage("isHealthConnected") private var isHealthConnected = false
    @AppStorage("isStravaConnected") private var isStravaConnected = false
    @AppStorage("isIntervalsConnected") private var isIntervalsConnected = false
    
    var body: some View {
        NavigationStack {
                List {
                    // MARK: Integrations
                    Section {
                        integrationButton(
                            title: "Apple Health",
                            icon: "heart.text.square.fill",
                            color: .red,
                            isConnected: $isHealthConnected
                        )
                        
                        integrationButton(
                            title: "Strava",
                            icon: "figure.run.square.stack.fill",
                            color: .orange,
                            isConnected: $isStravaConnected
                        )
                        
                        integrationButton(
                            title: "Intervals.icu",
                            icon: "chart.bar.xaxis",
                            color: .blue,
                            isConnected: $isIntervalsConnected
                        )
                    } header: {
                        Text("Integrations")
                    } footer: {
                        Text("Connect your accounts to automatically sync completed workouts.")
                    }
                    
                    // MARK: Preferences
                    Section("Preferences") {
                        HStack {
                            Image(systemName: "heart.circle.fill")
                                .foregroundColor(.red)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Maximum Heart Rate")
                                    .foregroundColor(.primary)
                                Text("Used to calculate your personal HR Zones")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Picker("", selection: $userMaxHR) {
                                ForEach(100...220, id: \.self) { bpm in
                                    Text("\(bpm) BPM").tag(bpm)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.primary)
                        }
                        
                        Picker(selection: $appTheme) {
                            ForEach(AppTheme.allCases, id: \.self) { theme in
                                Text(theme.title).tag(theme)
                            }
                        } label: {
                            Label("Appearance", systemImage: "circle.lefthalf.filled")
                        }
                        
                        Toggle(isOn: $hapticsEnabled) {
                            Label("Haptic Feedback", systemImage: "hand.tap.fill")
                        }
                        .tint(.blue)
                    }
                    
                    // MARK: Support the Project
                    Section {
                        HStack(spacing: 12) {
                            tipCard(icon: "cup.and.saucer.fill", title: "Coffee", price: "$3", color: .brown)
                            tipCard(icon: "bolt.heart.fill", title: "Workout", price: "$5", color: .orange)
                            tipCard(icon: "heart.circle.fill", title: "Supporter", price: "$10", color: .purple)
                        }
                        .frame(maxWidth: .infinity)
                    } header: {
                        Text("Support the Developer")
                    } footer: {
                        Text("Kymo is ad-free and subscription-free. Tips help keep the app independent, polished, and updated.")
                    }
                    
                    // MARK: About
                    Section {
                        VStack(alignment: .center, spacing: 12) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundColor(.blue)
                            
                            Text("Kymo v0.1")
                                .font(.headline.weight(.bold))
                            
                            Text("Built for athletes, by athletes.\nThis is a privacy-first, open-source project. You don't need an account, and all your workout data stays strictly and securely on your own device.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                            
                            Button("View Source on GitHub") {
                                if let url = URL(string: "https://github.com/jonkwl/kymo-ios") {
                                    openURL(url)
                                }
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.blue)
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("Settings")
                .contentMargins(.top, 16, for: .scrollContent)
                .contentMargins(.bottom, 24, for: .scrollContent)
            }
    }
    
    // MARK: Subviews
    private func integrationButton(
        title: String,
        icon: String,
        color: Color,
        isConnected: Binding<Bool>
    ) -> some View {
        Button {
            Haptics.play(.medium)

            withAnimation(.snappy) {
                isConnected.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(isConnected.wrappedValue ? "Connected" : "Tap to connect")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer(minLength: 12)

                if isConnected.wrappedValue {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(color)
                        .frame(width: 28, height: 28)
                        .background(.white, in: Circle())
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(color.gradient.opacity(0.9))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    private func tipCard(icon: String, title: String, price: String, color: Color) -> some View {
        Button {
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(color)
                }
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.primary)
                    Text(price)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 110)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
