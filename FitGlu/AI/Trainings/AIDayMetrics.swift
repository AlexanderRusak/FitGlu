import Foundation

struct AIDayMetrics: Codable {
    struct ZoneBalance: Codable {
        let zbsScore: Int            // 0..100
        let timeRecovMin: Int
        let timeFatMin: Int
        let timeTransMin: Int
        let timeAnaMin: Int
        let timeStressMin: Int
    }
    struct Intensity: Codable {
        let rpe10: Int               // 0..10
        let peakHRPercent: Int       // % от HRmax
        let timeAt90plusMin: Int     // минут >=90% HRmax
        let sawRedZone: Bool
        let setsCount: Int?
    }
    struct Energy: Codable {
        let totalKcal: Int
        let stressSeconds: Int
        let kcalPerStressMin: Double?
    }
    struct Context: Codable {
        let hrMax: Int
        let hrRest: Int?
        /// Диапазоны зон (bpm). Ключи: "Recovery","Fat","Trans","Ana","Stress"
        let zonesBPM: [String: ClosedRange<Int>]
    }

    let dateISO: String             // YYYY-MM-DD
    let zoneBalance: ZoneBalance
    let intensity: Intensity
    let energy: Energy
    let context: Context?
}

/// Метрики КАЖДОЙ тренировки (совпадает с использованием в TrainingsScreen)
struct AITrainingMetrics: Codable {
    let id: Int64
    let title: String               // Walking / Strength / HIIT и т.д.
    let startHHmm: String
    let endHHmm: String
    let zoneBalance: AIDayMetrics.ZoneBalance
    let intensity: AIDayMetrics.Intensity
    let energy: AIDayMetrics.Energy
}

// MARK: - Helpers
extension Date {
    var isoDate: String { ISO8601DateFormatter().string(from: self).prefix(10).description }
}

extension Double {
    var minutesRounded: Int { Int((self / 60.0).rounded()) }
}

