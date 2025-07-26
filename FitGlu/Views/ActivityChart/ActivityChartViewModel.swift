import Foundation
import SwiftUI

@MainActor
final class ActivityChartViewModel: ObservableObject {

    @Published var hrPoints: [HeartRateChartPoint] = []
    @Published var glucosePoints: [GlucoseChartPoint] = []
    @Published var zones: [ZoneRange] = []

    /// Заполняем свои массивы из DetailsViewModel
    func configure(from details: DetailsViewModel) async {
        // 1. Зоны
        let thresholds = (try? AverageZonesDBManager.shared.fetchAverageZones())
            ?? DefaultZonesProvider.estimate(age: details.userAge ?? 30)
        zones = [
            ZoneRange(range: thresholds.z1[0]...thresholds.z1[1], color: .blue.opacity(0.2)),
            ZoneRange(range: thresholds.z2[0]...thresholds.z2[1], color: .green.opacity(0.2)),
            ZoneRange(range: thresholds.z3[0]...thresholds.z3[1], color: .yellow.opacity(0.2)),
            ZoneRange(range: thresholds.z4[0]...thresholds.z4[1], color: .orange.opacity(0.2)),
            ZoneRange(range: thresholds.z5[0]...thresholds.z5[1], color: .red.opacity(0.2)),
        ]

        // 2. Сегменты тренировок для быстрого поиска по времени
        let workouts: [(range: ClosedRange<TimeInterval>, type: String)] = details.trainings.map {
            ($0.startTime...$0.endTime, $0.type)
        }

        // 3. HR точки
        hrPoints = details.hrDailyPoints.map { hr in
            let ts = hr.time.timeIntervalSince1970
            let matchedType = workouts.first { $0.range.contains(ts) }?.type
            return HeartRateChartPoint(
                time: hr.time,
                bpm: hr.bpm,
                trainingType: matchedType
            )
        }

        // 4. Glucose точки
        glucosePoints = details.glucose.map { g in
            let d = Date(timeIntervalSince1970: g.timestamp)
            return GlucoseChartPoint(time: d, value: g.glucoseValue)
        }
    }
}
