import SwiftUI

struct WorkoutMonitorView: View {
    let trainingType: TrainingType
    @StateObject private var monitor = HeartRateMonitor()
    @State private var zoneManager = HeartRateZoneManager()
    @State private var isWorkoutActive = false

    var body: some View {
        VStack {
            Text("Training Type: \(trainingType.rawValue)")
            Text("Heart Rate: \(monitor.heartRate, specifier: "%.0f") bpm")
            
            if isWorkoutActive {
                Button("Finish Workout") {
                    monitor.stopWorkoutSession()
                    isWorkoutActive = false
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            } else {
                Button("Start Workout") {
                    isWorkoutActive = true
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .onChange(of: monitor.heartRate) { newHeartRate in
            if let age = monitor.getAge() {
                print("Heart rate changed to: \(newHeartRate), age: \(age), training type: \(trainingType)")
                zoneManager.updateZone(for: newHeartRate, age: age, trainingType: trainingType)
            }
        }
        .onAppear {
            monitor.requestAuthorization()
            monitor.fetchAge()
        }
    }
}
