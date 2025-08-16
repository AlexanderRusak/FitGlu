//
//  SessionAnalyzer.swift
//  HR-CGM Labs
//

import Foundation

// MARK: – DTO ----------------------------------------------------------------

public struct HRGlucosePoint: Identifiable, Codable {
    public let id = UUID()
    public let pulseTimestamp: TimeInterval     // сек
    public let glucoseTimestamp: TimeInterval   // сек (сырой CGM)
    public let pulse: Int                       // bpm
    public let glucose: Double                  // mg/dL

    /// точка со сдвигом глюкозы на «лаг»
    func withShiftedGlucose(by lag: TimeInterval) -> Self {
        .init(pulseTimestamp: pulseTimestamp,
              glucoseTimestamp: glucoseTimestamp - lag,
              pulse: pulse,
              glucose: glucose)
    }
}

public struct WorkoutChunk: Identifiable, Codable {
    public let id: Int64
    public let type: String
    public let start, end: TimeInterval
    public let points: [HRGlucosePoint]

    /// удобный «копировщик» с заменой точек
    func copy(points new: [HRGlucosePoint]) -> Self {
        .init(id: id, type: type, start: start, end: end, points: new)
    }
}

public struct ZoneThresholds: Codable {
    public let z1, z2, z3, z4, z5: [Int]   // [low, high]
}

public struct SessionDTO: Identifiable, Codable {
    public let id = UUID()
    public let start, end: TimeInterval
    public let workouts: [WorkoutChunk]
    public let lag: Double                // мс
    public let zones: ZoneThresholds
}

// MARK: – SessionAnalyzer ----------------------------------------------------

public enum SessionAnalyzer {

    // Конфигурируемые константы для будущей настройки
    private static let MAX_TRAINING_GAP: TimeInterval = 600       // сек – максимальный разрыв между тренировками для объединения в одну сессию
    private static let DEFAULT_MIN_LAG_MS: Int = 300_000          // мс – минимальное значение лага между пульсом и глюкозой
    private static let DEFAULT_MAX_LAG_MS: Int = 1_800_000        // мс – максимальное значение лага между пульсом и глюкозой
    private static let DEFAULT_LAG_STEP_MS: Int = 1_000           // мс – шаг изменения лага при переборе корреляции
    private static let MIN_CORRELATION_POINTS: Int = 3            // минимальное число совпадающих точек HR–CGM для расчёта корреляции

