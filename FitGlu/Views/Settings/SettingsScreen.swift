import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject var settings: AppSettingsStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    Picker("Training goal", selection: $settings.goal) {
                        ForEach(TrainingGoal.allCases) { g in
                            Text(g.title).tag(g)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(settings.goal.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
