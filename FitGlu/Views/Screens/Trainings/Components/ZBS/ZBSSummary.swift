import SwiftUI

struct ZBSSummary: View {
    let avg: Double
    let totals: TimeInZone
    let showChips: Bool

    private var level: ScoreLevel { .init(score: avg) }
    private var minutes: [Double] {
        let m = totals.minutes
        return [m.rec, m.fat, m.tran, m.ana, m.stress]
    }

    var body: some View {
        if showChips {
            // только цветные суммарные чипы
            HStack(spacing: 6) {
                ForEach(Array(zip(HRZone.allCases, minutes)), id: \.0) { zone, val in
                    if val >= 1 {
                        ZoneChip(title: zone.short,
                                 valueText: "\(Int(val))m",
                                 color: zone.color)
                    }
                }
            }
        } else {
            // число + капсула
            HStack(spacing: 6) {
                Text("\(Int(round(avg))) / 100")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Text(level.label)
                    .font(.caption2).bold()
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(level.color.opacity(0.15), in: Capsule())
            }
        }
    }
}
