import SwiftUI

struct ChartLegend: View {

    let trainings: [TrainingRow]
    @Binding var showHRLine: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                dot(.red,  "Glucose")
                dot(.blue, "Heart Rate")
                Toggle("Line", isOn: $showHRLine)
                    .toggleStyle(.switch)
                    .font(.footnote)
            }
            let types = Array(Set(trainings.map(\.type.cleaned))).sorted()
            if !types.isEmpty {
                HStack(spacing: 16) {
                    ForEach(types, id: \.self) { t in
                        dot(TrainingPalette.color(for: t), t)
                    }
                }
            }
        }
    }
    private func dot(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) { Circle().fill(c).frame(width: 10, height: 10); Text(t).font(.footnote) }
    }
}
