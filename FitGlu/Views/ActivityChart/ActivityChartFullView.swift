import SwiftUI
import Charts

struct ActivityChartFullView: View {
    let trainings: [TrainingRow]
    let hrSegments: [[HRPoint]]
    let glucose: [GlucoseRow]
    let zones: ZoneThresholds

    var body: some View {
        Chart {
            // Линии пульса, покрашенные по типу тренировки
            ForEach(trainings, id: \..id) { training in
                let range = Date(timeIntervalSince1970: training.startTime)...Date(timeIntervalSince1970: training.endTime)
                let color = TrainingPalette.color(for: training.type)

                ForEach(hrSegments, id: \..first?.time) { segment in
                    let filtered = segment.filter { range.contains($0.time) }
                    if !filtered.isEmpty {
                        ForEach(filtered) { point in
                            LineMark(
                                x: .value("Time", point.time),
                                y: .value("BPM", point.bpm)
                            )
                            .foregroundStyle(color)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                }
            }

            // Линия глюкозы
            if !glucose.isEmpty {
                ForEach(glucose, id: \..id) { row in
                    LineMark(
                        x: .value("Time", Date(timeIntervalSince1970: row.timestamp)),
                        y: .value("Glucose", row.glucoseValue)
                    )
                    .foregroundStyle(.pink)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                }
            }

            // Горизонтальные зоны
            ForEach(zones.all, id: \..label) { zone in
                RectangleMark(
                    xStart: .value("Start", minTime),
                    xEnd:   .value("End", maxTime),
                    yStart: .value("Y", zone.range.lowerBound),
                    yEnd:   .value("Y", zone.range.upperBound)
                )
                .foregroundStyle(zone.color.opacity(0.1))
            }
        }
        .frame(height: 300)
        .padding()
    }

    private var minTime: Date {
        let all = hrSegments.flatMap { $0.map { $0.time } } + glucose.map { Date(timeIntervalSince1970: $0.timestamp) }
        return all.min() ?? Date()
    }

    private var maxTime: Date {
        let all = hrSegments.flatMap { $0.map { $0.time } } + glucose.map { Date(timeIntervalSince1970: $0.timestamp) }
        return all.max() ?? Date()
    }
}

// MARK: - Support zone struct
extension ZoneThresholds {
    var all: [(label: String, range: ClosedRange<Int>, color: Color)] {
        [
            ("Z1", z1[0]...z1[1], .blue),
            ("Z2", z2[0]...z2[1], .green),
            ("Z3", z3[0]...z3[1], .yellow),
            ("Z4", z4[0]...z4[1], .orange),
            ("Z5", z5[0]...z5[1], .red)
        ]
    }
}
