import SwiftUI

struct FatBurningView: View {
    @StateObject private var manager = FatBurningManager()

    var body: some View {
        VStack {
            Text("Fat Burning Workout")
                .font(.headline)

            // Центральное отображение пульса
            Text("\(String(format: "%.0f", manager.currentHeartRate)) bpm")
                .font(.system(size: 30, weight: .bold, design: .default))
                .foregroundColor(.green)
                .padding(.vertical, 0)

            // Текущая зона тренировки
            Text("Zone: \(manager.currentZone)")
                .foregroundColor(colorForZone(manager.currentZone))
                .font(.title3)
                .padding()

            Spacer()

            // Кнопка управления тренировкой
            if manager.isWorkoutActive {
                Button("Finish Workout") {
                    manager.stopWorkout()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            } else {
                Button("Start Workout") {
                    manager.startWorkout()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
    }

    private func colorForZone(_ zone: String) -> Color {
        switch zone {
        case "Below Target": return .blue
        case "Within Target": return .green
        case "Above Target": return .red
        default: return .gray
        }
    }
}


#Preview {
    FatBurningView()
}
