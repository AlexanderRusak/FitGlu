// DailyAnalyzer.swift
import Foundation

// MARK: - Public types

public struct TrainingQuality: Identifiable {
    public let id: Int64
    public let training: TrainingRow
    public let tiz: TimeInZone
    public let zoneBalanceScore: Double  // 0...100

    public init(id: Int64, training: TrainingRow, tiz: TimeInZone, zoneBalanceScore: Double) {
        self.id = id
        self.training = training
        self.tiz = tiz
        self.zoneBalanceScore = zoneBalanceScore
    }
}

public struct TimeInZone {
    public var rec: TimeInterval = 0   // Recovery (Z1)
    public var fat: TimeInterval = 0   // FatBurn  (Z2)
    public var tran: TimeInterval = 0  // Transition (Z3)
    public var ana: TimeInterval = 0   // Anabolic  (Z4)
    public var stress: TimeInterval = 0// Stress    (Z5+)

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

// MARK: - Analyzer

public final class DailyAnalyzer {

    public enum ZoneKind { case rec, fat, tran, ana, stress }

    private let z1: ClosedRange<Int>
    private let z2: ClosedRange<Int>
    private let z3: ClosedRange<Int>
    private let z4: ClosedRange<Int>
    private let z5: ClosedRange<Int>

    /// Конструктор из индивидуальных порогов
    public init(thresholds: ZoneThresholds) {
        self.z1 = thresholds.z1[0]...thresholds.z1[1]
        self.z2 = thresholds.z2[0]...thresholds.z2[1]
        self.z3 = thresholds.z3[0]...thresholds.z3[1]
        self.z4 = thresholds.z4[0]...thresholds.z4[1]
        self.z5 = thresholds.z5[0]...thresholds.z5[1]
    }

    /// Удобный хелпер, если порогов нет — используем дефолт по возрасту
    public static func withDefault(age: Int) -> DailyAnalyzer {
        let t = DefaultZonesProvider.estimate(age: age)
        return DailyAnalyzer(thresholds: t)
    }

    // MARK: - Public API

    /// Главный метод: оценка качества по всем тренировкам дня
    /// (оставляем internal, чтобы не требовать public для HRPoint)
    func analyzeDay(trainings: [TrainingRow],
                    hrSegments: [[HRPoint]]) -> [TrainingQuality] {

        trainings.map { tr in
            let interval = Date(timeIntervalSince1970: tr.startTime)
                        ... Date(timeIntervalSince1970: tr.endTime)

            // Берём только сегменты, которые пересекают тренировку, и подрезаем по границам
            let segs = hrSegments
                .map { cutSegment($0, to: interval) }
                .filter { $0.count > 1 }

            let tiz = accumulateTIZ(from: segs, within: interval)
            let score = zoneBalance(tiz: tiz)

            return TrainingQuality(id: tr.id, training: tr, tiz: tiz, zoneBalanceScore: score)
        }
    }

    // MARK: - Core

    /// Обрезаем сегмент под интервал тренировки и добавляем «соседние» точки
    private func cutSegment(_ seg: [HRPoint],
                            to interval: ClosedRange<Date>) -> [HRPoint] {

        guard !seg.isEmpty else { return [] }
        let s = seg.sorted { $0.time < $1.time }

        var result: [HRPoint] = []

        if let before = s.last(where: { $0.time < interval.lowerBound }) {
            result.append(before)
        }
        result.append(contentsOf: s.filter { interval.contains($0.time) })
        if let after = s.first(where: { $0.time > interval.upperBound }) {
            result.append(after)
        }
        return result
    }

    /// Накопление TIZ по «ступенчатой» кривой HR (hold-to-next)
    private func accumulateTIZ(from segments: [[HRPoint]],
                               within interval: ClosedRange<Date>) -> TimeInZone {

        var tiz = TimeInZone()

        for seg in segments where seg.count >= 2 {
            for i in 0..<(seg.count - 1) {
                let p = seg[i]
                let q = seg[i + 1]

                let t0 = max(p.time, interval.lowerBound)
                let t1 = min(q.time, interval.upperBound)
                guard t1 > t0 else { continue }

                let dt = t1.timeIntervalSince(t0)
                switch zone(for: p.bpm) {
                case .rec:    tiz.rec    += dt
                case .fat:    tiz.fat    += dt
                case .tran:   tiz.tran   += dt
                case .ana:    tiz.ana    += dt
                case .stress: tiz.stress += dt
                }
            }
        }
        return tiz
    }

    /// Определение зоны по bpm
    private func zone(for bpm: Int) -> ZoneKind {
        if z1.contains(bpm) { return .rec }
        if z2.contains(bpm) { return .fat }
        if z3.contains(bpm) { return .tran }
        if z4.contains(bpm) { return .ana }
        // всё, что выше z4 верхнего, считаем стрессом (включая z5)
        return .stress
    }

    /// Баланс зон 0–100
    private func zoneBalance(tiz: TimeInZone) -> Double {
        let m = tiz.minutes
        let totalActive = m.rec + m.fat + m.tran + m.ana + m.stress
        guard totalActive > 0 else { return 0 }

        let raw = 0.0*m.rec + 1.0*m.fat + 1.5*m.tran + 2.0*m.ana - 1.0*m.stress
        let norm = (raw / (2.0 * totalActive)) * 100.0     // максимум — вся тренировка в Z4
        return max(0, min(100, norm))
    }
}
