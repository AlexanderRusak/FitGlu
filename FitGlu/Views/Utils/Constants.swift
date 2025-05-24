
import CoreGraphics

struct ChartConfig {
    let panDamping:   Double
    let zoomAmplifier: CGFloat
    let maxZoom: ClosedRange<CGFloat>

    static let `default` = ChartConfig(
        panDamping: 0.01,          // «тяжесть» скролла
        zoomAmplifier: 4,          // чувствительность pinch-zoom
        maxZoom: 1...40
    )
}
