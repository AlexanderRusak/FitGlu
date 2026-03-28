import SwiftUI

struct ENESummary: View {
    let day: EnergyDayEfficiency
    let showChips: Bool

    var body: some View {
        if showChips {
            FlowLayout(spacing: 8, rowSpacing: 8) {
                ZoneChip(title: "Total kcal",
                         valueText: kcalText(day.totalKcal),
                         color: .orange)

                ZoneChip(title: "Stress",
                         valueText: stressLabel(day.totalStressSec),
                         color: .red)

                ZoneChip(title: "kcal / Stress-min",
                         valueText: effText(kcalPerStressMin: day.kcalPerStressMin,
                                            stressSec: day.totalStressSec),
                         color: .yellow)
            }
        } else {
            HStack(spacing: 8) {
                Text(effText(kcalPerStressMin: day.kcalPerStressMin,
                             stressSec: day.totalStressSec))
                    .font(.headline.monospacedDigit())
                Text("kcal / Stress-min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
