import HealthKit

extension HKWorkoutActivityType {
    /// Имя как в Workout.app (English locale)
    var workoutName: String {
        switch self {
        case .running:                      "Running"
        case .walking:                      "Walking"
        case .cycling:                      "Cycling"
        case .functionalStrengthTraining:   "Functional Strength Training"
        case .traditionalStrengthTraining:  "Traditional Strength Training"
        // …добавляйте по мере необходимости…
        default:                            "Other"
        }
    }
}
