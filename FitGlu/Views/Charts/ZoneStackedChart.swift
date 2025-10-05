import SwiftUI
import Charts

public enum ZonesChartMode { case minutes, percent }

public struct ZonesStackedChart: View {
    @State private var visibleZones: Set<ZoneKind> = [.rec, .fat, .tran, .ana, .stress]
    @State private var probeDate: Date? = nil

    public let data: [ZoneDayPoint]       // исходные точки (минуты)
    public var mode: ZonesChartMode = .minutes
    public var showLegend: Bool = true
    public var showValueLabels: Bool = true
    public var showPeriodSummary: Bool = true
    public var showAvgBand: Bool = true

    public init(
        data: [ZoneDayPoint],
        mode: ZonesChartMode = .minutes,
        showLegend: Bool = true,
        showValueLabels: Bool = true,
        showPeriodSummary: Bool = true,
        showAvgBand: Bool = true
    ) {
        self.data = data.sorted { $0.date < $1.date }
        self.mode = mode
        self.showLegend = showLegend
        self.showValueLabels = showValueLabels
        self.showPeriodSummary = showPeriodSummary
        self.showAvgBand = showAvgBand
    }

    // ВАЖНО: что показываем — минуты или проценты
    private var displayData: [ZoneDayPoint] {
        mode == .minutes ? data : data.normalizedToPercent()
    }

    // MARK: Slice
    private struct Slice: Identifiable {
        let id = UUID()
        let day: Date
        let kind: ZoneKind
        let yStart: Double
        let yEnd: Double
        let value: Double
    }

    private var slices: [Slice] {
        displayData.flatMap { point in
            var cursor = 0.0
            var items: [Slice] = []
            func push(_ kind: ZoneKind, _ value: Double) {
                guard value > 0 else { return }
                items.append(.init(day: point.date, kind: kind,
                                   yStart: cursor, yEnd: cursor + value, value: value))
                cursor += value
            }
            push(.rec, point.rec)
            push(.fat, point.fat)
            push(.tran, point.tran)
            push(.ana, point.ana)
            push(.stress, point.stress)
            return items.filter { visibleZones.contains($0.kind) }
        }
    }

    private struct DayTotal: Identifiable {
        let id = UUID()
        let date: Date
        let total: Double
    }
    private var dayTotals: [DayTotal] {
        displayData.map { .init(date: $0.date, total: $0.total) }
    }

    // Домены
    private var yMaxMinutes: Double {
        let m = data.map(\.total).max() ?? 0
        let padded = m + 10
        return max(0, (ceil(padded / 10.0) * 10.0))
    }
    private var yDomain: ClosedRange<Double> {
        mode == .minutes ? (0...yMaxMinutes) : (0...100)
    }
    private var xDomain: ClosedRange<Date> {
        let s = displayData.first?.date ?? Date()
        let e = displayData.last?.date  ?? Date()
        return s...e
    }

    // Сводка периода
    public struct PeriodSummary {
        public let rec: Double, fat: Double, tran: Double, ana: Double, stress: Double
        public var total: Double { rec + fat + tran + ana + stress }
        public func pct(_ v: Double) -> Int { total > 0 ? Int(round(100 * v / total)) : 0 }
    }
    private var summary: PeriodSummary {
        .init(
            rec:    displayData.reduce(0){ $0 + $1.rec },
            fat:    displayData.reduce(0){ $0 + $1.fat },
            tran:   displayData.reduce(0){ $0 + $1.tran },
            ana:    displayData.reduce(0){ $0 + $1.ana },
            stress: displayData.reduce(0){ $0 + $1.stress }
        )
    }

