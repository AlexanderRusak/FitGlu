import Foundation

struct UserSettings: Codable {
    var goal: TrainingGoal
    var updatedAt: Date

    static let `default` = UserSettings(goal: .maintain, updatedAt: .now)
}
