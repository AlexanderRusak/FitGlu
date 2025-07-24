import Foundation
import SQLite


public final class SessionZonesDBManager {

    // Singleton
    public static let shared = SessionZonesDBManager()

    // Подключение к БД (берём из вашего DatabaseService)
    private let db: Connection = DatabaseService.shared.db

    // Таблица session_zones
    private let tableSessionZones = Table("session_zones")

    // Колонки
    private let id       = SQLite.Expression<Int64>("id")
    private let start    = SQLite.Expression<Double>("start")
    private let end      = SQLite.Expression<Double>("end")
    private let z1Low    = SQLite.Expression<Int>("z1_low")
    private let z1High   = SQLite.Expression<Int>("z1_high")
    private let z2Low    = SQLite.Expression<Int>("z2_low")
    private let z2High   = SQLite.Expression<Int>("z2_high")
    private let z3Low    = SQLite.Expression<Int>("z3_low")
    private let z3High   = SQLite.Expression<Int>("z3_high")
    private let z4Low    = SQLite.Expression<Int>("z4_low")
    private let z4High   = SQLite.Expression<Int>("z4_high")
    private let z5Low    = SQLite.Expression<Int>("z5_low")
    private let z5High   = SQLite.Expression<Int>("z5_high")
    private let types = SQLite.Expression<String>("types")

    private init() {
        do {
            try db.run(tableSessionZones.create(ifNotExists: true) { t in
                t.column(id,      primaryKey: .autoincrement)
                t.column(start,   unique: true)
                t.column(end)
                t.column(z1Low);  t.column(z1High)
                t.column(z2Low);  t.column(z2High)
                t.column(z3Low);  t.column(z3High)
                t.column(z4Low);  t.column(z4High)
                t.column(z5Low);  t.column(z5High)
            })
        } catch {
            print("❌ SessionZonesDBManager init error:", error)
        }
    }

    /// Сохраняет одну сессию, если её ещё нет (по start)
    public func save(session: SessionDTO) throws {
        // проверяем, есть ли уже
        if try exists(start: session.start) { return }

        let insert = tableSessionZones.insert(
            start  <- session.start,
            end    <- session.end,
            z1Low  <- session.zones.z1[0],
            z1High <- session.zones.z1[1],
            z2Low  <- session.zones.z2[0],
            z2High <- session.zones.z2[1],
            z3Low  <- session.zones.z3[0],
            z3High <- session.zones.z3[1],
            z4Low  <- session.zones.z4[0],
            z4High <- session.zones.z4[1],
            z5Low  <- session.zones.z5[0],
            z5High <- session.zones.z5[1]
        )
        try db.run(insert)
    }

    /// Сохраняет массив сессий, пропуская дубли
    public func save(sessions: [SessionDTO]) throws {
        try db.transaction {
            for s in sessions {
                try save(session: s)
            }
        }
    }

    /// Проверяет, есть ли в БД сессия с таким start
    public func exists(start startTime: Double) throws -> Bool {
        let query = tableSessionZones.filter(start == startTime).limit(1)
        let count = try db.scalar(query.count)
        return count > 0
    }

    /// Возвращает все сохранённые сессии
    public func fetchAll() throws -> [SessionDTO] {
        var result = [SessionDTO]()
        for row in try db.prepare(tableSessionZones.order(start.asc)) {
            let types = try decodeTypes(row[types])
            let zones = ZoneThresholds(
                z1: [row[z1Low],  row[z1High]],
                z2: [row[z2Low],  row[z2High]],
                z3: [row[z3Low],  row[z3High]],
                z4: [row[z4Low],  row[z4High]],
                z5: [row[z5Low],  row[z5High]]
            )
            let dto = SessionDTO(
                start:    row[start],
                end:      row[end],
                workouts: [],    // в БД храним только зоны, сами WorkoutChunk нет необходимости сюда складывать
                lag:      0,     // при желании можно добавить колонку lag и сохранять её
                zones:    zones

            )
            result.append(dto)
        }
        return result
    }

    /// Подсчитывает общее число записей
    public func count() throws -> Int {
        try db.scalar(tableSessionZones.count)
    }
    
    public func clearAll() throws {
        try db.run(tableSessionZones.delete())
    }
    
    private func encodeTypes(_ types: [String]) throws -> String {
        let data = try JSONEncoder().encode(types)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private func decodeTypes(_ str: String) throws -> [String] {
        guard let data = str.data(using: .utf8) else { return [] }
        return try JSONDecoder().decode([String].self, from: data)
    }
}