    // ————— public API ——————————————————————————————————————————————
    static func makeSessions(hrSegments: [[HRPoint]],
                             glucose: [GlucoseRow],
                             trainings: [TrainingRow]) -> [SessionDTO] {

        // 1. плоский HR-массив
        let hr = hrSegments.flatMap { $0 }.sorted { $0.time < $1.time }
        guard !hr.isEmpty, !glucose.isEmpty, !trainings.isEmpty else { return [] }

        // 2. склеиваем тренировки в «цепочки»
        let sortedTR = trainings.sorted { $0.startTime < $1.startTime }
        var chains = [[TrainingRow]]()
        var chain = [sortedTR.first!]
        for t in sortedTR.dropFirst() {
            if t.startTime - chain.last!.endTime <= MAX_TRAINING_GAP {
                chain.append(t)
            } else {
                chains.append(chain)
                chain = [t]
            }
        }
        chains.append(chain)

        // 3. интерполяция CGM ------------------------------------------------
        let g = glucose.sorted { $0.timestamp < $1.timestamp }

        func interp(_ ts: TimeInterval) -> Double {
            if ts <= g.first!.timestamp { return g.first!.glucoseValue.round3 }
            if ts >= g.last!.timestamp  { return g.last!.glucoseValue.round3 }

            var lo = 0, hi = g.count - 1
            while hi - lo > 1 {
                let mid = (lo + hi) / 2
                (g[mid].timestamp <= ts) ? (lo = mid) : (hi = mid)
            }
            let (t0, t1) = (g[lo].timestamp, g[hi].timestamp)
            let (v0, v1) = (g[lo].glucoseValue, g[hi].glucoseValue)
            return (v0 + (ts - t0) / (t1 - t0) * (v1 - v0)).round3
        }

        func points(in tr: TrainingRow) -> [HRGlucosePoint] {
            let r = tr.startTime ... tr.endTime
            return hr.lazy
                .filter { r.contains($0.time.timeIntervalSince1970) }
                .map {
                    let ts = $0.time.timeIntervalSince1970
                    return HRGlucosePoint(pulseTimestamp: ts,
                                          glucoseTimestamp: ts,
                                          pulse: $0.bpm,
                                          glucose: interp(ts))
                }
        }

        // 4. формируем SessionDTO -------------------------------------------
        var sessions = [SessionDTO]()

        for chain in chains {
            let chunks = chain.compactMap { tr -> WorkoutChunk? in
                let pts = points(in: tr)
                return pts.isEmpty ? nil :
                    .init(id: tr.id, type: tr.type,
                          start: tr.startTime, end: tr.endTime, points: pts)
            }
            guard !chunks.isEmpty else { continue }

            // —— лаг (расчёт оптимального сдвига между пульсом и глюкозой)
            let lagMs = calcLag(points: chunks.flatMap(\.points),
                                minLag: DEFAULT_MIN_LAG_MS,
                                maxLag: DEFAULT_MAX_LAG_MS,
                                step: DEFAULT_LAG_STEP_MS)

            // —— сдвигаем глюкозу
            let shifted = chunks.map {
                $0.copy(points: $0.points.map { $0.withShiftedGlucose(by: lagMs/1_000) })
            }

            // —— пульсовые зоны
            let zones = ZoneCalculator.estimate(from: shifted.flatMap(\.points))

            sessions.append(.init(start: shifted.first!.start,
                                  end: shifted.last!.end,
                                  workouts: shifted,
                                  lag: lagMs,
                                  zones: zones))
        }

        // — DEBUG JSON —
        if  let data = try? JSONEncoder.pretty.encode(sessions),
            let js   = String(data: data, encoding: .utf8) {
            print("===== HR–CGM Sessions JSON =====\n\(js)")
        }
        return sessions
    }

    // ————— private helpers ————————————————————————————————————————
    private static func calcLag(points: [HRGlucosePoint],
                                minLag: Int = DEFAULT_MIN_LAG_MS,
                                maxLag: Int = DEFAULT_MAX_LAG_MS,
                                step: Int = DEFAULT_LAG_STEP_MS) -> Double {

        guard points.count >= MIN_CORRELATION_POINTS else { return .zero }

        let pByT = Dictionary(uniqueKeysWithValues:
            points.map { (Int($0.pulseTimestamp.rounded()), Double($0.pulse)) })
        let gByT = Dictionary(uniqueKeysWithValues:
            points.map { (Int($0.glucoseTimestamp.rounded()), $0.glucose) })

        var bestLag = 0, bestR = -Double.infinity
        var lag = minLag
        while lag <= maxLag {
            var x = [Double](), y = [Double]()
            for (t, p) in pByT {
                if let g = gByT[t + lag / 1_000] {
                    x.append(p)
                    y.append(g)
                }
            }
            if x.count >= MIN_CORRELATION_POINTS {
                let r = pearson(x, y)
                if r > bestR {
                    bestR = r
                    bestLag = lag
                }
            }
            lag += step
        }
        return Double(bestLag)
    }

    private static func pearson(_ x: [Double], _ y: [Double]) -> Double {
        let n = Double(x.count)
        guard n > 1 else { return .nan }
        let mx = x.reduce(0,+)/n, my = y.reduce(0,+)/n
        var num = 0.0, sx = 0.0, sy = 0.0
        for i in 0..<x.count {
            let dx = x[i] - mx, dy = y[i] - my
            num += dx*dy; sx += dx*dx; sy += dy*dy
        }
        let denom = (sx*sy).squareRoot()
        return denom > 0 ? num/denom : .nan
    }
}

// MARK: – ZoneCalculator (глюкоза + пульс) -----------------------------------

private struct ZoneCalculator {

