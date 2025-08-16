import Foundation

extension DailyAnalyzer {

    func energyEfficiencyForTrainings(
        trainings: [TrainingRow],
        hrSegments: [[HRPoint]],
        kcalProvider: (TrainingRow) -> Double?
    ) -> [EnergyTrainingEfficiency] {

        let qs = analyzeDay(trainings: trainings, hrSegments: hrSegments)
        return qs.map { q in
            let kcal = kcalProvider(q.training) ?? 0
            let stressSec = q.tiz.stress
            let eff = safeRate(kcal: kcal, stressSec: stressSec)
            return EnergyTrainingEfficiency(id: q.id, training: q.training, kcal: kcal, stressSec: stressSec, kcalPerStressMin: eff)
        }
    }

    func energyEfficiencyForDay(
        trainings: [TrainingRow],
        hrSegments: [[HRPoint]],
        kcalProvider: (TrainingRow) -> Double?
    ) -> EnergyDayEfficiency {

        let list = energyEfficiencyForTrainings(trainings: trainings, hrSegments: hrSegments, kcalProvider: kcalProvider)
        let totalKcal   = list.reduce(0.0) { $0 + $1.kcal }
        let totalStress = list.reduce(0.0) { $0 + $1.stressSec }
        let dayEff      = safeRate(kcal: totalKcal, stressSec: totalStress)
        return EnergyDayEfficiency(totalKcal: totalKcal, totalStressSec: totalStress, kcalPerStressMin: dayEff)
    }
}
