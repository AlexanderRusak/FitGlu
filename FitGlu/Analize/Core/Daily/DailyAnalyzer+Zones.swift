import Foundation

extension DailyAnalyzer {
    /// Маппинг bpm → зона
    func zone(for bpm: Int) -> ZoneKind {
        if bpm <= 30 { return .rec }
        if bpm >= 230 { return .stress }
        if bpm < z2.lowerBound { return .rec }
        if bpm < z3.lowerBound { return .fat }
        if bpm < z4.lowerBound { return .tran }
        if bpm < z5.lowerBound { return .ana }
        return .stress
    }

    /// Баланс зон 0–100
    func zoneBalance(tiz: TimeInZone) -> Double {
        let m = tiz.minutes
        let total = m.rec + m.fat + m.tran + m.ana + m.stress
        guard total > 0 else { return 0 }
        let raw = 0.0*m.rec + 1.0*m.fat + 1.5*m.tran + 2.0*m.ana - 1.0*m.stress
        let norm = (raw / (2.0 * total)) * 100.0
        return max(0, min(100, norm))
    }
}
