import Foundation

public final class DailyAnalyzer {

    public enum ZoneKind { case rec, fat, tran, ana, stress }

    // ВНИМАНИЕ: без private, чтобы расширения в других файлах видели границы зон
    let z1: ClosedRange<Int>
    let z2: ClosedRange<Int>
    let z3: ClosedRange<Int>
    let z4: ClosedRange<Int>
    let z5: ClosedRange<Int>

    public init(thresholds: ZoneThresholds) {
        self.z1 = thresholds.z1[0]...thresholds.z1[1]
        self.z2 = thresholds.z2[0]...thresholds.z2[1]
        self.z3 = thresholds.z3[0]...thresholds.z3[1]
        self.z4 = thresholds.z4[0]...thresholds.z4[1]
        self.z5 = thresholds.z5[0]...thresholds.z5[1]
    }

    public static func withDefault(age: Int) -> DailyAnalyzer {
        DailyAnalyzer(thresholds: DefaultZonesProvider.estimate(age: age))
    }
}
