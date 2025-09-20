import SwiftUI

struct WRSummaryView: View {
    let summary: WorkRestSummary
    let showChips: Bool

    var body: some View {
        HStack(spacing: 8) {
            chip("Sets", "\(summary.sets)")
            if showChips {
                chip("Work", format(summary.avgWork))
                chip("Rest", format(summary.avgRest))
                chip("W/R", String(format: "%.2f", summary.workRestRatio))
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(_ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.subheadline).bold()
            Text(value).font(.subheadline).monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func format(_ t: TimeInterval) -> String {
        let m = Int(t) / 60, s = Int(t) % 60
        return String(format: "%dm %02ds", m, s)
    }
}
