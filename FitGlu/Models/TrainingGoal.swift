import Foundation

enum TrainingGoal: String, CaseIterable, Identifiable, Codable {
    case maintain
    case fatLoss
    case muscleGain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .maintain: return "Maintain"
        case .fatLoss: return "Fat loss"
        case .muscleGain: return "Muscle gain"
        }
    }

    var subtitle: String {
        switch self {
        case .maintain: return "Follow readiness & recovery."
        case .fatLoss: return "Control stress / intensity."
        case .muscleGain: return "Quality strength work + recovery."
        }
    }
}
