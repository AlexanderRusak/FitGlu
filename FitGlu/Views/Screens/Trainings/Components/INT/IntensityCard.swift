import SwiftUI

struct IntensityCard: View {
    let m: IntensityTrainingMetrics

    private var start: Date { Date(timeIntervalSince1970: m.training.startTime) }
    private var end:   Date { Date(timeIntervalSince1970: m.training.endTime) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // заголовок
            HStack(alignment: .firstTextBaseline) {
                Text(m.training.type).font(.headline)
                Spacer()
                Text("\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            // метрика
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Intensity (RPE)").font(.body)
                    Spacer()
                    Text(String(format: "%.1f / 10", m.rpeIndex))
                        .foregroundStyle(.secondary).monospacedDigit()
                }
                RPECompactBar(rpe: Int(m.rpeIndex))
            }

            // чипы
            HStack(spacing: 8) {
                ZoneChip(title: "Peak", valueText: "\(Int(round(m.peakPercent)))%", color: IntensityPalette.peak)
                ZoneChip(title: "Avg",  valueText: "\(m.avgHR) bpm",               color: IntensityPalette.avg)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
