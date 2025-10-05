import Foundation

/// Минуты в зонах за один день (дата → rec/fat/tran/ana/stress).
public struct ZoneDayPoint: Identifiable, Hashable {
    public let id = UUID()
    public let date: Date
    public let rec: Double
    public let fat: Double
    public let tran: Double
    public let ana: Double
    public let stress: Double

    public init(date: Date, rec: Double, fat: Double, tran: Double, ana: Double, stress: Double) {
        self.date = date
        self.rec = rec
        self.fat = fat
        self.tran = tran
        self.ana = ana
        self.stress = stress
    }

    /// Суммарные минуты за день.
    public var total: Double { rec + fat + tran + ana + stress }

    /// Представление в процентах (0…100 по каждой зоне).
    public func asPercent() -> ZoneDayPoint {
        guard total > 0 else { return self }
        func p(_ v: Double) -> Double { (v / total) * 100.0 }
        return ZoneDayPoint(date: date,
                            rec: p(rec), fat: p(fat), tran: p(tran), ana: p(ana), stress: p(stress))
    }
}
