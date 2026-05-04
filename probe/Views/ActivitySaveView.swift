import SwiftUI

struct ActivitySaveDraft: Identifiable, Equatable {
    let id = UUID()
    
    let sport: Sport
    let durationText: String
    
    let currentBpmAtEnd: Int?
    let averageBpmText: String?
    let maxBpmText: String?
    
    let lapCount: Int
    let distanceText: String?
    
    let gpsWasEnabled: Bool
    let rrIntervalCount: Int?
    let ecgSampleCount: Int?
    let ecgWasAvailable: Bool
    
    let startedAt: Date?
    let endedAt: Date
}

struct ActivitySaveMetadata {
    let note: String
    let rpe: Int?
    let customTitle: String?
}

struct ActivitySaveView: View {
    let draft: ActivitySaveDraft
    let onSave: (ActivitySaveMetadata) -> Void
    let onDiscard: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var note = ""
    @State private var hasRPE = false
    @State private var rpe: Double = 5
    
    // Custom Title States
    @State private var customTitle: String? = nil
    @State private var isEditingTitle = false
    @State private var tempTitle = ""
    
    @State private var showingDiscardConfirmation = false
    @State private var showingRecordedData = false
    
    @State private var showingSensorAlert = false
    @State private var alertMetricName = ""
    
