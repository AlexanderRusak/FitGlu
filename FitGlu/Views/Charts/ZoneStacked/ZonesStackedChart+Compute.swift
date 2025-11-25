// Views/Charts/ZonesStacked/ZonesStackedChart+Compute.swift
import SwiftUI

extension ZonesStackedChart {

    // MARK: – Slice (ручной стек через yStart/yEnd)
    struct Slice: Identifiable {
        let id = UUID()
        let day: Date
        let kind: ZoneKind
        let yStart: Double
        let yEnd: Double
        let value: Double
    }

    var slices: [Slice] {
        data.flatMap { point in
            var cursor = 0.0
            var items: [Slice] = []
            func push(_ kind: ZoneKind, _ value: Double) {
                guard value > 0 else { return }
                let s = Slice(
                    day: Calendar.current.startOfDay(for: point.date),
                    kind: kind,
                    yStart: cursor,
                    yEnd: cursor + value,
                    value: value
                )
                cursor += value
                items.append(s)
            }
            push(.rec, point.rec)
            push(.fat, point.fat)
            push(.tran, point.tran)
            push(.ana, point.ana)
            push(.stress, point.stress)
            return items.filter { visibleZones.contains($0.kind) }
        }
    }

    // totals для аннотаций
    struct DayTotal: Identifiable {
        let id = UUID()
        let date: Date
        let total: Double
    }
    var dayTotals: [DayTotal] { data.map { .init(date: Calendar.current.startOfDay(for: $0.date), total: $0.total) } }

    // Домены осей
    var yMaxMinutes: Double {
        let m = data.map(\.total).max() ?? 0
        let padded = m + 10
        return max(0, (ceil(padded / 10.0) * 10.0))
    }
    var yDomain: ClosedRange<Double> {
        mode == .minutes ? (0...yMaxMinutes) : (0...100)
    }
    var xDomain: ClosedRange<Date> {
        let s = data.first?.date ?? Date()
        let e = data.last?.date ?? Date()
        return s...e
    }

    // Среднее и полоса вокруг него (только Minutes)
    var avgTotalMinutes: Double {
        guard mode == .minutes, !data.isEmpty else { return 0 }
        let sum = data.reduce(0) { $0 + $1.total }
        return sum / Double(data.count)
    }
    var bandHalfMinutes: Double { mode == .minutes ? (yMaxMinutes * 0.10) : 0 }
    var bandLowMinutes: Double  { max(0, avgTotalMinutes - bandHalfMinutes) }
    var bandHighMinutes: Double { min(yMaxMinutes, avgTotalMinutes + bandHalfMinutes) }

    // Сводка периода
    public struct PeriodSummary {
        public let rec: Double, fat: Double, tran: Double, ana: Double, stress: Double
        public var total: Double { rec + fat + tran + ana + stress }
        public func pct(_ v: Double) -> Int { total > 0 ? Int(round(100 * v / total)) : 0 }
    }
    var summary: PeriodSummary {
        .init(
            rec:   data.reduce(0){ $0 + $1.rec },
            fat:   data.reduce(0){ $0 + $1.fat },
            tran:  data.reduce(0){ $0 + $1.tran },
            ana:   data.reduce(0){ $0 + $1.ana },
            stress:data.reduce(0){ $0 + $1.stress }
        )
    }

    // Утилиты
    func snapDate(_ x: Date) -> Date? {
        guard !data.isEmpty else { return nil }
        let cal = Calendar.current
        let d = cal.startOfDay(for: x)
        return data.min(by: { abs($0.date.timeIntervalSince(d)) < abs($1.date.timeIntervalSince(d)) })?.date
    }

    func totalsFor(day: Date) -> (total: Double, parts: [(ZoneKind, Double)])? {
        guard let p = data.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) else { return nil }
        let pairs: [(ZoneKind, Double)] = [
            (.rec, p.rec), (.fat, p.fat), (.tran, p.tran), (.ana, p.ana), (.stress, p.stress)
        ].filter { visibleZones.contains($0.0) && $0.1 > 0 }

        let total = pairs.reduce(0) { $0 + $1.1 }
        return (total, pairs)
    }
}
