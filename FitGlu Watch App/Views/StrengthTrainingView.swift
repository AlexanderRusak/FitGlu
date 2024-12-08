import SwiftUI

struct StrengthTrainingView: View {
    @StateObject private var strengthManager = StrengthTrainingManager()
    @State private var isWorkoutActive = false

    var body: some View {
        VStack {
            Text("Strength Training")
                .font(.headline)

            Text("Peaks: \(strengthManager.peakCount)")
            Text("Current HR: \(strengthManager.currentHeartRate, specifier: "%.0f") bpm")
                .onChange(of: strengthManager.currentHeartRate) { newValue in
                    print("Current HR changed to \(newValue)")
                }
            Text("Last Peak: \(strengthManager.lastPeakRate, specifier: "%.0f") bpm")
            Text("Target: \(strengthManager.normalThreshold) bpm")
                .foregroundColor(.blue)

            if isWorkoutActive {
                Button("Finish") {
                    strengthManager.stopMonitoring()
                    isWorkoutActive = false
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            } else {
                Button("Start") {
                    strengthManager.startMonitoring()
                    isWorkoutActive = true
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
    }
}

#Preview {
    StrengthTrainingView()
}
