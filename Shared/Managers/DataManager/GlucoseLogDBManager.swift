import Foundation
import SQLite

public class GlucoseLogDBManager {
    public static let shared = GlucoseLogDBManager()
    private let db = DatabaseService.shared.db

    private let tableGlucose = Table("glucose_log")
    private let colID = SQLite.Expression<Int64>("id")
    private let colTimestamp = SQLite.Expression<Double>("timestamp")
    private let colGlucoseValue = SQLite.Expression<Double>("glucose_value")

    private init() {
        do {
            try createTable()
        } catch {
            print("❌ GlucoseLogDBManager: createTable error: \(error)")
        }
    }

    private func createTable() throws {
        try db.run(tableGlucose.create(ifNotExists: true) { t in
            t.column(colID, primaryKey: .autoincrement)
            t.column(colTimestamp, unique: true)  // Делаем timestamp уникальным!
            t.column(colGlucoseValue)
        })
        print("✅ GlucoseLogDBManager: created table glucose_log (if not existed)")
    }

    public func insertGlucose(timestamp: Double, value: Double) {
        // Проверяем, есть ли уже запись с таким timestamp
        if glucoseExists(timestamp: timestamp) {
            print("⚠️ GlucoseLogDBManager: запись с timestamp \(timestamp) уже есть, пропускаем")
            return
        }

        let insert = tableGlucose.insert(
            colTimestamp <- timestamp,
            colGlucoseValue <- value
        )
        do {
            let rowID = try db.run(insert)
            print("✅ GlucoseLogDBManager: inserted row \(rowID), glucose=\(value)")
        } catch {
            print("❌ GlucoseLogDBManager insertGlucose error: \(error)")
        }
    }
    
    // Проверка наличия записи
    private func glucoseExists(timestamp: Double) -> Bool {
        let query = tableGlucose.filter(colTimestamp == timestamp)
        do {
            return try db.pluck(query) != nil
        } catch {
            print("❌ GlucoseLogDBManager: Ошибка при проверке дубликатов: \(error)")
            return false
        }
    }
    
    // Получение всех данных
    public func getAllGlucose() -> [GlucoseRow] {
        var results: [GlucoseRow] = []
        do {
            for row in try db.prepare(tableGlucose) {
                let idVal = try row.get(colID)
                let tsVal = try row.get(colTimestamp)
                let gVal = try row.get(colGlucoseValue)
                results.append(GlucoseRow(id: idVal, timestamp: tsVal, glucoseValue: gVal))
            }
        } catch {
            print("❌ Error getAllGlucose: \(error)")
        }
        return results
    }
    
    public func getGlucoseInRange(start: Double, end: Double) -> [GlucoseRow] {
        var results: [GlucoseRow] = []
        let query = tableGlucose.filter(colTimestamp >= start && colTimestamp <= end)
        
        do {
            for row in try db.prepare(query) {
                let idVal = try row.get(colID)
                let tsVal = try row.get(colTimestamp)
                let gVal = try row.get(colGlucoseValue)
                results.append(GlucoseRow(id: idVal, timestamp: tsVal, glucoseValue: gVal))
            }
        } catch {
            print("❌ Error getGlucoseInRange: \(error)")
        }
        
        return results
    }
}




public struct GlucoseRow {
    public let id: Int64
    public let timestamp: Double
    public let glucoseValue: Double
}
