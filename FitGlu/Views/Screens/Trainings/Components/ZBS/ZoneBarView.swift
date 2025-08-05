import SwiftUI

struct ZonesBarView: View {
    let thresholds: ZoneThresholds     // ← у структуры уже есть subscript

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HR zones (bpm)")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HRZone.allCases, id: \.self) { zone in
                        let bpm = thresholds[zone]          // работает через subscript
                        ZoneChip(
                            title: zone.long,
                            valueText: "\(bpm[0])–\(bpm[1])",
                            color: zone.color
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
