import Foundation
import WatchConnectivity
import SwiftUI

class PhoneConnectivityProvider: NSObject, ObservableObject, WCSessionDelegate {
    
    static let shared = PhoneConnectivityProvider()
    
    // Храним последнее пришедшее сообщение
    @Published var lastMessage: [String: Any]? = nil
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            let s = WCSession.default
            s.delegate = self
            s.activate()
        }
    }

    // MARK: - WCSessionDelegate (iOS)
    
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        print("📲 iPhone: session activated, state=\(activationState.rawValue), err=\(String(describing: error))")
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("📲 iPhone: isReachable=\(session.isReachable)")
    }
    
    // Приходят сообщения "часы -> телефон"
    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        print("📲 iPhone got message: \(message)")
        
        guard let action = message["action"] as? String else { return }
        if action == "finishWorkout" {
            guard let trainingID = message["trainingID"] as? Int64,
                  let type = message["type"] as? String,
                  let startTime = message["startTime"] as? Double,
                  let endTime = message["endTime"] as? Double else {
                print("❌ Ошибка: Некорректные данные тренировки")
                replyHandler(["status": "error", "message": "Invalid data"])
                return
            }
            
            print("✅ Данные тренировки: ID=\(trainingID), Type=\(type), Start=\(startTime), End=\(endTime)")
            
            // 💾 Сохранение тренировки в iPhone DB
            let newTrainingID = TrainingLogDBManager.shared.startTraining(type: TrainingType(rawValue: type) ?? .fatBurning)
            if let id = newTrainingID {
                TrainingLogDBManager.shared.rawUpdateStartEnd(id, startTime, endTime)
            }
            
            // 💓 Сохранение пульса
            if let heartRates = message["heartRates"] as? [[String: Any]] {
                for hr in heartRates {
                    if let timestamp = hr["timestamp"] as? Double,
                       let value = hr["value"] as? Int {
                        print("💓 Сохранение HR: \(value) BPM в \(timestamp)")
                        HeartRateLogDBManager.shared.insertHeartRate(trainingID: trainingID, hrValue: value, timestamp: timestamp)
                    }
                }
            }

            replyHandler(["status": "ok"])
        }
    }

}
