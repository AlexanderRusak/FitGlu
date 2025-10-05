import SwiftUI

public struct PeriodHeaderView: View {
    public struct Info {
        public let start: Date
        public let end: Date
        public let daysCount: Int
        public let workoutsCount: Int
        public let totalMinutes: Int
        public let avgPerDay: Int
        public let avgZBS: Int?      // опционально, если пришлёшь
        public let kcal: Int?        // суммарные ккал за период
    }

    public let info: Info

    public init(info: Info) { self.info = info }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(dateRange(info.start, info.end))
                    .font(.headline)
                Spacer()
                Text("\(info.daysCount)d")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            // чипы
            HStack(spacing: 8) {
                chip("Workouts", "\(info.workoutsCount)")
                chip("Minutes", "\(info.totalMinutes)")
                chip("Avg/day", "\(info.avgPerDay)")
                if let z = info.avgZBS { chip("Avg ZBS", "\(z)") }
                if let k = info.kcal { chip("kcal", "\(k)") }
            }
        }
    }

    private func chip(_ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }

    private func dateRange(_ s: Date, _ e: Date) -> String {
        let df1 = DateFormatter(); df1.dateFormat = "d MMM"
        let df2 = DateFormatter(); df2.dateFormat = "d MMM yyyy"
        let sameYear = Calendar.current.component(.year, from: s) == Calendar.current.component(.year, from: e)
        let left = sameYear ? df1.string(from: s) : df2.string(from: s)
        let right = df2.string(from: e)
        return "\(left) – \(right)"
    }
}
