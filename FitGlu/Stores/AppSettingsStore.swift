import Foundation
import Combine

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var goal: TrainingGoal {
        didSet {
            guard goal != oldValue else { return }
            local.saveUserSettings(UserSettings(goal: goal, updatedAt: .now))
        }
    }

    private let local: LocalDBProvider

    init(local: LocalDBProvider = LocalDBProvider()) {
        self.local = local
        self.goal = local.loadUserSettings().goal
    }
}
