import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject var settings: AppSettingsStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    Picker("Training goal", selection: $settings.goal) {
                        ForEach(TrainingGoal.allCases) { g in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(g.title)
                                Text(g.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(g)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
