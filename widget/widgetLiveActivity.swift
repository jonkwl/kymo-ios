import ActivityKit
import WidgetKit
import SwiftUI

struct widgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionAttributes.self) { context in
            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(.blue)
                            .font(.system(size: 14, weight: .bold))
                        Text("ProCapture")
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("REC")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.2))
                    .clipShape(Capsule())
                    .foregroundColor(.red)
                }
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.sessionName.uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundColor(.gray)
                        
                        Text(formatTime(context.state.elapsedTime))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white)
                            .contentTransition(.identity)
                    }
                    
                    Spacer()
                    
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                        
                        Text("\(context.state.currentBpm)")
                            .font(.system(size: 42, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .contentTransition(.identity)
                        
                        Text("BPM")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.gray)
                            .padding(.bottom, 6)
                    }
                }
            }
            .padding(16)
            .activityBackgroundTint(Color(red: 28/255, green: 28/255, blue: 30/255))
            .activitySystemActionForegroundColor(Color.white)
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                        Text("\(context.state.currentBpm)")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .contentTransition(.identity)
                    }
                    .padding(.top, 4)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatTime(context.state.elapsedTime))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                        .monospacedDigit()
                        .contentTransition(.identity)
                        .padding(.top, 4)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.attributes.sessionName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                            Text("RECORDING")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.red)
                                .tracking(1)
                        }
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("\(context.state.currentBpm)")
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .contentTransition(.identity)
                }
                .padding(.horizontal, 4)
            } compactTrailing: {
                Text(formatTime(context.state.elapsedTime))
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundColor(.blue)
                    .monospacedDigit()
                    .contentTransition(.identity)
                    .padding(.horizontal, 4)
            } minimal: {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
