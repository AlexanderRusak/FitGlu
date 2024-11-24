import SwiftUI
import WidgetKit
import ActivityKit

struct HeartRateLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HeartRateActivityAttributes.self) { context in
            VStack {
                Text("Heart Rate")
                    .font(.headline)
                Text("\(context.state.heartRate) bpm")
                    .font(.largeTitle)
                    .bold()
                Text("Training: \(context.state.trainingType)")
                    .font(.subheadline)
            }
            .padding()
        }
    }
}
