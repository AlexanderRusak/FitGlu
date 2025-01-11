// DatabaseService.swift
import Foundation
import SQLite

class DatabaseService {
    static let shared = DatabaseService()
    
    let db: Connection
    
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
            print("DatabaseService: DB created/opened at \(fileUrl.path)")
            
        } catch {
            fatalError("Ошибка инициализации базы: \(error)")
        }
    }
}
