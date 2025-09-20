import SwiftUI

struct WRCompactBar: View {
    let summary: WorkRestSummary

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(Color.blue.opacity(0.25))
                .frame(width: 6, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(summary.sets) sets")
                    .font(.headline)
                    .monospacedDigit()

                HStack(spacing: 12) {
                    Text("Work \(format(summary.avgWork))")
                    Text("Rest \(format(summary.avgRest))")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .monospacedDigit()
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func format(_ t: TimeInterval) -> String {
        let m = Int(t) / 60, s = Int(t) % 60
        return String(format: "%dm %02ds", m, s)
    }
}
