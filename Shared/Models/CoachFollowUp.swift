import Foundation

struct CoachFollowUp: Codable, Identifiable {
    var id: String // yyyy-MM-dd (day of evaluation)
    var date: Date
    var planDateId: String // вчера
    var proteinHit: Bool?
    var stepsHit: Bool?
    var sleepHit: Bool?
    var trainingDone: Bool?
    var weightDelta: Double?
    var restingHRDelta: Int?
    var createdAt: Date
}
