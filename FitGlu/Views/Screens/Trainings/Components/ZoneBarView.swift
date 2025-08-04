import SwiftUI

struct ZonesBarView: View {
    let thresholds: ZoneThresholds

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HR zones (bpm)")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HRZone.allCases, id: \.self) { zone in
                        let rangeText = range(thresholds[zone])    // см. helper ниже
                        ZoneChip(title: zone.full, valueText: rangeText, color: zone.color)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func range(_ zone: HRZone) -> [Int] {
        switch zone {
        case .z1: thresholds.z1
        case .z2: thresholds.z2
        case .z3: thresholds.z3
        case .z4: thresholds.z4
        case .z5: thresholds.z5
        }
    }
    private func range(_ arr: [Int]) -> String { "\(arr[0])–\(arr[1])" }
}

struct ZoneChip: View {
    let title: String
    let valueText: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(valueText)
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground).opacity(0.6), in: Capsule())
    }
}
