// Views/Charts/ZonesStacked/TooltipCard.swift
import SwiftUI

struct TooltipCard: View {
    let date: Date
    let total: Double
    let parts: [(ZoneKind, Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(date, format: .dateTime.day().month(.abbreviated))
                .font(.caption).foregroundStyle(.secondary)
            Text("\(Int(total.rounded())) min")
                .font(.footnote.weight(.semibold))

            ForEach(parts, id: \.0) { (k, v) in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(k.color)
                        .frame(width: 8, height: 8)
                    Text("\(k.shortTitle) \(Int(v.rounded()))m")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 3, x: 0, y: 1)
    }
}
