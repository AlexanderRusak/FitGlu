import Foundation

public struct EnergyTrainingEfficiency: Identifiable {
    public let id: Int64
    public let training: TrainingRow
    public let kcal: Double
    public let stressSec: TimeInterval
    public let kcalPerStressMin: Double
}

public struct EnergyDayEfficiency {
    public let totalKcal: Double
    public let totalStressSec: TimeInterval
    public let kcalPerStressMin: Double
}

public struct TrainingQuality: Identifiable {
    public let id: Int64
    public let training: TrainingRow
    public let tiz: TimeInZone
    public let zoneBalanceScore: Double
    public init(id: Int64, training: TrainingRow, tiz: TimeInZone, zoneBalanceScore: Double) {
        self.id = id; self.training = training; self.tiz = tiz; self.zoneBalanceScore = zoneBalanceScore
    }
}

public struct TimeInZone {
    public var rec: TimeInterval = 0
    public var fat: TimeInterval = 0
    public var tran: TimeInterval = 0
    public var ana: TimeInterval = 0
    public var stress: TimeInterval = 0
    public init() {}

    public var total: TimeInterval { rec + fat + tran + ana + stress }
    public var minutes: (rec: Double, fat: Double, tran: Double, ana: Double, stress: Double) {
        (rec/60, fat/60, tran/60, ana/60, stress/60)
    }
    public var percents: (rec: Double, fat: Double, tran: Double, ana: Double, stress: Double) {
        guard total > 0 else { return (0,0,0,0,0) }
        return (rec/total*100, fat/total*100, tran/total*100, ana/total*100, stress/total*100)
    }
}

public struct TrainingIntensity: Identifiable {
    public let id: Int64
    public let training: TrainingRow
    public let peakHRPercent: Double
    public let timeAbove90: TimeInterval
    public let sawRedZone: Bool
    public let hrRPE10: Int
    public let avgHR: Int
    public let duration: TimeInterval
}

public struct DayIntensity {
    public let peakHRPercent: Double
    public let timeAbove90: TimeInterval
    public let sawRedZone: Bool
    public let hrRPE10: Int
    public static let zero = DayIntensity(peakHRPercent: 0, timeAbove90: 0, sawRedZone: false, hrRPE10: 0)
}
