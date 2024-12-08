import SwiftUI

struct WorkoutSelectionView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: FatBurningView()) {
                    Text(TrainingType.fatBurning.rawValue)
                }
                
                // Закомментировано временно, пока Cardio Training не реализована
                // NavigationLink(destination: CardioView()) {
                //     Text(TrainingType.cardio.rawValue)
                // }
                
                NavigationLink(destination: StrengthTrainingView()) {
                    Text("Strength Training")
                }
                
                // Закомментировано временно, пока High Intensity Training не реализована
                // NavigationLink(destination: HighIntensityView()) {
                //     Text(TrainingType.highIntensity.rawValue)
                // }
            }
            .navigationTitle("Select Workout")
        }
    }
}

#Preview {
    WorkoutSelectionView()
}
