import SwiftUI

// MARK: - Shared “Recorded Data” disclosure

enum RecordedDataPresentation {
    case form
    /// Saved-session detail: neutral chrome, no per-session accent color.
    case groupedCard
}

/// Disclosure group used from the save-activity form and the saved-session detail card.
struct RecordedDataDisclosureBlock: View {
    @Binding var isExpanded: Bool

    let showLocationRoute: Bool
    var locationRouteDetail: String = "Saved"
    let rrIntervalsRecorded: Bool
    let ecgRecorded: Bool

    /// Save flow: show “Not Available” for streams that were not captured. Detail flow: omit missing rows.
    let showMissingSensorRows: Bool
    var onUnsupportedMetric: ((String) -> Void)?

    var presentation: RecordedDataPresentation = .form

    var body: some View {
        Group {
            DisclosureGroup(isExpanded: $isExpanded) {
                switch presentation {
                case .form:
                    formDisclosureContent
                case .groupedCard:
                    groupedCardDisclosureContent
                }
            } label: {
                disclosureLabel
            }
        }
        .tint(presentation == .groupedCard ? .primary : .accentColor)
    }

    // MARK: Labels

    @ViewBuilder
    private var disclosureLabel: some View {
        switch presentation {
        case .form:
            Label("Recorded Data", systemImage: "heart.text.square")
                .foregroundStyle(.primary)
        case .groupedCard:
            HStack(spacing: 10) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.monochrome)
                Text("Recorded Data")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: Form (save sheet)

    @ViewBuilder
    private var formDisclosureContent: some View {
        if showLocationRoute {
            formRecordedRow(title: "Location Route", detail: locationRouteDetail, icon: "location.fill", color: .green)
        }

        formRecordedRow(title: "Heart Rate", detail: "Recorded", icon: "heart.fill", color: .red)

        if rrIntervalsRecorded {
            formRecordedRow(title: "RR-Intervals", detail: "Recorded", icon: "waveform.path.ecg", color: .pink)
        } else if showMissingSensorRows, let onUnsupportedMetric {
            formUnsupportedRow(title: "RR-Intervals", icon: "waveform.path.ecg", color: .pink, onTap: onUnsupportedMetric)
        }

        if ecgRecorded {
            formRecordedRow(title: "ECG", detail: "Recorded", icon: "bolt.heart.fill", color: .blue)
        } else if showMissingSensorRows, let onUnsupportedMetric {
            formUnsupportedRow(title: "ECG", icon: "bolt.heart.fill", color: .blue, onTap: onUnsupportedMetric)
        }
    }

    private func formRecordedRow(title: String, detail: String, icon: String, color: Color) -> some View {
        HStack {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon).foregroundStyle(color)
            }
            Spacer()
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func formUnsupportedRow(title: String, icon: String, color: Color, onTap: @escaping (String) -> Void) -> some View {
        HStack {
            Label {
                Text(title)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: icon).foregroundStyle(color.opacity(0.4))
            }

            Spacer()

            Button {
                onTap(title)
            } label: {
                HStack(spacing: 4) {
                    Text("Not Available")
                    Image(systemName: "questionmark.circle")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }

    // MARK: Grouped card (session detail)

    private var groupedCardDisclosureContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            groupedStreamRow(title: "Heart Rate", systemImage: "heart.fill")

            if rrIntervalsRecorded {
                groupedRowDivider
                groupedStreamRow(title: "RR-Intervals", systemImage: "waveform.path.ecg")
            }
            if ecgRecorded {
                groupedRowDivider
                groupedStreamRow(title: "ECG", systemImage: "bolt.heart.fill")
            }
        }
        .padding(.top, 6)
    }

    private var groupedRowDivider: some View {
        Divider()
            .padding(.leading, 48)
    }

    private func groupedStreamRow(title: String, systemImage: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Text("Recorded")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background {
                    Capsule(style: .continuous)
                        .fill(Color(.quaternarySystemFill))
                }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
