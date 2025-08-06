import SwiftUI

struct ENEList: View {
    let items: [EnergyTrainingEfficiency]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items) { ENECell(item: $0) }
        }
    }
}

private struct ENECell: View {
    let item: EnergyTrainingEfficiency

    private var start: Date { Date(timeIntervalSince1970: item.training.startTime) }
    private var end:   Date { Date(timeIntervalSince1970: item.training.endTime) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.training.type)
                    .font(.headline)
                Spacer()
                Text("\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // мини-строка с чипами
            FlowLayout(spacing: 8, rowSpacing: 8) {
                ZoneChip(title: "kcal",   valueText: kcalText(item.kcal),                   color: .orange)
                ZoneChip(title: "Stress", valueText: stressLabel(item.stressSec),           color: .red)
                ZoneChip(title: "Eff",    valueText: effText(kcalPerStressMin: item.kcalPerStressMin,
                                                             stressSec: item.stressSec),   color: .yellow)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
