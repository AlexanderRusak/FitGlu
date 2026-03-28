import Foundation
import SwiftUI

@MainActor
final class ActivityChartViewModel: ObservableObject {

    // MARK: — Данные для Chart
    @Published var zones: [ZoneRange] = []
    @Published var trainings: [TrainingRow] = []
    @Published var hrPoints: [HeartRateChartPoint] = []
    @Published var glucosePoints: [GlucoseChartPoint] = []

    /// Конфигурируем модель из DetailsViewModel
    func configure(from details: DetailsViewModel) async {
        // 1) Зоны
        let thresholds = (try? AverageZonesDBManager.shared.fetchAverageZones())
            ?? DefaultZonesProvider.estimate(age: details.userAge ?? 30)

        zones = [
            ZoneRange(range: thresholds.z1[0]...thresholds.z1[1],
                      color: .blue.opacity(0.2),  label: "Z1"),
            ZoneRange(range: thresholds.z2[0]...thresholds.z2[1],
                      color: .green.opacity(0.2), label: "Z2"),
            ZoneRange(range: thresholds.z3[0]...thresholds.z3[1],
                      color: .yellow.opacity(0.2),label: "Z3"),
            ZoneRange(range: thresholds.z4[0]...thresholds.z4[1],
                      color: .orange.opacity(0.2),label: "Z4"),
            ZoneRange(range: thresholds.z5[0]...thresholds.z5[1],
                      color: .red.opacity(0.2),   label: "Z5"),
        ]

        // 2) Тренировки
        trainings = details.trainings

        // 3) Диапазоны тренировок
        let workoutRanges: [ClosedRange<Date>] = trainings.map { training -> ClosedRange<Date> in
            let startDate = Date(timeIntervalSince1970: training.startTime)
            let endDate   = Date(timeIntervalSince1970: training.endTime)
            return startDate...endDate
        }

        // 4) Точки пульса с привязкой к тренировке (или nil)
        hrPoints = details.hrDailyPoints.map { hr in
            let t = hr.time
            let trainingType = zip(trainings, workoutRanges)
                .first { _, range in range.contains(t) }?
                .0.type
            return HeartRateChartPoint(time: t,
                                       bpm: hr.bpm,
                                       trainingType: trainingType)
        }

        // 5) Точки глюкозы
        glucosePoints = details.glucose.map { g in
            GlucoseChartPoint(
                time: Date(timeIntervalSince1970: g.timestamp),
                value: g.glucoseValue
            )
        }
    }
}
