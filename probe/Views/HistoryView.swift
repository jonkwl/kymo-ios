import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("November 2023") {
                    HStack {
                        Image(systemName: "heart.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Norwegian 4x4")
                                .font(.headline)
                            Text("Nov 14 • 48:12 • RPE 9")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("My Activities")
            .padding(.vertical, 16)
        }
    }
}
