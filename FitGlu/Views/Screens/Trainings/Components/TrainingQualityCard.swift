import SwiftUI

struct TrainingQualityCard: View {
    let q: TrainingQuality
    @State private var showInfo = false          // sheet-флаг

    private var start: Date { Date(timeIntervalSince1970: q.training.startTime) }
    private var end:   Date { Date(timeIntervalSince1970: q.training.endTime) }

    // удобный доступ к статусу
    private var scoreLevel: ScoreLevel { .init(score: q.zoneBalanceScore) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            scoreGauge
            tizRow
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: – Sub-views
private extension TrainingQualityCard {

    // 1) Заголовок
    var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(q.training.type).font(.headline)
            Spacer()
            Text("\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }

    // 2) Gauge + статус + ℹ︎
    var scoreGauge: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text("Zone Balance Score")

                Spacer()
                Text("\(Int(round(q.zoneBalanceScore))) / 100")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                // статус-капсула
                Text(scoreLevel.label)
                    .font(.caption2).bold()
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(scoreLevel.color.opacity(0.15), in: Capsule())
            }

            Gauge(value: q.zoneBalanceScore, in: 0...100) { }
                .gaugeStyle(.linearCapacity)
        }
    }

    // 3) TIZ-строка
    var tizRow: some View {
        let m = q.tiz.minutes
        let minutes = [m.rec, m.fat, m.tran, m.ana, m.stress]

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(zip(HRZone.allCases, minutes)), id: \.0) { zone, value in
                    ZoneChip(title: zone.short,
                             valueText: "\(Int(round(value)))m",
                             color: zone.color)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
