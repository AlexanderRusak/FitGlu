import Foundation
import WatchKit

class HeartRateZoneManager {
    private var currentZone: HeartRateZone = .belowTarget
    private var hasSignaledWithinTarget = false // Флаг для отслеживания сигнала "в норме"

    func updateZone(for heartRate: Double, age: Int, trainingType: TrainingType, onZoneChange: @escaping (HeartRateZone) -> Void) {
        print("Calculating zone for heart rate: \(heartRate), age: \(age), training type: \(trainingType)")
        let newZone = HeartRateZonesCalculator.getHeartRateZone(for: heartRate, age: age, trainingType: trainingType)
        
        print("Current zone: \(currentZone), New zone: \(newZone)")
        
        // Если зона изменилась
        if newZone != currentZone {
            print("Zone changed to \(newZone). Triggering haptic feedback.")
            currentZone = newZone
            hasSignaledWithinTarget = false
            triggerHapticFeedback(for: newZone)
            onZoneChange(newZone)
        }
        
        // Если зона не изменилась, но пользователь вне зоны "в норме"
        if newZone != .withinTarget {
            print("Still outside target zone. Triggering haptic feedback.")
            triggerHapticFeedback(for: newZone)
        } else if newZone == .withinTarget, !hasSignaledWithinTarget {
            print("Within target zone. Triggering haptic feedback.")
            triggerHapticFeedback(for: newZone)
            hasSignaledWithinTarget = true
        }
    }

    
    private func triggerHaptic(type: WKHapticType, repeatCount: Int = 1, delay: Double = 0.4) {
        guard repeatCount > 0 else { return }
        let device = WKInterfaceDevice.current()
        print("Triggering haptic: \(type) \(repeatCount) times.")
        device.play(type)
        if repeatCount > 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.triggerHaptic(type: type, repeatCount: repeatCount - 1, delay: delay)
            }
        }
    }

    private func triggerHapticFeedback(for zone: HeartRateZone) {
        print("Triggering haptic feedback for zone: \(zone)")
        switch zone {
        case .belowTarget:
            triggerHaptic(type: .directionUp, repeatCount: 3)
        case .withinTarget:
            if !hasSignaledWithinTarget {
                triggerHaptic(type: .success)
                hasSignaledWithinTarget = true // Устанавливаем флаг
            }
        case .aboveTarget:
            triggerHaptic(type: .failure, repeatCount: 4)
        }
    }
}
