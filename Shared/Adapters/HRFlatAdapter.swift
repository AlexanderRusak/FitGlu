import Foundation
import HealthKit

/// «Сырые» записи из БД / HealthKit
typealias HRRaw = HeartRateLogRow     // ← ваша модель

struct HRChunk {
    var rows: [HeartRateLogRow]
}

// MARK: – Flat‑Run Adapterћ
final class HRFlatAdapter {
    
    private let maxGap: TimeInterval

    init(maxGap: TimeInterval = 5 * 60) {      // ← можно настроить при создании
        self.maxGap = maxGap
    }

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
    
    func chunks(from samples: [HKQuantitySample]) -> [[HKQuantitySample]] {

        // 1) прежнее «очищение» (удаляем подряд-идущие одинаковые bpm)
        let cleaned = convert(samples).sorted { $0.startDate < $1.startDate }
        guard let first = cleaned.first else { return [] }

        // 2) сегментация по разрыву
        var segments: [[HKQuantitySample]] = [[first]]

        for s in cleaned.dropFirst() {
            guard let last = segments.last?.last else { continue }

            if s.startDate.timeIntervalSince(last.startDate) > maxGap {
                // дырка > maxGap → открываем новый сегмент
                segments.append([s])
            } else {
                segments[segments.count - 1].append(s)
            }
        }
        return segments
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

