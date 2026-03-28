// Views/Charts/ZonesStacked/PeriodSummaryView.swift
import SwiftUI

struct PeriodSummaryView: View {
    let summary: ZonesStackedChart.PeriodSummary
    let mode: ZonesChartMode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Period totals")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                stat(.rec,    "rec",    summary.rec,    summary.pct(summary.rec))
                stat(.fat,    "fat",    summary.fat,    summary.pct(summary.fat))
                stat(.tran,   "tran",   summary.tran,   summary.pct(summary.tran))
                stat(.ana,    "ana",    summary.ana,    summary.pct(summary.ana))
                stat(.stress, "stress", summary.stress, summary.pct(summary.stress))
            }

            Text(mode == .minutes ? "Total: \(Int(summary.total.rounded())) min" : "Total: 100%")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stat(_ kind: ZoneKind, _ label: String, _ value: Double, _ pct: Int) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(kind.color)
                .frame(width: 8, height: 8)
            let text = mode == .minutes
                ? "\(label) \(Int(value.rounded()))m (\(pct)%)"
                : "\(label) \(pct)%"
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
