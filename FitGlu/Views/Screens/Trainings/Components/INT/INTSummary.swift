import SwiftUI

/// Шапка «Intensity & Peaks». В свёрнутом виде показывает чипы, в развёрнутом — можно скрыть.
struct INTSummary: View {
    let day: DayIntensity
    let showChips: Bool

    var body: some View {
        HStack(spacing: 8) {
            // справа — «оценка» (RPE0–10) компактно
            if !showChips {
                Text("\(day.hrRPE10) / 10")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 6)
            }
            if showChips {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Chip(title: "Peak", value: String(format: "%.0f%%", day.peakHRPercent))
                        Chip(title: "≥90%", value: "\(Int(round(day.timeAbove90/60)))m")
                        Chip(title: "Red", value: day.sawRedZone ? "yes" : "no")
                        Chip(title: "RPE", value: "\(day.hrRPE10)/10")
                    }
                }
            }
        }
        .contentTransition(.opacity)
    }

    private func Chip(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.caption2)
            Text(value).font(.caption2).monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color(.secondarySystemBackground), in: Capsule())
    }
}
