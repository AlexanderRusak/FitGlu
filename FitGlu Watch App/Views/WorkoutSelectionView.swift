import SwiftUI

struct WorkoutSelectionView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: FatBurningView()) {
                    Text(TrainingType.fatBurning.rawValue)
                }
                NavigationLink(destination: CardioView()) {
                    Text(TrainingType.cardio.rawValue)
                }
                NavigationLink(destination: HighIntensityView()) {
                    Text(TrainingType.highIntensity.rawValue)
                }
            }
            .navigationTitle("Select Workout")
        }
    }
}

#Preview {
    WorkoutSelectionView()
}
