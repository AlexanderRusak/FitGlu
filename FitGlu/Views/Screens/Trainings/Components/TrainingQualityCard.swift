import SwiftUI

struct TrainingQualityCard: View {
    let q: TrainingQuality

    private var start: Date { Date(timeIntervalSince1970: q.training.startTime) }
    private var end:   Date { Date(timeIntervalSince1970: q.training.endTime) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок
            HStack(alignment: .firstTextBaseline) {
                Text(q.training.type)
                    .font(.headline)
                Spacer()
                Text("\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            // Zone Balance Score
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Zone Balance Score")
                    Spacer()
                    Text("\(Int(round(q.zoneBalanceScore))) / 100")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Gauge(value: q.zoneBalanceScore, in: 0...100) { }
                    .gaugeStyle(.linearCapacity)
            }

            // TIZ
            let m = q.tiz.minutes
            let minutes = [m.rec, m.fat, m.tran, m.ana, m.stress]

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(zip(HRZone.allCases, minutes)), id: \.0) { zone, value in
                        ZoneChip(title: zone.full,
                                 valueText: "\(Int(round(value)))m",
                                 color: zone.color)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
