import Foundation
import HealthKit

class FatBurningManager: ObservableObject {
    private let heartRateManager = HeartRateManager()
    private let zoneManager = HeartRateZoneManager()
    private let healthKitManager = HealthKitAuthorizationManager()
    
    @Published var currentHeartRate: Double = 0.0
    @Published var age: Int?
    @Published var isWorkoutActive: Bool = false
    @Published var currentZone: String = "Below Target" // Для отображения в UI
    
    init() {
        print("FatBurningManager initialized.")
        fetchUserDetails()
        configureHeartRateMonitoring()
    }

    private func configureHeartRateMonitoring() {
        print("Configuring heart rate monitoring...")
        heartRateManager.onHeartRateUpdate = { [weak self] heartRate in
            print("Heart rate received: \(heartRate)")
            DispatchQueue.main.async {
                self?.currentHeartRate = heartRate
                self?.updateZone(for: heartRate)
            }
        }
    }

    private func fetchUserDetails() {
        print("Fetching user details...")
        healthKitManager.fetchAge { [weak self] age in
            print("Fetched age: \(String(describing: age))")
            DispatchQueue.main.async {
                self?.age = age
            }
        }
    }

    private func updateZone(for heartRate: Double) {
        print("Updating zone for heart rate: \(heartRate)")
        guard let age = age else {
            print("Age is not available yet.")
            return
        }
        
        zoneManager.updateZone(for: heartRate, age: age, trainingType: .fatBurning) { [weak self] (newZone: HeartRateZone) in
            print("New zone received: \(newZone)")
            DispatchQueue.main.async {
                self?.currentZone = "\(newZone)" // Конвертация в строку для UI
                print("Zone updated to: \(self?.currentZone ?? "Unknown")")
            }
        }
    }

    func startWorkout() {
        print("Starting workout...")
        isWorkoutActive = true
        heartRateManager.startHeartRateMonitoring()
    }

    func stopWorkout() {
        print("Stopping workout...")
        isWorkoutActive = false
        heartRateManager.stopHeartRateMonitoring()
    }
}
