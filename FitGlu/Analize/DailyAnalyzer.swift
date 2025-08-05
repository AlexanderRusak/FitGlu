// DailyAnalyzer.swift
import Foundation

// MARK: - Public types (для UI)

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

/// Интенсивность отдельно по тренировке
public struct TrainingIntensity: Identifiable {
    public let id: Int64
    public let training: TrainingRow
    public let peakHRPercent: Double     // max(HR)/HRmax * 100
    public let timeAbove90: TimeInterval // сек > 90% HRmax
    public let sawRedZone: Bool          // был ли устойчивый Z5
    public let hrRPE10: Int              // 0...10 (по HR reserve)
    public let avgHR: Int                // средний HR за тренировку
    public let duration: TimeInterval    // длительность, сек
}

/// Интенсивность агрегированно за день
public struct DayIntensity {
    public let peakHRPercent: Double
    public let timeAbove90: TimeInterval
    public let sawRedZone: Bool
    public let hrRPE10: Int
    
    static let zero = DayIntensity(
        peakHRPercent: 0,
        timeAbove90: 0,
        sawRedZone: false,
        hrRPE10: 0
    )
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
    
    public static func estimateHRMax(from thresholds: ZoneThresholds, age: Int?) -> Int {
        if thresholds.z5.count >= 2 { return thresholds.z5[1] }
        if let age = age { return max(150, 220 - age) }
        return 190
    }

    /// Оценка HRrest по дневным точкам HR:
    /// берём 5-й перцентиль (устойчивее минимума). Fallback = 60.
    static func estimateHRRest(from hrPoints: [HRPoint], fallback: Int = 60) -> Int {
        let vals = hrPoints.map(\.bpm).sorted()
        guard vals.count >= 5 else { return fallback }
        let idx = max(0, Int(Double(vals.count) * 0.05))   // 5-й перцентиль
        return vals[idx]
    }

    // MARK: - PUBLIC API: Качество (TIZ/ZBS)

    /// Оценка качества по всем тренировкам дня
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

    // MARK: - PUBLIC API: Интенсивность/пики

    /// Интенсивность по каждой тренировке (использует точки HR внутри интервала тренировки)
    ///
    /// - Parameters:
    ///   - hrMax: индивидуальный HRmax
    ///   - hrRest: индивидуальный HRrest
    ///   - minRedHold: минимальная длительность (сек) для флага «видел красную зону»
    func intensityForTrainings(trainings: [TrainingRow],
                               hrSegments: [[HRPoint]],
                               hrMax: Int,
                               hrRest: Int,
                               minRedHold: TimeInterval = 20) -> [TrainingIntensity] {

        let z5Lower = z5.lowerBound  // нижняя граница пятой зоны
        return trainings.map { tr in
            let interval = Date(timeIntervalSince1970: tr.startTime)
                        ... Date(timeIntervalSince1970: tr.endTime)

            let segs = hrSegments
                .map { cutSegment($0, to: interval) }
                .filter { $0.count > 1 }

            let points = segs.flatMap { $0 }.sorted { $0.time < $1.time }
            let metrics = computeIntensity(points: points,
                                           hrMax: hrMax,
                                           hrRest: hrRest,
                                           z5Lower: z5Lower,
                                           minRedHold: minRedHold)

            return TrainingIntensity(
                id: tr.id,
                training: tr,
                peakHRPercent: metrics.peakPct,
                timeAbove90: metrics.timeAbove90,
                sawRedZone: metrics.sawRed,
                hrRPE10: metrics.rpe10,
                avgHR: Int(metrics.avgHR.rounded()),
                duration: metrics.duration
            )
        }
    }

    /// Интенсивность агрегированно за день (суммирует все тренировки)
    func intensityForDay(trainings: [TrainingRow],
                         hrSegments: [[HRPoint]],
                         hrMax: Int,
                         hrRest: Int,
                         minRedHold: TimeInterval = 20) -> DayIntensity {

        // Собираем все точки ТОЛЬКО внутри интервалов тренировок
        let ranges: [ClosedRange<Date>] = trainings.map {
            Date(timeIntervalSince1970: $0.startTime)...Date(timeIntervalSince1970: $0.endTime)
        }

        func inAnyWorkout(_ t: Date) -> Bool {
            for r in ranges where r.contains(t) { return true }
            return false
        }

        let points = hrSegments
            .flatMap { $0 }
            .filter { inAnyWorkout($0.time) }
            .sorted { $0.time < $1.time }

        let z5Lower = z5.lowerBound
        let m = computeIntensity(points: points,
                                 hrMax: hrMax,
                                 hrRest: hrRest,
                                 z5Lower: z5Lower,
                                 minRedHold: minRedHold)

        return DayIntensity(
            peakHRPercent: m.peakPct,
            timeAbove90: m.timeAbove90,
            sawRedZone: m.sawRed,
            hrRPE10: m.rpe10
        )
    }

    // MARK: - Core (внутренние helpers)

    /// Обрезаем сегмент под интервал тренировки и добавляем «соседние» точки
    func cutSegment(_ seg: [HRPoint],
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

    // MARK: - Edwards TRIMP (по TIZ) — опционально, на будущее

    /// Простой TRIMP по Edwards (веса 1..5)
    func trimpEdwards(from tiz: TimeInZone) -> Double {
        let m = tiz.minutes
        return 1.0*m.rec + 2.0*m.fat + 3.0*m.tran + 4.0*m.ana + 5.0*m.stress
    }

    // MARK: - Intensity math

    /// Расчёт интенсивности по последовательности точек HR (внутр. функция)
    private func computeIntensity(points: [HRPoint],
                                  hrMax: Int,
                                  hrRest: Int,
                                  z5Lower: Int,
                                  minRedHold: TimeInterval) -> (peakPct: Double,
                                                                timeAbove90: TimeInterval,
                                                                sawRed: Bool,
                                                                rpe10: Int,
                                                                avgHR: Double,
                                                                duration: TimeInterval) {

        guard !points.isEmpty, hrMax > hrRest else {
            return (0, 0, false, 0, Double(hrRest), 0)
        }

        // Пик %
        let peak = points.map(\.bpm).max() ?? hrRest
        let peakPct = Double(peak) / Double(hrMax) * 100.0

        // Взвешенное среднее HR и длительность
        var sumHRxDT = 0.0
        var sumDT    = 0.0
        var t90      = 0.0
        var hold     = 0.0
        var sawRed   = false

        let thr90 = Int((Double(hrMax) * 0.90).rounded())

        for i in 0..<(points.count - 1) {
            let p = points[i]
            let q = points[i + 1]
            let dt = q.time.timeIntervalSince(p.time)
            guard dt > 0 else { continue }

            sumHRxDT += Double(p.bpm) * dt
            sumDT    += dt

            if p.bpm >= thr90 { t90 += dt }

            if p.bpm >= z5Lower {
                hold += dt
                if hold >= minRedHold { sawRed = true }
            } else {
                hold = 0
            }
        }

        let avgHR = sumDT > 0 ? (sumHRxDT / sumDT) : Double(hrRest)

        // HR-RPE по резерву ЧСС
        let hrr = Double(hrMax - hrRest)
        let hrR = max(0, min(1, (avgHR - Double(hrRest)) / hrr))
        let rpe10 = Int((hrR * 10).rounded())

        return (peakPct, t90, sawRed, rpe10, avgHR, sumDT)
    }
    
}