    var body: some View {
        NavigationStack {
            Form {
                workoutHeader
                summarySection
                effortSection
                notesSection
                recordedDataSection
                actionSection
            }
            .navigationTitle("Save Activity")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .alert("Activity Title", isPresented: $isEditingTitle) {
                TextField("Custom Name", text: $tempTitle)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    let trimmed = tempTitle.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty && trimmed != draft.sport.rawValue {
                        withAnimation {
                            customTitle = trimmed
                        }
                    }
                }
            } message: {
                Text("Enter a custom name for your activity.")
            }
            .alert("Discard activity?", isPresented: $showingDiscardConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    onDiscard()
                    dismiss()
                }
            } message: {
                Text("This will permanently discard the recorded data from this session.")
            }
            .alert("Not Supported", isPresented: $showingSensorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your connected sensor does not support recording \(alertMetricName).")
            }
        }
    }
    
    // MARK: Header
    
    private var workoutHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 64, height: 64)
                
                Image(systemName: customTitle == nil ? draft.sport.icon : "tag.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(customTitle ?? draft.sport.rawValue)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Button {
                        if customTitle != nil {
                            withAnimation {
                                customTitle = nil
                            }
                        } else {
                            tempTitle = draft.sport.rawValue
                            isEditingTitle = true
                        }
                    } label: {
                        Image(systemName: customTitle != nil ? "arrow.uturn.backward" : "pencil")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(customTitle != nil ? .red : .blue)
                            .padding(6)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.borderless)
                    .padding(.horizontal, 4)
                }
                
                Text("Ended at \(draft.endedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
    }
    
    // MARK: Summary Section
    
    private var summarySection: some View {
        Section("Workout Summary") {
            summaryRow(title: "Duration", value: draft.durationText, icon: "timer", color: .blue)
            
            summaryRow(
                title: draft.averageBpmText == nil ? "Last Heart Rate" : "Avg Heart Rate",
                value: "\(draft.averageBpmText ?? bpmFallbackText) bpm",
                icon: "heart.fill",
                color: .red
            )
            
            if let maxBpmText = draft.maxBpmText {
                summaryRow(title: "Max Heart Rate", value: "\(maxBpmText) bpm", icon: "heart.circle.fill", color: .pink)
            }
            
            summaryRow(title: "Laps", value: "\(draft.lapCount)", icon: "flag.fill", color: .orange)
            
            if let distanceText = draft.distanceText {
                summaryRow(title: "Distance", value: distanceText, icon: "point.topleft.down.curvedto.point.bottomright.up", color: .purple)
            }
        }
    }
    
    private func summaryRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Label {
                Text(title).foregroundColor(.primary)
            } icon: {
                Image(systemName: icon).foregroundColor(color)
            }
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
    }
    
    private var bpmFallbackText: String {
        draft.currentBpmAtEnd.map { "\($0)" } ?? "—"
    }
    
    // MARK: Effort Section
    
    private var effortSection: some View {
        Section {
            Toggle(isOn: $hasRPE.animation(.snappy)) {
                Label("Track RPE", systemImage: "gauge")
                    .foregroundColor(.primary)
            }
            .tint(.orange)
            
            if hasRPE {
                VStack(spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(Int(rpe))")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(.orange)
                        
                        Text("/ 10")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(rpeLabel(for: Int(rpe)))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $rpe, in: 1...10, step: 1)
                        .tint(.orange)
                    
                    HStack {
                        Text("Easy").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text("Max").font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: Notes Section
    
    private var notesSection: some View {
        Section("Notes") {
            TextField("Add context or training notes...", text: $note, axis: .vertical)
                .lineLimit(4...10)
                .padding(.vertical, 4)
        }
    }
    
    // MARK: Recorded Data Section
    
    private var recordedDataSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showingRecordedData) {
                if draft.gpsWasEnabled {
                    dataRow(title: "Location Route", detail: "Saved", icon: "location.fill", color: .green)
                }
                
                dataRow(title: "Heart Rate", detail: "Recorded", icon: "heart.fill", color: .red)
                
                if rrWasIncluded {
                    dataRow(title: "RR-Intervals", detail: "Recorded", icon: "waveform.path.ecg", color: .pink)
                } else {
                    unsupportedDataRow(title: "RR-Intervals", icon: "waveform.path.ecg", color: .pink)
                }
                
                if ecgWasIncluded {
                    dataRow(title: "ECG", detail: "Recorded", icon: "bolt.heart.fill", color: .blue)
                } else {
                    unsupportedDataRow(title: "ECG", icon: "bolt.heart.fill", color: .blue)
                }
            } label: {
                Label("Health Metrics", systemImage: "heart.text.square")
                    .foregroundColor(.primary)
            }
        }
    }
    
    private func dataRow(title: String, detail: String, icon: String, color: Color) -> some View {
        HStack {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon).foregroundColor(color)
            }
            Spacer()
            Text(detail)
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
    }
    
    private func unsupportedDataRow(title: String, icon: String, color: Color) -> some View {
        HStack {
            Label {
                Text(title)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: icon).foregroundColor(color.opacity(0.4))
            }
            
            Spacer()
            
            Button {
                alertMetricName = title
                showingSensorAlert = true
            } label: {
                HStack(spacing: 4) {
                    Text("Not Available")
                    Image(systemName: "questionmark.circle")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }
    
    private var rrWasIncluded: Bool {
        (draft.rrIntervalCount ?? 0) > 0
    }
    
    private var ecgWasIncluded: Bool {
        (draft.ecgSampleCount ?? 0) > 0
    }
    
    // MARK: Action Section
    
    private var actionSection: some View {
        Section {
            Button {
                saveActivity()
            } label: {
                Text("Save Activity")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            }
            .listRowBackground(Color.blue)
            .foregroundColor(.white)
            
            Button(role: .destructive) {
                showingDiscardConfirmation = true
            } label: {
                Text("Discard Activity")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    private func saveActivity() {
        let metadata = ActivitySaveMetadata(
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            rpe: hasRPE ? Int(rpe) : nil,
            customTitle: customTitle
        )
        onSave(metadata)
        dismiss()
    }
    
    // MARK: Helpers
    
    private func rpeLabel(for value: Int) -> String {
        switch value {
        case 1...2: return "Very easy"
        case 3...4: return "Easy"
        case 5...6: return "Moderate"
        case 7...8: return "Hard"
        case 9: return "Very hard"
        default: return "Max effort"
        }
    }
}
