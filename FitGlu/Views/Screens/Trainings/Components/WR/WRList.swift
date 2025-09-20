import SwiftUI

struct WRList: View {
    let items: [WRItem]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(items) { it in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(it.training.type)
                            .font(.headline)
                        Spacer()
                        Text(timeRange(it.training))
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }

                    FlowLayout(spacing: 8) {
                        chip("Sets", "\(it.summary.sets)")
                        chip("Work", fmt(it.summary.avgWork))
                        chip("Rest", fmt(it.summary.avgRest))
                        chip("W/R", String(format: "%.2f", it.summary.workRestRatio))
                    }
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func chip(_ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(title).bold()
            Text(value).monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func fmt(_ t: TimeInterval) -> String {
        let m = Int(t) / 60, s = Int(t) % 60
        return String(format: "%dm %02ds", m, s)
    }

    private func timeRange(_ tr: TrainingRow) -> String {
        let s = Date(timeIntervalSince1970: tr.startTime)
        let e = Date(timeIntervalSince1970: tr.endTime)
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "\(f.string(from: s))–\(f.string(from: e))"
    }
}
