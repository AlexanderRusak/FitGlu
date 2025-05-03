// Shared/HealthKit/HKWorkoutActivityType+Readable.swift
import HealthKit

extension HKWorkoutActivityType {
    var readableName: String {
        switch self {
        case .running:                     return "Running"
        case .walking:                     return "Walking"
        case .functionalStrengthTraining,
             .traditionalStrengthTraining: return "Strength Training"
        case .cycling:                     return "Cycling"
        // добавляйте нужные вам варианты ↓
        default:                           return "Other"
        }
    }
}
