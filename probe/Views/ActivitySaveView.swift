import SwiftUI

enum ActivityColor: String, CaseIterable, Identifiable, Codable, Equatable {
    case blue
    case green
    case orange
    case red
    case pink
    case purple
    case teal
    case yellow
    case gray
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .blue: return "Blue"
        case .green: return "Green"
        case .orange: return "Orange"
        case .red: return "Red"
        case .pink: return "Pink"
        case .purple: return "Purple"
        case .teal: return "Teal"
        case .yellow: return "Yellow"
        case .gray: return "Gray"
        }
    }
    
    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .pink: return .pink
        case .purple: return .purple
        case .teal: return .teal
        case .yellow: return .yellow
        case .gray: return .gray
        }
    }
}

struct ActivitySaveDraft: Identifiable, Equatable {
    let id = UUID()
    
    let sport: Sport
    let color: ActivityColor
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
    let color: ActivityColor
}

struct ActivitySaveView: View {
    let draft: ActivitySaveDraft
    let onSave: (ActivitySaveMetadata) -> Void
    let onDiscard: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var note = ""
    @State private var hasRPE = false
    @State private var rpe: Double = 5
    
    @State private var customTitle: String? = nil
    @State private var selectedColor: ActivityColor
    @State private var isEditingTitle = false
    @State private var tempTitle = ""
    @State private var isColorPickerVisible = false
    
    @State private var showingDiscardConfirmation = false
    @State private var showingRecordedData = false
    
    @State private var showingSensorAlert = false
    @State private var alertMetricName = ""
    
    init(
        draft: ActivitySaveDraft,
        onSave: @escaping (ActivitySaveMetadata) -> Void,
        onDiscard: @escaping () -> Void
    ) {
        self.draft = draft
        self.onSave = onSave
        self.onDiscard = onDiscard
        _selectedColor = State(initialValue: draft.color)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                workoutHeader
                
                if isColorPickerVisible {
                    colorSection
                }
                
                summarySection
                effortSection
                notesSection
                recordedDataSection
                actionSection
            }
            .animation(.default, value: isColorPickerVisible)
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
    
    private var workoutHeader: some View {
        HStack(spacing: 16) {
            Button {
                isColorPickerVisible.toggle()
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(selectedColor.color.opacity(0.16))
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: customTitle == nil ? draft.sport.icon : "tag.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(selectedColor.color)
                    }
                    
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Color.secondary)
                        .clipShape(Circle())
                        .offset(x: 2, y: 2)
                }
            }
            .buttonStyle(.plain)
            
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
                            .foregroundColor(customTitle != nil ? .red : selectedColor.color)
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
    
    private var colorSection: some View {
        Section("Icon Color") {
            LazyVGrid(columns: colorColumns, spacing: 14) {
                ForEach(ActivityColor.allCases) { activityColor in
                    Button {
                        withAnimation(.snappy) {
                            selectedColor = activityColor
                        }
                    } label: {
                        colorSwatch(for: activityColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(activityColor.title)
                    .accessibilityAddTraits(selectedColor == activityColor ? .isSelected : [])
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var colorColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    }
    
    private func colorSwatch(for activityColor: ActivityColor) -> some View {
        let isSelected = selectedColor == activityColor
        
        return HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(activityColor.color.opacity(0.18))
                    .frame(width: 30, height: 30)
                
                Circle()
                    .fill(activityColor.color)
                    .frame(width: 18, height: 18)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white)
                }
            }
            
            Text(activityColor.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.horizontal, 10)
        .background(isSelected ? activityColor.color.opacity(0.12) : Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? activityColor.color.opacity(0.6) : Color.clear, lineWidth: 1)
        }
    }
    
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
    
    private var notesSection: some View {
        Section("Notes") {
            TextField("Add context or training notes...", text: $note, axis: .vertical)
                .lineLimit(4...10)
                .padding(.vertical, 4)
        }
    }
    
    private var recordedDataSection: some View {
        Section {
            RecordedDataDisclosureBlock(
                isExpanded: $showingRecordedData,
                showLocationRoute: draft.gpsWasEnabled,
                rrIntervalsRecorded: (draft.rrIntervalCount ?? 0) > 0,
                ecgRecorded: (draft.ecgSampleCount ?? 0) > 0,
                showMissingSensorRows: true,
                onUnsupportedMetric: { name in
                    alertMetricName = name
                    showingSensorAlert = true
                },
                presentation: .form
            )
        }
    }
    
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
            customTitle: customTitle,
            color: selectedColor
        )
        onSave(metadata)
        dismiss()
    }
    
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
