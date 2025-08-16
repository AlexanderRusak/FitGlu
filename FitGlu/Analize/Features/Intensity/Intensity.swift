import Foundation

extension DailyAnalyzer {

    func intensityForTrainings(trainings: [TrainingRow],
                               hrSegments: [[HRPoint]],
                               hrMax: Int,
                               hrRest: Int,
                               minRedHold: TimeInterval = 20) -> [TrainingIntensity] {

        let z5Lower = z5.lowerBound
        return trainings.map { tr in
            let interval = Date(timeIntervalSince1970: tr.startTime)...Date(timeIntervalSince1970: tr.endTime)
            let segs = hrSegments.map { cutSegment($0, to: interval) }.filter { $0.count > 1 }
            let points = segs.flatMap { $0 }.sorted { $0.time < $1.time }
            let m = computeIntensity(points: points, hrMax: hrMax, hrRest: hrRest, z5Lower: z5Lower, minRedHold: minRedHold)
            return TrainingIntensity(id: tr.id,
                                     training: tr,
                                     peakHRPercent: m.peakPct,
                                     timeAbove90: m.timeAbove90,
                                     sawRedZone: m.sawRed,
                                     hrRPE10: m.rpe10,
                                     avgHR: Int(m.avgHR.rounded()),
                                     duration: m.duration)
        }
    }

    func intensityForDay(trainings: [TrainingRow],
                         hrSegments: [[HRPoint]],
                         hrMax: Int,
                         hrRest: Int,
                         minRedHold: TimeInterval = 20) -> DayIntensity {

        let ranges = trainings.map {
            Date(timeIntervalSince1970: $0.startTime)...Date(timeIntervalSince1970: $0.endTime)
        }
        func inAnyWorkout(_ t: Date) -> Bool { ranges.contains { $0.contains(t) } }

        let points = hrSegments.flatMap { $0 }.filter { inAnyWorkout($0.time) }.sorted { $0.time < $1.time }

        let z5Lower = z5.lowerBound
        let m = computeIntensity(points: points, hrMax: hrMax, hrRest: hrRest, z5Lower: z5Lower, minRedHold: minRedHold)
        return DayIntensity(peakHRPercent: m.peakPct, timeAbove90: m.timeAbove90, sawRedZone: m.sawRed, hrRPE10: m.rpe10)
    }
}

// сугубо внутренняя математика
private func computeIntensity(points: [HRPoint],
                              hrMax: Int,
                              hrRest: Int,
                              z5Lower: Int,
                              minRedHold: TimeInterval)
-> (peakPct: Double, timeAbove90: TimeInterval, sawRed: Bool, rpe10: Int, avgHR: Double, duration: TimeInterval) {

    guard !points.isEmpty, hrMax > hrRest else { return (0,0,false,0, Double(hrRest), 0) }

    let peak = points.map(\.bpm).max() ?? hrRest
    let peakPct = Double(peak) / Double(hrMax) * 100.0

    var sumHRxDT = 0.0, sumDT = 0.0, t90 = 0.0, hold = 0.0
    var sawRed = false
    let thr90 = Int((Double(hrMax) * 0.90).rounded())

    for i in 0..<(points.count - 1) {
        let p = points[i], q = points[i + 1]
        let dt = q.time.timeIntervalSince(p.time); guard dt > 0 else { continue }
        sumHRxDT += Double(p.bpm) * dt; sumDT += dt
        if p.bpm >= thr90 { t90 += dt }
        if p.bpm >= z5Lower { hold += dt; if hold >= minRedHold { sawRed = true } } else { hold = 0 }
    }

    let avgHR = sumDT > 0 ? (sumHRxDT / sumDT) : Double(hrRest)
    let hrr = Double(hrMax - hrRest)
    let hrR = max(0, min(1, (avgHR - Double(hrRest)) / hrr))
    let rpe10 = Int((hrR * 10).rounded())

    return (peakPct, t90, sawRed, rpe10, avgHR, sumDT)
}
