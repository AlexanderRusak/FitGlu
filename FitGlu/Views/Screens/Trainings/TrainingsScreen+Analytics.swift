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

        // Интенсивность — собираем корректные агрегаты за период
        var aggDur: TimeInterval   = 0          // Σ длительностей (сек)
        var sumHRdt: Double        = 0          // Σ(avgHR * dur)
        var sumRPEdt: Double       = 0          // Σ(rpeIndex * dur)
        var aggPeakHR: Int         = 0          // max по дню
        var aggPeakPct: Double     = 0          // max по дню
        var aggTimeAt90: Double    = 0          // Σ секунд ≥90% HR
        var aggSawRed: Bool        = false      // OR по всем дням

        // Энергия
        var sumKcal: Double        = 0
        var sumStressSec: Double   = 0

        var day = Calendar.current.startOfDay(for: start)
        let endDay = Calendar.current.startOfDay(for: end)

        while day <= endDay {
            await detailsVM.load(for: day)

            // 1) Качество зон — добавляем все тренировки дня
            let dayQual = analyzer.analyzeDay(
                trainings: detailsVM.trainings,
                hrSegments: detailsVM.hrSegments
            )
            qualities.append(contentsOf: dayQual)

            // 2) HR на день
            let hrRest = DailyAnalyzer.estimateHRRestSmart(from: detailsVM.hrDailyPoints)
            let hrMaxUsed: Int = {
                if useStandardZones {
                    let age = detailsVM.userAge ?? 30
                    return min(230, max(160, 220 - age))
                } else {
                    return HRMaxDBManager.shared.valueOrDefault(age: detailsVM.userAge)
                }
            }()

            // 3) Интенсивность ПО ТРЕНИРОВКАМ (берём метрики с duration/avg/peak/rpe)
            let list: [IntensityTrainingMetrics] = analyzer.intensityForTrainings(
                trainings: detailsVM.trainings,
                hrSegments: detailsVM.hrSegments,
                hrMax: hrMaxUsed,
                hrRest: hrRest
            )
            intensityList.append(contentsOf: list.map { TrainingIntensity(from: $0) })

            // День → агрегаты
            let dayDur       = list.reduce(0.0) { $0 + $1.duration }
            let daySumHRdt   = list.reduce(0.0) { $0 + Double($1.avgHR)   * $1.duration }
            let daySumRPEdt  = list.reduce(0.0) { $0 + $1.rpeIndex        * $1.duration }
            let dayPeakHR    = list.map(\.peakHR).max() ?? 0
            let dayPeakPct   = list.map(\.peakPercent).max() ?? 0

            aggDur   += dayDur
            sumHRdt  += daySumHRdt
            sumRPEdt += daySumRPEdt
            aggPeakHR = max(aggPeakHR, dayPeakHR)
            aggPeakPct = max(aggPeakPct, dayPeakPct)

            // ≥90% HR и красная зона — берём из дневной сводки
            let dayInt = analyzer.intensityForDay(
                trainings: detailsVM.trainings,
                hrSegments: detailsVM.hrSegments,
                hrMax: hrMaxUsed,
                hrRest: hrRest
            )
            let dayIntRaw: IntensityDayMetrics = analyzer.intensityForDay(
                trainings: detailsVM.trainings,
                hrSegments: detailsVM.hrSegments,
                hrMax: hrMaxUsed,
                hrRest: hrRest
            )

            // секунды ≥90% HR считаем по сегментам
            let dayTimeAt90 = evidenceSecondsAt90(
                segments: detailsVM.hrSegments,
                thresholds: thresholds,
                hrMax: hrMaxUsed
            )

            // sawRed — был ли вход в красную зону (граница Z5.low)
            let redLowerBPM = thresholds.z5[0]    // если у тебя z5 = [low, high] в bpm
            let daySawRed = detailsVM.hrSegments.contains { seg in
                seg.contains { $0.bpm >= redLowerBPM }
            }

            // агрегаты
            aggTimeAt90 += dayTimeAt90
            aggSawRed   = aggSawRed || daySawRed

            // 4) Totals по зонам за день → в период
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

            // 5) Энергия
            let eneProvider: (TrainingRow) -> Double? = { tr in detailsVM.energyByTraining[tr.id] }
            let eneD = analyzer.energyEfficiencyForDay(
                trainings: detailsVM.trainings,
                hrSegments: detailsVM.hrSegments,
                kcalProvider: eneProvider
            )
            sumKcal      += eneD.totalKcal
            sumStressSec += eneD.totalStressSec

            day = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        }

        // ——— Применяем агрегаты по периоду ———
        self.dayTotals = aggTotals

        let avgHR = aggDur > 0 ? Int(round(sumHRdt / aggDur)) : 0
        let rpeW  = aggDur > 0 ? (sumRPEdt / aggDur) : 0

        self.intensityDay = DayIntensity(
            peakHRPercent: aggPeakPct,         // пик в % от HRmax — берём максимальный за период
            timeAbove90:   aggTimeAt90,        // суммарные секунды ≥90% HR за период
            sawRedZone:    aggSawRed,          // был ли хоть раз
            hrRPE10:       Int(round(rpeW))    // взвешенное по длительности среднее RPE 0–10
        )

        let eff = sumStressSec > 0 ? (sumKcal / (sumStressSec / 60.0)) : 0
        self.eneDay = EnergyDayEfficiency(
            totalKcal:       sumKcal,
            totalStressSec:  sumStressSec,
            kcalPerStressMin: eff
        )

        // avgHR посчитан выше (если нужен в UI — сохрани куда надо)
        _ = avgHR
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
