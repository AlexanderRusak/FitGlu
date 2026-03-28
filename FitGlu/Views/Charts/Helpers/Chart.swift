import SwiftUI
import Charts

// MARK: - Dense grid helper
public extension Chart {

    // MARK: 1. Только плотная X-сетка (крупные + мелкие деления)
    func denseXGrid(
        major: Calendar.Component = .hour,
        majorStep: Int            = 1,
        minor: Calendar.Component = .minute,
        minorStep: Int            = 15
    ) -> some View {
        self.chartXAxis {
            // ── крупные деления (толстая линия + подпись)
            AxisMarks(values: .stride(by: major, count: majorStep)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6))
                AxisTick()
                AxisValueLabel()
            }
            // ── мелкие деления (пунктир, без подписи)
            AxisMarks(values: .stride(by: minor, count: minorStep)) { _ in
                AxisGridLine(
                    stroke: StrokeStyle(lineWidth: 0.3, dash: [2, 4])
                )
                .foregroundStyle(.gray.opacity(0.25))
            }
        }
    }

    // MARK: 2. Плотная X-сетка + густая шкала по Y
    func denseAxes(
        // X
        majorX: Calendar.Component = .hour,
        majorXStep: Int            = 1,
        minorX: Calendar.Component = .minute,
        minorXStep: Int            = 10,
        // Y
        yStep: Double              = 25        // шаг сетки по оси Y
    ) -> some View {

        self
        // ───────── X ─────────
        .chartXAxis {
            // крупные (часы)
            AxisMarks(values: .stride(by: majorX, count: majorXStep)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6))
                AxisTick()
                AxisValueLabel()
            }
            // мелкие (минуты)
            AxisMarks(values: .stride(by: minorX, count: minorXStep)) { _ in
                AxisGridLine(
                    stroke: StrokeStyle(lineWidth: 0.3, dash: [2, 4])
                )
                .foregroundStyle(.gray.opacity(0.25))
                // ▸ подписи на «мелких» делениях можно включить выборочно:
                // AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        // ───────── Y ─────────
        .chartYAxis {
            AxisMarks(values: .stride(by: yStep)) { _ in
                AxisGridLine(
                    stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3])
                )
                .foregroundStyle(.gray.opacity(0.25))
                AxisTick()
                AxisValueLabel()   // каждая горизонтальная линия подписана
            }
        }
    }
}
