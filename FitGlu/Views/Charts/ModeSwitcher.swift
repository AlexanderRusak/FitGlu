import SwiftUI

public enum ZonesChartMode: String, CaseIterable, Identifiable {
    case minutes, percent
    public var id: Self { self }
    public var title: String {
        switch self {
        case .minutes: return "Minutes"
        case .percent: return "Percent"
        }
    }
}

public struct ModeSwitcher: View {
    @Binding var mode: ZonesChartMode

    public init(mode: Binding<ZonesChartMode>) {
        self._mode = mode
    }

    public var body: some View {
        Picker("", selection: $mode) {
            ForEach(ZonesChartMode.allCases) { m in
                Text(m.title).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .tint(.green)                          // акцент
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.06))
        )
        .accessibilityLabel("Chart mode")
    }
}
