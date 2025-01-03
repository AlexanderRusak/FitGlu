import SwiftUI

struct FatBurningView: View {
    @StateObject private var manager = FatBurningManager()

    var body: some View {
        VStack(spacing: 5) {
            // Заголовок
            Text("Fat Burning Workout")
                .font(.headline)
                .padding(.top, 0)

            // Блок пульса и глюкозы
            HStack(spacing: 15) {
                // Пульс
                VStack(spacing: 0) {
                    Text("\(String(format: "%.0f", manager.currentHeartRate))")
                        .font(.system(size: 40, weight: .heavy, design: .default))
                        .foregroundColor(.green)

                    Text("bpm")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }

                // Вертикальный разделитель (опционально)
                Divider()
                    .frame(height: 40)
                    .background(Color.gray.opacity(0.5))

                // Глюкоза
                VStack(spacing: 4) {
                    // Само значение глюкозы
                    Text("\(String(format: "%.1f", manager.currentGlucose))") // "%.0f" если хотите без десятичных
                        .font(.system(size: 30, weight: .bold, design: .default))
                        .foregroundColor(.pink)

                    // Подпись с единицей измерения
                    Text("mg/dL")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 0)

            // Зона
            Text("Zone: \(manager.currentZone)")
                .font(.headline)
                .foregroundColor(colorForZone(manager.currentZone))
                .padding(.vertical, 0)


            // Кнопка управления тренировкой
            if manager.isWorkoutActive {
                Button {
                    manager.stopWorkout()
                } label: {
                    Text("Finish Workout")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            } else {
                Button {
                    manager.startWorkout()
                } label: {
                    Text("Start Workout")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .navigationTitle("Fat Burning")
        .navigationBarTitleDisplayMode(.inline)
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
