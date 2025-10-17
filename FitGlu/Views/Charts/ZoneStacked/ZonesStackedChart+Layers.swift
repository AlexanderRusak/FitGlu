// Views/Charts/ZonesStacked/ZonesStackedChart+Layers.swift
import SwiftUI
import Charts

extension ZonesStackedChart {

    @ViewBuilder
    var chartView: some View {
        // --- вычисления ---
        let isMinutes = (mode == .minutes)
        let avgTotal: Double = {
            guard isMinutes, !data.isEmpty else { return 0 }
            let sum = data.reduce(0) { $0 + $1.total }
            return sum / Double(data.count)
        }()
        let bandHalf: Double  = isMinutes ? yMaxMinutes * 0.10 : 0
        let bandLow  = max(0, avgTotal - bandHalf)
        let bandHigh = min(yMaxMinutes, avgTotal + bandHalf)

        Chart {
            // 1) AVG band — фон (рисуем ПЕРЕД столбиками)
            if isMinutes, !data.isEmpty {
                RectangleMark(
                    xStart: .value("Start", xDomain.lowerBound),
                    xEnd:   .value("End",   xDomain.upperBound),
                    yStart: .value("Low",   bandLow),
                    yEnd:   .value("High",  bandHigh)
                )
                .foregroundStyle(Color.white.opacity(0.08))   // чуть светлее, чем .secondary.opacity(0.12)
                .cornerRadius(2)
            }

            // 2) Стеки
            ForEach(slices) { s in
                RectangleMark(
                    x:      .value("Day", s.day, unit: .day),
                    yStart: .value("Start", s.yStart),
                    yEnd:   .value("End",   s.yEnd)
                )
                .foregroundStyle(color(for: s.kind))
                .cornerRadius(2)
            }

            // 3) Линия среднего — РИСУЕМ ПОСЛЕ, чтобы была поверх баров
            if isMinutes, !data.isEmpty {
                RuleMark(y: .value("Avg", avgTotal))
                    .lineStyle(StrokeStyle(lineWidth: 1.6, dash: [5,4]))
                    .foregroundStyle(Color.blue.opacity(0.7))  // контрастнее
                    .annotation(position: .trailing) {
                        Text("Avg")
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
            }

            // 4) Метки тоталов, если нужно
            if showValueLabels {
                ForEach(dayTotals) { t in
                    PointMark(x: .value("Day", t.date, unit: .day),
                              y: .value("Total", t.total))
                        .opacity(0.001)
                        .annotation(position: .top) {
                            Text("\(Int(round(t.total)))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 2)
                                .padding(.horizontal, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                }
            }
        }
        // домены
        .chartXScale(domain: xDomain)
        .chartYScale(domain: yDomain)              // 0...yMaxMinutes для Minutes; 0...100 для Percent
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) {
                AxisGridLine().foregroundStyle(.tertiary)
                AxisTick()
                AxisValueLabel(format: .dateTime.day())
            }
        }
        .chartYAxis { AxisMarks() }
    }


    // MARK: – Слои

    struct AvgBandLayer: ChartContent {
        let enabled: Bool
        let xDomain: ClosedRange<Date>
        let low: Double
        let high: Double
        let avg: Double

        var body: some ChartContent {
            if enabled {
                RectangleMark(
                    xStart: .value("Start", xDomain.lowerBound),
                    xEnd:   .value("End",   xDomain.upperBound),
                    yStart: .value("Low",   low),
                    yEnd:   .value("High",  high)
                )
                .foregroundStyle(.secondary.opacity(0.12))
                .cornerRadius(2)

                RuleMark(y: .value("Avg", avg))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .leading) {
                        Text("Avg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
            }
        }
    }

    struct StacksLayer: ChartContent {
        let slices: [Slice]
        let colorFor: (ZoneKind) -> Color

        var body: some ChartContent {
            ForEach(slices) { s in
                RectangleMark(
                    x: .value("Day", s.day, unit: .day),
                    yStart: .value("Start", s.yStart),
                    yEnd: .value("End", s.yEnd)
                )
                .foregroundStyle(colorFor(s.kind))
                .cornerRadius(2)
            }
        }
    }

    struct TotalsLabelsLayer: ChartContent {
        let totals: [DayTotal]
        let mode: ZonesChartMode

        var body: some ChartContent {
            ForEach(totals) { t in
                PointMark(
                    x: .value("Day", t.date, unit: .day),
                    y: .value("Total", t.total)
                )
                .opacity(0.001)
                .annotation(position: .top) {
                    Text(mode == .minutes ? "\(Int(round(t.total)))"
                                          : "\(Int(round(t.total)))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
    }

    // Цвет зоны
    func color(for kind: ZoneKind) -> Color {
        switch kind {
        case .rec:    return ZonePalette.rec
        case .fat:    return ZonePalette.fat
        case .tran:   return ZonePalette.tran
        case .ana:    return ZonePalette.ana
        case .stress: return ZonePalette.stress
        }
    }
}
