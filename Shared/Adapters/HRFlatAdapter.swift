import Foundation
import HealthKit

/// «Сырые» записи из БД / HealthKit
typealias HRRaw = HeartRateLogRow     // ← ваша модель

// MARK: – Flat‑Run Adapterћ
final class HRFlatAdapter {

    /// Удаляет подряд идущие дубликаты HR‑значений
    func convert(_ raw: [HeartRateLogRow]) -> [HeartRateLogRow] {

        print("💓 HR (raw) =", raw.count)              // ← было

        guard !raw.isEmpty else { return [] }

        var cleaned: [HeartRateLogRow] = []
        var lastValue: Int?

        for sample in raw {
            let v = sample.heartRate
            guard v != lastValue else { continue }    // пропускаем дубль
            lastValue = v
            cleaned.append(sample)
        }

        print("💓 HR (clean) =", cleaned.count)        // ← стало
        return cleaned
    }
}

extension HRFlatAdapter {

    /// Сглаживание для массива HKQuantitySample
    /// (использует ту же логику flat‑run внутри)
    func convert(_ samples: [HKQuantitySample]) -> [HKQuantitySample] {
        guard samples.count > 1 else { return samples }

        var cleaned: [HKQuantitySample] = []
        var lastBPM: Int?

        for s in samples {
            let bpm = Int(s.quantity.doubleValue(
                for: .count().unitDivided(by: .minute())) )
            guard bpm != lastBPM else { continue }
            lastBPM = bpm
            cleaned.append(s)
        }
        return cleaned
    }
}

