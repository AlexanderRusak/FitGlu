import Foundation

// небольшой хелпер
private extension Array where Element == Int {
    func percentile(_ p: Double) -> Int? {
        guard !isEmpty else { return nil }
        let s = self.sorted()
        let idx = Swift.max(0, Swift.min(s.count - 1,
                              Int(round((p/100.0) * Double(s.count - 1)))))
        return s[idx]
    }
}

extension DailyAnalyzer {
    /// Единая, «умная» оценка HRmax для конкретного дня.
    static func hrMaxForDay(
        thresholds: ZoneThresholds,
        hrPoints: [HRPoint],
        useStandardZones: Bool,
        age: Int?
    ) -> Int {
        // 5) если включён режим "220−возраст"
        let formula: Int = {
            guard let age else { return 190 }
            return Swift.min(230, Swift.max(150, 220 - age))
        }()

        // 1) верх Z5
        let z5hi: Int = thresholds.z5.count >= 2 ? Swift.max(thresholds.z5[0], thresholds.z5[1]) : 0

        // 2) фактический пик
        let workoutBPM = hrPoints.filter(\.inWorkout).map(\.bpm)
        let observedPeak = workoutBPM.max() ?? 0

        // 3) 95-й перцентиль
        let p95 = workoutBPM.percentile(95) ?? 0

        // 4) верх Z4 → HRmax через 90%
        let z4hi = thresholds.z4.count >= 2 ? Swift.max(thresholds.z4[0], thresholds.z4[1]) : 0
        let backFrom90 = z4hi > 0 ? Int(ceil(Double(z4hi) / 0.90)) : 0

        // кандидаты
        var candidates = [z5hi, observedPeak, p95, backFrom90]
        if useStandardZones { candidates.append(formula) }

        // итог
        let best = candidates.filter { (120...240).contains($0) }.max() ?? formula
        return Swift.min(230, Swift.max(150, best))
    }

    /// Устойчивый HRrest
    static func estimateHRRestSmart(from hrPoints: [HRPoint], fallback: Int = 60) -> Int {
        let quiet = hrPoints.filter { !$0.inWorkout }.map(\.bpm)
        if let p5 = quiet.percentile(5), (35...100).contains(p5) { return p5 }
        let all = hrPoints.map(\.bpm)
        if let p5 = all.percentile(5), (35...100).contains(p5) { return p5 }
        return fallback
    }
    
    static func bpmAt90Percent(thresholds: ZoneThresholds, hrMax: Int) -> Int {
        let z4hi = thresholds.z4.count >= 2 ? Swift.max(thresholds.z4[0], thresholds.z4[1]) : 0
        let p90  = Int(round(0.90 * Double(hrMax)))
        return Swift.max(z4hi, p90)
    }
}
