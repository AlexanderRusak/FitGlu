import Foundation

/// Пара «время–глюкоза» – ровно то, что пойдёт в БД
public struct GPair: Codable {
    public let t: TimeInterval   // сек – timestamp (уже СДВИНУТ)
    public let g: Double         // mg/dL
}

public extension SessionDTO {

    /// Все ТОЛЬКО смещённые точки CGM (одна на каждый HR-семпл).
    /// Работает с вашей существующей схемой, потому что в `SessionAnalyzer`
    /// вы уже вызвали `withShiftedGlucose` перед тем, как собрать `SessionDTO`.
    var shiftedGlucosePairs: [GPair] {
        workouts
            .flatMap(\.points)          // все HRGlucosePoint
            .map { GPair(t: $0.glucoseTimestamp,
                         g: $0.glucose) }
            .sorted { $0.t < $1.t }     // (необязательно, но приятно)
    }
}
