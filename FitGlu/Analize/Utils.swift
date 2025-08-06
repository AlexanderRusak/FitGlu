import Foundation

@inline(__always)
func safeRate(kcal: Double,
                          stressSec: TimeInterval,
                          minSeconds: TimeInterval = 60) -> Double {
    guard stressSec >= minSeconds else { return 0 }          // < 1 минуты — считаем не определено
    return kcal / (stressSec / 60.0)
}

func stressLabel(_ seconds: TimeInterval) -> String {
    if seconds < 60 { return "<1m" }
    let m = Int(seconds.rounded() / 60)
    return "\(m)m"
}

func effText(kcalPerStressMin: Double, stressSec: TimeInterval, showDash: Bool = true) -> String {
    guard stressSec >= 60 else { return showDash ? "—" : "0.0" }
    return String(format: "%.1f", kcalPerStressMin)
}

private let kcalFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    return f
}()

func kcalText(_ kcal: Double) -> String {
    kcalFormatter.string(from: NSNumber(value: kcal.rounded())) ?? "\(Int(kcal.rounded()))"
}
