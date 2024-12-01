import Foundation

struct HeartRateZonesCalculator {
    static func getHeartRateZone(for heartRate: Double, age: Int, trainingType: TrainingType) -> HeartRateZone {
        let trainingZone = calculateZones(forAge: age, trainingType: trainingType)
        if heartRate < trainingZone.lowerBound {
            return .belowTarget
        } else if heartRate > trainingZone.upperBound {
            return .aboveTarget
        } else {
            return .withinTarget
        }
    }

    static func calculateZones(forAge age: Int, trainingType: TrainingType) -> TrainingZone {
        let maxHeartRate = 220 - age // Используем классическую формулу

        switch trainingType {
        case .fatBurning:
            return TrainingZone(lowerBound: 0.5 * Double(maxHeartRate), upperBound: 0.65 * Double(maxHeartRate))
        case .cardio:
            return TrainingZone(lowerBound: 0.65 * Double(maxHeartRate), upperBound: 0.85 * Double(maxHeartRate))
        case .highIntensity:
            return TrainingZone(lowerBound: 0.85 * Double(maxHeartRate), upperBound: Double(maxHeartRate))
        }
    }
}
