import Foundation

struct CoachPlan: Codable, Identifiable {
    var id: String // yyyy-MM-dd
    var date: Date
    var goal: TrainingGoal
    var snapshotId: String
    var analysisVersion: String
    var planText: String
    var actions: [String] // 3 пункта
    var avoid: String
    var improve: String
    var motivation: String
    var createdAt: Date
}
