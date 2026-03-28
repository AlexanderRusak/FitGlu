import Foundation

final class DefaultZonesProvider {
    static func estimate(age: Int) -> ZoneThresholds {
        let maxHR = 220 - age

        let z1 = [Int(Double(maxHR) * 0.50), Int(Double(maxHR) * 0.60)]
        let z2 = [Int(Double(maxHR) * 0.60), Int(Double(maxHR) * 0.70)]
        let z3 = [Int(Double(maxHR) * 0.70), Int(Double(maxHR) * 0.80)]
        let z4 = [Int(Double(maxHR) * 0.80), Int(Double(maxHR) * 0.90)]
        let z5 = [Int(Double(maxHR) * 0.90), maxHR]

        return ZoneThresholds(z1: z1, z2: z2, z3: z3, z4: z4, z5: z5)
    }
}