    public var body: some View {
        VStack(spacing: 10) {
            chartView.frame(height: 260)

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

    @ViewBuilder
    private var chartView: some View {
        // среднее — только для минутного режима
        let avgTotal: Double = {
            guard mode == .minutes, !data.isEmpty else { return 0 }
            let sum = data.reduce(0) { $0 + $1.total }
            return sum / Double(data.count)
        }()
        let bandHalf: Double = mode == .minutes ? (yMaxMinutes * 0.10) : 0
        let bandLow  = max(0, avgTotal - bandHalf)
        let bandHigh = min(yMaxMinutes, avgTotal + bandHalf)

        Chart {
            // Вертикальная линия + тултип
            if let d = probeDate, let info = totalsFor(day: d) {
                RuleMark(x: .value("Probe", d))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3,3]))
                    .annotation(position: .topLeading) {
                        TooltipCard(date: d, total: info.total, parts: info.parts, mode: mode)
                    }
            }

            if mode == .minutes, showAvgBand, !data.isEmpty {
                // AVG band
                RectangleMark(
                    xStart: .value("Start", xDomain.lowerBound),
                    xEnd:   .value("End",   xDomain.upperBound),
                    yStart: .value("Low",   bandLow),
                    yEnd:   .value("High",  bandHigh)
                )
                .foregroundStyle(.secondary.opacity(0.12))
                .cornerRadius(2)

                // AVG line
                RuleMark(y: .value("Avg", avgTotal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .leading) {
                        Text("Avg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
            }

            // Стеки
            ForEach(slices) { s in
                RectangleMark(
                    x: .value("Day", s.day, unit: .day),
                    yStart: .value("Start", s.yStart),
                    yEnd: .value("End", s.yEnd)
                )
                .foregroundStyle(color(for: s.kind))
                .cornerRadius(2)
            }

            // Подписи тоталов (мин/%, зависят от режима)
            if showValueLabels {
                ForEach(dayTotals) { t in
                    PointMark(
                        x: .value("Day", t.date, unit: .day),
                        y: .value("Total", t.total)
                    )
                    .opacity(0.001)
                    .annotation(position: .top) {
                        Text(mode == .minutes ? "\(Int(round(t.total)))" : "\(Int(round(t.total)))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) {
                AxisGridLine().foregroundStyle(.tertiary)
                AxisTick()
                AxisValueLabel(format: .dateTime.day())
            }
        }
        .chartYAxis { AxisMarks() }
        .chartOverlay { proxy in
            GeometryReader { geo in
                let frame = geo[proxy.plotAreaFrame]
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let localX = value.location.x - frame.origin.x
                                if localX >= 0, localX <= frame.size.width,
                                   let date: Date = proxy.value(atX: localX) {
                                    withAnimation(.easeInOut(duration: 0.12)) {
                                        probeDate = snapDate(date)
                                    }
                                }
                            }
                    )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: displayData)
    }

    private func color(for kind: ZoneKind) -> some ShapeStyle {
        switch kind {
        case .rec:    return ZonePalette.rec
        case .fat:    return ZonePalette.fat
        case .tran:   return ZonePalette.tran
        case .ana:    return ZonePalette.ana
        case .stress: return ZonePalette.stress
        }
    }

    private func snapDate(_ x: Date) -> Date? {
        guard !displayData.isEmpty else { return nil }
        let d = Calendar.current.startOfDay(for: x)
        return displayData.min(by: { abs($0.date.timeIntervalSince(d)) < abs($1.date.timeIntervalSince(d)) })?.date
    }

    /// Возвращает total и пары (зона, значение) с учётом режима и фильтра видимости.
    private func totalsFor(day: Date) -> (total: Double, parts: [(ZoneKind, Double)])? {
        guard let p = displayData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) else { return nil }
        let pairs: [(ZoneKind, Double)] = [
            (.rec, p.rec), (.fat, p.fat), (.tran, p.tran), (.ana, p.ana), (.stress, p.stress)
        ].filter { visibleZones.contains($0.0) && $0.1 > 0 }

        let total = pairs.reduce(0) { $0 + $1.1 }
        return (total, pairs)
    }
}

// ───────── Легенда и сводка (микроправка цвета) ─────────

private struct ZonesLegendInteractive: View {
    @Binding var visible: Set<ZoneKind>
    var body: some View {
        HStack(spacing: 10) {
            item(.rec,    title: "rec",    color: ZonePalette.rec)
            item(.fat,    title: "fat",    color: ZonePalette.fat)
            item(.tran,   title: "tran",   color: ZonePalette.tran)
            item(.ana,    title: "ana",    color: ZonePalette.ana)
            item(.stress, title: "stress", color: ZonePalette.stress)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    @ViewBuilder
    private func item(_ kind: ZoneKind, title: String, color: Color) -> some View {
        let isOn = visible.contains(kind)
        Button {
            if isOn { visible.remove(kind) } else { visible.insert(kind) }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(isOn ? color : color.opacity(0.25))
                    .frame(width: 10, height: 10)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(isOn ? Color.secondary : Color.secondary.opacity(0.5))
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(.thickMaterial.opacity(isOn ? 0.18 : 0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct PeriodSummaryView: View {
    let summary: ZonesStackedChart.PeriodSummary
    let mode: ZonesChartMode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Period totals")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                stat(.rec,    "rec",    summary.rec,    summary.pct(summary.rec))
                stat(.fat,    "fat",    summary.fat,    summary.pct(summary.fat))
                stat(.tran,   "tran",   summary.tran,   summary.pct(summary.tran))
                stat(.ana,    "ana",    summary.ana,    summary.pct(summary.ana))
                stat(.stress, "stress", summary.stress, summary.pct(summary.stress))
            }
            let totalText = mode == .minutes ? "Total: \(Int(summary.total.rounded())) min" : "Total: 100%"
            Text(totalText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stat(_ kind: ZoneKind, _ label: String, _ value: Double, _ pct: Int) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color(for: kind))
                .frame(width: 8, height: 8)
            let valueText = "\(label) \(Int(value.rounded()))\(mode == .minutes ? "m" : "%") (\(pct)%)"
            Text(valueText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func color(for kind: ZoneKind) -> Color {
        switch kind {
        case .rec: return ZonePalette.rec
        case .fat: return ZonePalette.fat
        case .tran: return ZonePalette.tran
        case .ana: return ZonePalette.ana
        case .stress: return ZonePalette.stress
        }
    }
}

// Тултип теперь знает про режим
private struct TooltipCard: View {
    let date: Date
    let total: Double
    let parts: [(ZoneKind, Double)]
    let mode: ZonesChartMode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(date, format: .dateTime.day().month(.abbreviated))
                .font(.caption).foregroundStyle(.secondary)
            Text(mode == .minutes ? "\(Int(total.rounded())) min" : "\(Int(total.rounded()))%")
                .font(.footnote.weight(.semibold))
            ForEach(parts, id: \.0) { (k, v) in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: k))
                        .frame(width: 8, height: 8)
                    Text("\(k.shortTitle) \(Int(v.rounded()))\(mode == .minutes ? "m" : "%")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 3, x: 0, y: 1)
    }

    private func color(for kind: ZoneKind) -> Color {
        switch kind {
        case .rec: return ZonePalette.rec
        case .fat: return ZonePalette.fat
        case .tran: return ZonePalette.tran
        case .ana: return ZonePalette.ana
        case .stress: return ZonePalette.stress
        }
    }
}

private extension ZoneKind {
    var shortTitle: String {
        switch self {
        case .rec: return "rec"
        case .fat: return "fat"
        case .tran: return "tran"
        case .ana: return "ana"
        case .stress: return "stress"
        }
    }
}
