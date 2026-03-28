import Foundation

public struct AIPeriodMetrics: Codable {
    public struct DayZBS: Codable {
        public let dateISO: String
        public let zbsScore: Int?          // если считаешь средний ZBS по дням
        public let recMin: Int
        public let fatMin: Int
        public let tranMin: Int
        public let anaMin: Int
        public let stressMin: Int
        public var totalMin: Int { recMin + fatMin + tranMin + anaMin + stressMin }
    }

    public struct Intensity: Codable {
        public let avgRPE10: Int           // взвешенный по длительности
        public let peakHRPercent: Int      // макс. % HRmax в периоде
        public let timeAt90plusMin: Int    // сумма минут ≥90% HR за период
        public let sawRedAny: Bool         // был ли вход в красную зону
    }

    public struct Energy: Codable {
        public let totalKcal: Int
        public let stressMinutes: Int
        public let kcalPerStressMin: Double?
    }

    public struct Totals: Codable {
        public let recMin: Int
        public let fatMin: Int
        public let tranMin: Int
        public let anaMin: Int
        public let stressMin: Int

        public var totalMin: Int { recMin + fatMin + tranMin + anaMin + stressMin }
        public func pct(_ x: Int) -> Int { totalMin > 0 ? Int(round(Double(x) * 100.0 / Double(totalMin))) : 0 }
    }

    public struct Context: Codable {
        public let hrMax: Int?
        public let hrRest: Int?
        public let zonesBPM: [String: ClosedRange<Int>]?
        public let age: Int?
        public let sex: String?
        public let bodyMassKg: Double?
    }

    public let periodLabel: String        // например, "2025-09-22–2025-10-05"
    public let daysCount: Int
    public let mode: String               // "minutes" или "percent"
    public let totals: Totals
    public let perDay: [DayZBS]           // ограничим до 14–21, чтобы не раздувать промпт
    public let intensity: Intensity
    public let energy: Energy
    public let avgZBS: Int?               // если считаешь в периоде средний по дням
    public let context: Context?
}
