import Foundation

public extension Array where Element == ZoneDayPoint {
    /// Преобразует минутные значения в % по каждому дню (сумма ≈ 100).
    func normalizedToPercent() -> [ZoneDayPoint] {
        map { p in
            let tot = Swift.max(1.0, p.total) // защита от деления на 0
            return ZoneDayPoint(
                date: p.date,
                rec: (p.rec / tot) * 100.0,
                fat: (p.fat / tot) * 100.0,
                tran: (p.tran / tot) * 100.0,
                ana: (p.ana / tot) * 100.0,
                stress: (p.stress / tot) * 100.0
            )
        }
    }
}
