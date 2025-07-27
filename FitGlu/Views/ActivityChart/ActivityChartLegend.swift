// ActivityChartLegend.swift

import SwiftUI

struct ActivityChartLegend: View {

    let trainings: [TrainingRow]
    let hasGlucose: Bool

    var body: some View {
        VStack(spacing: 6) {
            // 1) верхний ряд: Glucose (если есть)
            if hasGlucose {
                HStack(spacing: 8) {
                    // вместо цветного кружка — пунктирная линия
                    Capsule()
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .foregroundColor(.red)
                        .frame(width: 20, height: 2)
                    Text("Glucose")
                        .font(.footnote)
                }
            }

            // 2) типы тренировок
            let types = Array(Set(trainings.map(\.type))).sorted()
            if !types.isEmpty {
                HStack(spacing: 16) {
                    ForEach(types, id: \.self) { t in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(TrainingPalette.color(for: t))
                                .frame(width: 10, height: 10)
                            Text(t)
                                .font(.footnote)
                        }
                    }
                }
            }
        }
    }
}
