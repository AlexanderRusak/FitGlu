import Foundation
import HealthKit

class HeartRateMonitor: ObservableObject {
    private let heartRateManager = HeartRateManager()
    private let workoutManager = WorkoutManager()

    @Published var heartRate: Double = 0.0
    @Published var age: Int? // Используется напрямую в SwiftUI

    init() {
        heartRateManager.onHeartRateUpdate = { [weak self] newHeartRate in
            DispatchQueue.main.async {
                self?.heartRate = newHeartRate
            }
        }
    }

    func fetchAge(using authorizationManager: HealthKitAuthorizationManager) {
        authorizationManager.fetchAge { [weak self] fetchedAge in
            DispatchQueue.main.async {
                self?.age = fetchedAge
            }
        }
    }

    func startWorkoutSession() {
        workoutManager.startWorkoutSession { error in
            if let error = error {
                print("Ошибка начала тренировки: \(error.localizedDescription)")
            } else {
                self.heartRateManager.startHeartRateMonitoring()
            }
        }
    }

    func stopWorkoutSession() {
        workoutManager.stopWorkoutSession { error in
            if let error = error {
                print("Ошибка завершения тренировки: \(error.localizedDescription)")
            } else {
                self.heartRateManager.stopHeartRateMonitoring()
            }
        }
    }
}
