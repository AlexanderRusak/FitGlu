import Foundation
import SQLite

public class DatabaseService {
    public static let shared = DatabaseService()
    
    public let db: Connection
    
    private init() {
        do {
            let documentsUrl = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let fileUrl = documentsUrl.appendingPathComponent("training.db")
            
            db = try Connection(fileUrl.path)
            print("Shared DatabaseService: DB opened at \(fileUrl.path)")
        } catch {
            fatalError("Shared DatabaseService error: \(error)")
        }
    }
}
