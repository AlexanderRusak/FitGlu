import Foundation

struct DailySnapshotDataQuality: Codable {
    var hasKcal: Bool
}

struct DailySnapshot: Codable, Identifiable {
    var id: String // yyyy-MM-dd
    var date: Date // startOfDay
    var steps: Int
    var sleepMinutes: Int
    var restingHR: Int
    var baselineRHR: Int
    var weightKg: Double?
    var proteinG: Int
    var kcalTotal: Int?
    var readiness: Int
    var trainingReadiness: Int
    var trainingReadinessLabel: String
    var recoveryProgress: Double
    var lastTrainingType: String?
    var lastTrainingScore: Int?
    var analysisVersion: String
    var dataQuality: DailySnapshotDataQuality
    var createdAt: Date
}
