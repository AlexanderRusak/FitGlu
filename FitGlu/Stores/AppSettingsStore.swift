import Foundation
import Combine

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var goal: TrainingGoal {
        didSet { saveGoal(goal) }
    }

    private let key = "fitglu.trainingGoal.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.goal = Self.loadGoal(from: defaults, key: key) ?? .maintain
    }

    private func saveGoal(_ value: TrainingGoal) {
        defaults.set(value.rawValue, forKey: key)
    }

    private static func loadGoal(from defaults: UserDefaults, key: String) -> TrainingGoal? {
        guard let raw = defaults.string(forKey: key) else { return nil }
        return TrainingGoal(rawValue: raw)
    }
}
