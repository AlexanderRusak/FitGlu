import Foundation
import WatchKit

class HeartRateZoneManager {
    private var currentZone: HeartRateZone = .belowTarget
    private var hasSignaledWithinTarget = false // Флаг для отслеживания сигнала "в норме"

    func updateZone(for heartRate: Double, age: Int, trainingType: TrainingType) {
        let newZone = HeartRateZonesCalculator.getHeartRateZone(for: heartRate, age: age, trainingType: trainingType)
        
        if newZone != currentZone {
            // Если зона изменилась, сбрасываем флаг "в норме" и сигнализируем о новой зоне
            currentZone = newZone
            hasSignaledWithinTarget = false
            triggerHapticFeedback(for: newZone)
        } else if newZone == .withinTarget, !hasSignaledWithinTarget {
            // Если зона "в норме" и сигнал еще не сработал
            triggerHapticFeedback(for: newZone)
        } else if newZone != .withinTarget {
            // Если зона не "в норме", постоянно сигнализируем
            triggerHapticFeedback(for: newZone)
        }
    }
    
    private func triggerHaptic(type: WKHapticType, repeatCount: Int = 1, delay: Double = 0.4) {
        guard repeatCount > 0 else { return }
        let device = WKInterfaceDevice.current()
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
