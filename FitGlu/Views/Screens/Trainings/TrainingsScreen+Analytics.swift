import SwiftUI

extension TrainingsScreen {
    @MainActor
      func loadData(force: Bool = false) async {
          guard !isLoading || force else { return }
          isLoading = true
          defer { isLoading = false }

          resetMetrics()

          if let rs = rangeStart, let re = rangeEnd, rs <= re {
              await loadRangeData(from: rs, to: re)
          } else {
              await detailsVM.load(for: selectedDate)   // тренировки / HR / глюкоза / шаги/сон/белок/вес
              await computeQuality()
          }
      }

    @MainActor
    func computeQuality() async {
        let thresholds = currentThresholds()
        activeThresholds = thresholds
        let analyzer = DailyAnalyzer(thresholds: thresholds)

        // 1) ZBS
        qualities = analyzer.analyzeDay(
            trainings: detailsVM.trainings,
            hrSegments: detailsVM.hrSegments
        )

        // 2) HRrest + базовый HRmax из БД/дефолт
        let hrRest = DailyAnalyzer.estimateHRRestSmart(from: detailsVM.hrDailyPoints)
        let hrMaxFromDBOrDefault: Int = HRMaxDBManager.shared.valueOrDefault(age: detailsVM.userAge)

        if let meta = HRMaxDBManager.shared.currentRecord() {
            print("🫀 HRrest=\(hrRest), HRmax(DB)=\(meta.value) (at \(Date(timeIntervalSince1970: meta.recordedAt)))")
        } else {
            print("🫀 HRrest=\(hrRest), HRmax(default)=\(hrMaxFromDBOrDefault)")
        }

        // 3) Пик за день
        let observedPeak = detailsVM.hrDailyPoints.filter(\.inWorkout).map(\.bpm).max() ?? 0
        print("⛰️ Observed peak bpm in workouts=\(observedPeak)")

        // ≥90% HR
        let evidSecAt90 = evidenceSecondsAt90(
            segments: detailsVM.hrSegments,
            thresholds: thresholds,
            hrMax: hrMaxFromDBOrDefault
        )

        // 4) Обновление «точки правды»
        if let tsOfPeak = detailsVM.hrDailyPoints.first(where: { $0.inWorkout && $0.bpm == observedPeak })?.time {
            let result = HRMaxDBManager.shared.bumpIfHigher(
                observed: observedPeak,
                recordedAt: tsOfPeak.timeIntervalSince1970,
                sourceTrainingId: detailsVM.trainings.first?.id,
                evidenceSecAt90: Int(evidSecAt90.rounded())
            )
            print("🗃️ HRMaxDB.bumpIfHigher → \(result)")
        }

        // 5) Какой HRmax использовать
        let hrMaxUsed: Int
        if useStandardZones {
            let age = detailsVM.userAge ?? 30
            hrMaxUsed = min(230, max(160, 220 - age))
            print("🔧 HRmax USED = \(hrMaxUsed) (mode=standard 220−age, age=\(age))")
        } else {
            hrMaxUsed = HRMaxDBManager.shared.valueOrDefault(age: detailsVM.userAge)
            if let meta = HRMaxDBManager.shared.currentRecord() {
                print("🔧 HRmax USED = \(hrMaxUsed) (mode=DB, recordedAt=\(Date(timeIntervalSince1970: meta.recordedAt)))")
            } else {
                print("🔧 HRmax USED = \(hrMaxUsed) (mode=DB/default, no meta)")
            }
        }

        // сохранить для AI/контекста
        computedHRMax  = hrMaxUsed
        computedHRRest = hrRest

        // 6) Интенсивность
        intensityList = analyzer.intensityForTrainings(
            trainings: detailsVM.trainings,
            hrSegments: detailsVM.hrSegments,
            hrMax: hrMaxUsed,
            hrRest: hrRest
        )
        intensityDay = analyzer.intensityForDay(
            trainings: detailsVM.trainings,
            hrSegments: detailsVM.hrSegments,
            hrMax: hrMaxUsed,
            hrRest: hrRest
        )

        // 7) Totals
        dayTotals = qualities.reduce(TimeInZone()) { acc, q in
            var t = acc; let m = q.tiz
            t.rec += m.rec; t.fat += m.fat; t.tran += m.tran
            t.ana += m.ana; t.stress += m.stress; return t
        }

        // 8) Энергия
        let eneProvider: (TrainingRow) -> Double? = { tr in detailsVM.energyByTraining[tr.id] }
        eneList = analyzer.energyEfficiencyForTrainings(
            trainings: detailsVM.trainings,
            hrSegments: detailsVM.hrSegments,
            kcalProvider: eneProvider
        )
        eneDay  = analyzer.energyEfficiencyForDay(
            trainings: detailsVM.trainings,
            hrSegments: detailsVM.hrSegments,
            kcalProvider: eneProvider
        )
    }

