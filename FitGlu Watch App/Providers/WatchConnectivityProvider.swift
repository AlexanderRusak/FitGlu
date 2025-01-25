import Foundation
import WatchConnectivity

class WatchConnectivityProvider: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityProvider()
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        print("Watch session activated. State=\(activationState.rawValue), error=\(String(describing: error))")
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("Watch: isReachable=\(session.isReachable)")
        if session.isReachable {
            // вызов общей логики из TrainingLogDBManager:
            TrainingLogDBManager.shared.syncAllUnSynced()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Watch got message: \(message)")
        // ...
    }
}
