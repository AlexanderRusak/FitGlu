// Views/Charts/ZonesStacked/ZonesLegendInteractive.swift
import SwiftUI

struct ZonesLegendInteractive: View {
    @Binding var visible: Set<ZoneKind>

    var body: some View {
        HStack(spacing: 10) {
            item(.rec,  title: "rec",    color: ZonePalette.rec)
            item(.fat,  title: "fat",    color: ZonePalette.fat)
            item(.tran, title: "tran",   color: ZonePalette.tran)
            item(.ana,  title: "ana",    color: ZonePalette.ana)
            item(.stress, title: "stress", color: ZonePalette.stress)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func item(_ kind: ZoneKind, title: String, color: Color) -> some View {
        let isOn = visible.contains(kind)
        Button {
            if isOn { visible.remove(kind) } else { visible.insert(kind) }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(isOn ? color : color.opacity(0.25))
                    .frame(width: 10, height: 10)
                Text(title)
                    .font(.caption)
                    .foregroundColor(Color.secondary.opacity(isOn ? 1 : 0.55))
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(.thickMaterial.opacity(isOn ? 0.18 : 0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
