import Foundation

// MARK: - Пара work/rest одного подхода
public struct WorkRestPair: Identifiable {
    public let id = UUID()
    public let work: TimeInterval   // сек
    public let rest: TimeInterval   // сек
    public let start: Date          // старт work
    public let end: Date            // конец rest
}

// MARK: - Сводка по списку пар
public struct WorkRestSummary {
    public let sets: Int
    public let avgWork: TimeInterval
    public let avgRest: TimeInterval
    public let workRestRatio: Double

    public static let zero = WorkRestSummary(sets: 0, avgWork: 0, avgRest: 0, workRestRatio: 0)
}

// Сводка по КОНКРЕТНОЙ тренировке (для списка)
public struct WRItem: Identifiable {
    public let id: Int64
    public let training: TrainingRow
    public let summary: WorkRestSummary
}

// MARK: - Параметры алгоритма
public struct WRParams {
    public var workHrr: Double      // вход в work по HRR
    public var restHrr: Double      // выход в rest по HRR
    public var minWork: TimeInterval
    public var minRest: TimeInterval
    public var gapSec: TimeInterval       // склейка кратких провалов
    public var smoothSec: TimeInterval    // сглаживание MA
    public var enterHold: TimeInterval    // сколько держать HR ≥ work для входа
    public var exitHold: TimeInterval     // сколько держать HR ≤ rest для выхода
    public var dropPct: Double            // относительное падение от пика (0.35 = −35%)
    public var fallHold: TimeInterval     // сколько держать падение

    public static func tuned(for type: String) -> WRParams {
        let t = type.lowercased()
        if t.contains("hiit") {
            return .init(workHrr: 0.50, restHrr: 0.40,
                         minWork: 8,   minRest: 12,
                         gapSec: 3, smoothSec: 5,
                         enterHold: 2, exitHold: 4,
                         dropPct: 0.30, fallHold: 2)
        } else if t.contains("strength") || t.contains("traditional") {
            return .init(workHrr: 0.45, restHrr: 0.35,
                         minWork: 10,  minRest: 20,
                         gapSec: 4, smoothSec: 5,
                         enterHold: 3, exitHold: 5,
                         dropPct: 0.35, fallHold: 3)
        } else {
            // для кардио — фактически отключаем детект пиков
            return .init(workHrr: 0.65, restHrr: 0.55,
                         minWork: 20,  minRest: 20,
                         gapSec: 3, smoothSec: 5,
                         enterHold: 3, exitHold: 5,
                         dropPct: 0.40, fallHold: 3)
        }
    }
}
