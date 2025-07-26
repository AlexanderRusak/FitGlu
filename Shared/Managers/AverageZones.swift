import Foundation
import SQLite

public final class AverageZonesDBManager {

    // MARK: – singleton
    public static let shared = AverageZonesDBManager()

    // MARK: – подключение к БД
    private let db: Connection = DatabaseService.shared.db

    // MARK: – таблица и колонки
    private let table           = SQLite.Table("average_zones")
    private let id              = SQLite.Expression<Int64>("id")
    private let count           = SQLite.Expression<Int>("count")
    private let z1Low           = SQLite.Expression<Int>("z1_low")
    private let z1High          = SQLite.Expression<Int>("z1_high")
    private let z2Low           = SQLite.Expression<Int>("z2_low")
    private let z2High          = SQLite.Expression<Int>("z2_high")
    private let z3Low           = SQLite.Expression<Int>("z3_low")
    private let z3High          = SQLite.Expression<Int>("z3_high")
    private let z4Low           = SQLite.Expression<Int>("z4_low")
    private let z4High          = SQLite.Expression<Int>("z4_high")
    private let z5Low           = SQLite.Expression<Int>("z5_low")
    private let z5High          = SQLite.Expression<Int>("z5_high")

    private init() {
        do {
            try db.run(table.create(ifNotExists: true) { t in
                t.column(id,     primaryKey: .autoincrement)
                t.column(count)
                t.column(z1Low);  t.column(z1High)
                t.column(z2Low);  t.column(z2High)
                t.column(z3Low);  t.column(z3High)
                t.column(z4Low);  t.column(z4High)
                t.column(z5Low);  t.column(z5High)
            })
        } catch {
            print("❌ AverageZonesDBManager init error:", error)
        }
    }

    /// Усредняем новую зону с уже сохранёнными
    public func upsertAverage(newZones: ZoneThresholds) throws {
        if try db.scalar(table.count) == 0 {
            // первая запись
            let insert = table.insert(
                count    <- 1,
                z1Low    <- newZones.z1[0],  z1High <- newZones.z1[1],
                z2Low    <- newZones.z2[0],  z2High <- newZones.z2[1],
                z3Low    <- newZones.z3[0],  z3High <- newZones.z3[1],
                z4Low    <- newZones.z4[0],  z4High <- newZones.z4[1],
                z5Low    <- newZones.z5[0],  z5High <- newZones.z5[1]
            )
            try db.run(insert)
        } else {
            // обновляем существующую запись
            guard let row = try db.pluck(table) else { return }
            let oldCount = row[count]
            func avg(_ old: Int, _ new: Int) -> Int {
                (old * oldCount + new) / (oldCount + 1)
            }
            let upd = table.update(
                count    <- oldCount + 1,
                z1Low    <- avg(row[z1Low], newZones.z1[0]),
                z1High   <- avg(row[z1High], newZones.z1[1]),
                z2Low    <- avg(row[z2Low], newZones.z2[0]),
                z2High   <- avg(row[z2High], newZones.z2[1]),
                z3Low    <- avg(row[z3Low], newZones.z3[0]),
                z3High   <- avg(row[z3High], newZones.z3[1]),
                z4Low    <- avg(row[z4Low], newZones.z4[0]),
                z4High   <- avg(row[z4High], newZones.z4[1]),
                z5Low    <- avg(row[z5Low], newZones.z5[0]),
                z5High   <- avg(row[z5High], newZones.z5[1])
            )
            try db.run(upd)
        }
    }

    /// Возвращает единственную запись со средними зонами
    public func fetchAverageZones() throws -> ZoneThresholds {
        guard let row = try db.pluck(table) else {
            return ZoneThresholds(z1: [0,0], z2: [0,0], z3: [0,0], z4: [0,0], z5: [0,0])
        }
        return ZoneThresholds(
            z1: [row[z1Low],  row[z1High]],
            z2: [row[z2Low],  row[z2High]],
            z3: [row[z3Low],  row[z3High]],
            z4: [row[z4Low],  row[z4High]],
            z5: [row[z5Low],  row[z5High]]
        )
    }

    /// Полностью очищает таблицу (для отладки)
    public func clearAll() throws {
        try db.run(table.delete())
    }
}
