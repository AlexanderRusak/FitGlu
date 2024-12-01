import SwiftUI

struct WorkoutSelectionView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: WorkoutMonitorView(trainingType: .fatBurning)) {
                    Text("Fat Burning")
                }
                NavigationLink(destination: WorkoutMonitorView(trainingType: .cardio)) {
                    Text("Cardio")
                }
                NavigationLink(destination: WorkoutMonitorView(trainingType: .highIntensity)) {
                    Text("High Intensity")
                }
            }
            .navigationTitle("Select Workout")
        }
    }
}

#Preview {
    WorkoutSelectionView()
}
