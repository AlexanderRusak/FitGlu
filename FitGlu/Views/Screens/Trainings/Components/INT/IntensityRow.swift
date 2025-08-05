import SwiftUI

/// Одна строка с метриками интенсивности (без прогресс-бара).
struct IntensityRow: View {
    let m: TrainingIntensity

    private var start: Date { Date(timeIntervalSince1970: m.training.startTime) }
    private var end:   Date { Date(timeIntervalSince1970: m.training.endTime) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Заголовок
            HStack(alignment: .firstTextBaseline) {
                Text(m.training.type)
                    .font(.headline)
                Spacer()
                Text("\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Чипы — автоматически переносятся на новую строку
            FlowLayout(spacing: 8, rowSpacing: 8) {
                MetricPill(icon: "bolt.fill",         // Peak %
                           label: "Peak",
                           value: "\(Int(round(m.peakHRPercent)))%",
                           tint: .indigo)

                MetricPill(icon: "percent",           // ≥90% time
                           label: "≥90%",
                           value: "\(Int(round(m.timeAbove90/60)))m",
                           tint: .blue)

                MetricPill(icon: "heart.fill",        // Red zone flag
                           label: "Red",
                           value: m.sawRedZone ? "yes" : "no",
                           tint: m.sawRedZone ? .red : .gray)

                MetricPill(icon: "gauge.with.dots.needle.67percent", // HR-RPE 0..10
                           label: "RPE",
                           value: "\(m.hrRPE10)/10",
                           tint: .orange)

                MetricPill(icon: "waveform.path.ecg",  // Avg HR
                           label: "AvgHR",
                           value: "\(m.avgHR) bpm",
                           tint: .purple)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Капсула «иконка + label + value». Аккуратнее и компактнее.
private struct MetricPill: View {
    let icon: String
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .imageScale(.small)
                .font(.caption2)
            Text(label).font(.caption2)
            Text(value)
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.9)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.14), in: Capsule())
        .overlay(
            Capsule().stroke(tint.opacity(0.25), lineWidth: 0.5)
        )
        .fixedSize() // капсула ужимается по контенту
    }
}
