import SwiftUI

struct IntensityList: View {
    let metrics: [TrainingIntensity]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(metrics) { m in
                IntensityRow(m: m)
            }
        }
    }
}