    @MainActor
    func loadRangeData(from start: Date, to end: Date) async {
        activeThresholds = currentThresholds()
        let thresholds = activeThresholds ?? DefaultZonesProvider.estimate(age: detailsVM.userAge ?? 30)
        let analyzer = DailyAnalyzer(thresholds: thresholds)

        var aggTotals = TimeInZone()
        var aggIntDur: TimeInterval = 0
        var aggIntWeightedAvgHR: Double = 0
        var aggIntWeightedRPE: Double = 0
        var aggPeakHR = 0
        var aggPeakPct: Double = 0
        var aggSawRed = false

        var sumKcal: Double = 0
        var sumStressSec: Double = 0

        var day = Calendar.current.startOfDay(for: start)
        let endDay = Calendar.current.startOfDay(for: end)

        while day <= endDay {
            await detailsVM.load(for: day)

            // 1) дневные качества
            let dayQual = analyzer.analyzeDay(
                trainings: detailsVM.trainings,
                hrSegments: detailsVM.hrSegments
            )
            qualities.append(contentsOf: dayQual)

            // 2) HRmax/HRrest на день
            let hrRest: Int = DailyAnalyzer.estimateHRRestSmart(from: detailsVM.hrDailyPoints)
            let hrMaxUsed: Int = {
                if useStandardZones {
                    let age = detailsVM.userAge ?? 30
                    return min(230, max(160, 220 - age))
                } else {
                    return HRMaxDBManager.shared.valueOrDefault(age: detailsVM.userAge)
                }
            }()

            // 3) интенсивность
            let list: [TrainingIntensity] = analyzer.intensityForTrainings(
                trainings: detailsVM.trainings,
                hrSegments: detailsVM.hrSegments,
                hrMax: hrMaxUsed,
                hrRest: hrRest
            )
            intensityList.append(contentsOf: list)

            let dayInt: DayIntensity = analyzer.intensityForDay(
                trainings: detailsVM.trainings,
                hrSegments: detailsVM.hrSegments,
                hrMax: hrMaxUsed,
                hrRest: hrRest
            )

            // totals по зонам
            let dayTotalsLocal = dayQual.reduce(TimeInZone()) { acc, q in
                var t = acc; let m = q.tiz
                t.rec += m.rec; t.fat += m.fat; t.tran += m.tran
                t.ana += m.ana; t.stress += m.stress; return t
            }
            aggTotals.rec    += dayTotalsLocal.rec
            aggTotals.fat    += dayTotalsLocal.fat
            aggTotals.tran   += dayTotalsLocal.tran
            aggTotals.ana    += dayTotalsLocal.ana
            aggTotals.stress += dayTotalsLocal.stress

            // интенсивность (взвешенно)
            let dayRPE10: Double = Double(dayInt.hrRPE10)
            let dayPeakPct: Double = dayInt.peakHRPercent
            let dayMinutesAt90: Double = dayInt.timeAbove90
            let daySawRed: Bool = dayInt.sawRedZone
            // saw red
            aggIntWeightedRPE = dayRPE10          // это уже дневной, взвешенный
            aggPeakPct        = dayPeakPct
            aggSawRed         = aggSawRed || daySawRed

            // Энергия
            let eneProvider: (TrainingRow) -> Double? = { tr in detailsVM.energyByTraining[tr.id] }
            let eneD = analyzer.energyEfficiencyForDay(
                trainings: detailsVM.trainings,
                hrSegments: detailsVM.hrSegments,
                kcalProvider: eneProvider
            )
            sumKcal += eneD.totalKcal
            sumStressSec += eneD.totalStressSec

            day = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        }

        // применяем агрегаты
        self.dayTotals = aggTotals

        let avgHR = aggIntDur > 0 ? Int(round(aggIntWeightedAvgHR / aggIntDur)) : 0
        let rpeW  = aggIntDur > 0 ? (aggIntWeightedRPE / aggIntDur) : 0

        self.intensityDay = DayIntensity(
            peakHRPercent: aggPeakPct,
            timeAbove90: 0,
            sawRedZone: aggSawRed,
            hrRPE10: Int(round(rpeW))
        )

        let eff = sumStressSec > 0 ? (sumKcal / (sumStressSec / 60.0)) : 0
        self.eneDay = EnergyDayEfficiency(
            totalKcal: sumKcal,
            totalStressSec: sumStressSec,
            kcalPerStressMin: eff
        )
    }

    func resetMetrics() {
        qualities = []
        intensityList = []
        intensityDay = DayIntensity(peakHRPercent: 0, timeAbove90: 0, sawRedZone: false, hrRPE10: 0)
        dayTotals = .init()
        eneList = []
        eneDay  = EnergyDayEfficiency(totalKcal: 0, totalStressSec: 0, kcalPerStressMin: 0)
    }

    /// OFF → индивидуальные из БД, ON → «220 − возраст»
    func currentThresholds() -> ZoneThresholds {
        if useStandardZones {
            return DefaultZonesProvider.estimate(age: detailsVM.userAge ?? 30)
        }
        return (try? AverageZonesDBManager.shared.fetchAverageZones())
            ?? DefaultZonesProvider.estimate(age: detailsVM.userAge ?? 30)
    }

    func evidenceSecondsAt90(segments: [[HRPoint]],
                                     thresholds: ZoneThresholds,
                                     hrMax: Int) -> TimeInterval {
        let p90 = DailyAnalyzer.bpmAt90Percent(thresholds: thresholds, hrMax: hrMax)
        var sec: TimeInterval = 0
        for seg in segments {
            guard seg.count > 1 else { continue }
            for i in 0..<(seg.count - 1) {
                let a = seg[i], b = seg[i+1]
                // грубая интеграция «ступеньками»: учитываем интервал только если обе точки ≥ p90
                if a.bpm >= p90 && b.bpm >= p90 {
                    sec += b.time.timeIntervalSince(a.time)
                }
            }
        }
        return max(0, sec)
    }
}