    // Константы для расчёта зон
    private static let DEFAULT_GLUCOSE_RISE: Double = 3.0    // mg/dL – минимальный подъём глюкозы для обнаружения гликемического порога
    private static let DEFAULT_GLUCOSE_WEIGHT: Double = 1.0  // (0…1) – вес гликемического порога при расчёте анаэробного порога
    private static let ZONE1_HIGH_FRACTION: Double = 0.75    // доля от анаэробного порога (thr) для верхней границы зоны 1
    private static let TRANSITION_FRACTION: Double = 0.90    // доля от анаэробного порога (thr) для границы между зонами 2 и 3
    private static let HR_PERCENTILE_LOW: Double = 60.0      // % – нижний целевой процентиль распределения HR
    private static let HR_PERCENTILE_HIGH: Double = 80.0     // % – высокий целевой процентиль распределения HR
    private static let HR_PERCENTILE_TOP: Double = 95.0      // % – верхний (пиковый) процентиль распределения HR

    /// Determine HR zones using glucose response thresholds.
    /// - glucoseRise: minimum glucose increase (mg/dL) to detect the glycemic threshold.
    /// - glucoseWeight: weight (0…1) given to the glycemic threshold vs. HR distribution.
    static func estimate(from pts: [HRGlucosePoint],
                         glucoseRise: Double = DEFAULT_GLUCOSE_RISE,
                         glucoseWeight: Double = DEFAULT_GLUCOSE_WEIGHT) -> ZoneThresholds {
        guard !pts.isEmpty else {
            return ZoneThresholds(z1: [0,0], z2: [0,0], z3: [0,0], z4: [0,0], z5: [0,0])
        }

        let sorted = pts.sorted { $0.pulseTimestamp < $1.pulseTimestamp }
        let allHR = sorted.map(\.pulse)
        let maxHR = allHR.max() ?? 0

        // Calculate HR percentiles
        let hr60 = allHR.percentile(HR_PERCENTILE_LOW)
        let hr80 = allHR.percentile(HR_PERCENTILE_HIGH)
        let hr95 = allHR.percentile(HR_PERCENTILE_TOP)

        // Identify glycemic threshold (HR_GT) where glucose rises at least `glucoseRise` from its minimum
        var gMin = sorted.first!.glucose
        var idxMin = 0
        for (i, point) in sorted.enumerated() {
            if point.glucose < gMin {
                gMin = point.glucose
                idxMin = i
            }
        }
        var hrGT: Int? = nil
        for j in (idxMin + 1)..<sorted.count {
            if sorted[j].glucose >= gMin + glucoseRise {
                hrGT = sorted[idxMin].pulse
                break
            }
        }

        // Determine threshold HR for zone 3/4 (anaerobic threshold)
        let thr: Int = {
            if let gt = hrGT {
                // Combine glycemic threshold and HR distribution (ensure not below 80th percentile)
                let combined = glucoseWeight * Double(gt) + (1 - glucoseWeight) * Double(hr80)
                return max(hr80, Int(combined.rounded()))
            } else {
                // Fallback: use 95th percentile if no glycemic threshold found
                return hr95
            }
        }()

        // Define transition threshold at ~90% of anaerobic threshold
        let transHR = Int(floor(TRANSITION_FRACTION * Double(thr)))

        // Calculate zone boundaries
        let z1Low = allHR.min() ?? 0
        let z1High = Int(floor(ZONE1_HIGH_FRACTION * Double(thr)))
        let z2Low = z1High + 1
        let z2High = transHR - 1
        let z3Low = transHR
        let z3High = thr - 1
        let z4Low = thr
        // Split remaining range between zone 4 and zone 5
        let mid = (thr + maxHR) / 2
        let z4High = mid
        let z5Low = (mid < maxHR) ? (mid + 1) : maxHR
        let z5High = maxHR

        return ZoneThresholds(
            z1: [min(z1Low, z1High), max(z1Low, z1High)],
            z2: [min(z2Low, z2High), max(z2Low, z2High)],
            z3: [min(z3Low, z3High), max(z3Low, z3High)],
            z4: [min(z4Low, z4High), max(z4Low, z4High)],
            z5: [min(z5Low, z5High), max(z5Low, z5High)]
        )
    }
}

// MARK: – helpers ------------------------------------------------------------

private extension Double { var round3: Double { (self*1_000).rounded()/1_000 } }

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return e
    }
}

// быстрый целочисленный перцентиль
private extension Array where Element == Int {
    func percentile(_ p: Double) -> Int {
        guard !isEmpty else { return 0 }
        let s = sorted()
        let pos = p / 100 * Double(s.count - 1)
        return s[Int(pos.rounded())]
    }
}
