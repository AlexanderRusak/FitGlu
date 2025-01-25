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
        print("iPhone: session activated, state=\(activationState.rawValue), err=\(String(describing: error))")
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("iPhone: isReachable=\(session.isReachable)")
    }
    
    // Приходят сообщения "часы -> телефон"
    func session(_ session: WCSession, didReceiveMessage message: [String : Any],
                 replyHandler: @escaping ([String : Any]) -> Void) {
        print("iPhone got message: \(message)")
        
        // Сохраним для UI
        DispatchQueue.main.async {
            self.lastMessage = message
        }
        
        guard let action = message["action"] as? String else { return }
        if action == "finishWorkout" {
            // Parse data from the message
            guard let localID = message["localID"] as? Int64,
                  let type = message["type"] as? String,
                  let startTime = message["startTime"] as? Double,
                  let endTime = message["endTime"] as? Double else {
                replyHandler(["status": "error", "message": "Invalid data"])
                return
            }
            
            // Store in local iPhone database
            let trainingID = TrainingLogDBManager.shared.startTraining(type: TrainingType(rawValue: type) ?? .fatBurning)
            if let id = trainingID {
                TrainingLogDBManager.shared.rawUpdateStartEnd(id, startTime, endTime)
            }
            
            // Respond to the watch
            replyHandler(["status": "ok"])
        }
    }
}
