// Views/Charts/ZonesStacked/ZonesStackedChart.swift
import SwiftUI
import Charts

/// Публичная обёртка графика зон за период (iOS 16 совместимый)
public struct ZonesStackedChart: View {

    // MARK: – Параметры API
    public let data: [ZoneDayPoint]      // уже отсортировано по дате
    public var mode: ZonesChartMode
    public var showLegend: Bool
    public var showValueLabels: Bool
    public var showPeriodSummary: Bool

    // MARK: – UI state
    @State var visibleZones: Set<ZoneKind> = [.rec, .fat, .tran, .ana, .stress]
    @State var probeDate: Date? = nil     // «залипание» выбранного дня по тапу

    public init(
        data: [ZoneDayPoint],
        mode: ZonesChartMode = .minutes,
        showLegend: Bool = true,
        showValueLabels: Bool = true,
        showPeriodSummary: Bool = true
    ) {
        self.data = data
        self.mode = mode
        self.showLegend = showLegend
        self.showValueLabels = showValueLabels
        self.showPeriodSummary = showPeriodSummary
    }

    public var body: some View {
        VStack(spacing: 10) {
            chartView
                .frame(height: 260)

            if showLegend {
                ZonesLegendInteractive(visible: $visibleZones)
                    .padding(.top, 2)
            }

            if showPeriodSummary {
                PeriodSummaryView(summary: summary, mode: mode)
                    .padding(.top, 2)
            }
        }
        .accessibilityLabel("Time in HR zones per day")
    }
}
