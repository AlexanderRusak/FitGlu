import SwiftUI
import Charts

// MARK: – Main chart view
struct GlucoseHeartRateChartView: View {

    /* tuneables */
    private let panDamping     : Double  = 0.01   // чем меньше – тем «тяжелее» скролл
    private let zoomAmplifier  : CGFloat = 4      // >1 усиливает pinch‑zoom
    private let maxZoom        : ClosedRange<CGFloat> = 1...40

    /* input */
    let glucoseData   : [GlucoseRow]
    let heartRateData : [HeartRateLogRow]
    let hrDailyPoints : [HRPoint]
    let trainings     : [TrainingRow]
    let domain        : ClosedRange<Date>      // период (сутки)

    /* zoom / pan state */
    @State private var lastGesture : CGFloat = 1
    @State private var scale       : CGFloat = 1
    @State private var offset      : TimeInterval = 0
    @State private var plotWidth   : CGFloat = 1      // вычисляется через overlay

    /* tooltip state */
    @State private var selectedTime      : Date?
    @State private var nearestGlucoseVal : (time: Date, value: Double)?
    @State private var nearestHRVal      : (time: Date, value: Double)?

    // MARK: – Derived helpers
    private var dayInterval: TimeInterval { domain.upperBound.timeIntervalSince(domain.lowerBound) }

    private var currentDomain: ClosedRange<Date> {
        let center = domain.lowerBound.addingTimeInterval(dayInterval / 2 + offset)
        let half   = dayInterval / (2 * Double(scale))
        return center.addingTimeInterval(-half) ... center.addingTimeInterval(half)
    }

    private var yMax: Double {
        let gMax = glucoseData.map(\.glucoseValue).max() ?? 10
        let hMax = Double(heartRateData.map(\.heartRate).max() ?? 120)
        return max(gMax, hMax) * 1.2
    }

    // MARK: – Body
    var body: some View {
        VStack(spacing: 6) {
            Text("Left Axis: Glucose (mg/dL) · Heart Rate (bpm)")
                .font(.subheadline).foregroundColor(.gray)

            Chart {
                trainingRects
                glucoseLine
                hrPoints(inWorkout: true)
                hrPoints(inWorkout: false)
            }
            .onAppear {
                       // 🔸 Выводим именно то, что график видит
                       print("""
                           ── Chart INPUT ──
                             trainings:      \(trainings.count)
                             HR points:      \(heartRateData.count)
                             HR ‘daily’:     \(hrDailyPoints.count)
                             glucose points: \(glucoseData.count)
                           ────────────────
                           """)
                   }
            .chartXScale(domain: currentDomain)
            .chartYScale(domain: 0...yMax)
            .chartYAxis { AxisMarks(position: .leading) { v in
                if let d = v.as(Double.self) { AxisValueLabel("\(Int(d))") }
            }}
            .chartOverlay { proxyOverlay($0) }
            .frame(maxWidth: .infinity)
            .border(.gray.opacity(0.3))

            legend
        }
        .padding(.horizontal)
    }
}

// MARK: – Chart building blocks
private extension GlucoseHeartRateChartView {

    // training rectangles
    var trainingRects: some ChartContent {
        ForEach(trainings, id: \.id) { t in
            RectangleMark(
                xStart: .value("Start", Date(timeIntervalSince1970: t.startTime)),
                xEnd:   .value("End",   Date(timeIntervalSince1970: t.endTime)),
                yStart: .value("Min", 0),
                yEnd:   .value("Max", yMax)
            )
            .foregroundStyle(TrainingPalette.color(for: t.type).opacity(0.20))
            .zIndex(-1)
        }
    }

    // glucose curve
    var glucoseLine: some ChartContent {
        ForEach(glucoseData, id: \.id) { g in
            LineMark(
                x: .value("Time", Date(timeIntervalSince1970: g.timestamp)),
                y: .value("Glucose", g.glucoseValue)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(.red)
        }
    }

    // heart‑rate dots
    @ChartContentBuilder
    func hrPoints(inWorkout: Bool) -> some ChartContent {
        ForEach(hrDailyPoints.filter { $0.inWorkout == inWorkout }) { p in
            PointMark(
                x: .value("Time", p.time),
                y: .value("Heart Rate", Double(p.bpm))
            )
            .symbolSize(inWorkout ? 32 : 22)
            .foregroundStyle(inWorkout ? .blue : .gray.opacity(0.45))
        }
    }
}

// MARK: – Overlay & gestures
private extension GlucoseHeartRateChartView {

    @ViewBuilder
    func proxyOverlay(_ proxy: ChartProxy) -> some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { plotWidth = proxy.plotAreaSize.width }
                .onChange(of: proxy.plotAreaSize) { new, _ in plotWidth = new.width }

                .contentShape(Rectangle())
                // tap → clear tooltip
                .simultaneousGesture(
                    TapGesture().onEnded { _ in clearTooltip() }
                )
                // drag → tooltip + pan
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            updateTooltip(at: g.location, proxy: proxy)

                            let secPerPt = dayInterval / Double(plotWidth)
                            offset -= Double(g.translation.width) * secPerPt * panDamping
                            offset = offset.clamped(to: -dayInterval/2 ... dayInterval/2)
                        }
                )
        }
        // pinch‑zoom (separate gesture)
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    let ratio = value / lastGesture
                    lastGesture = value
                    let amp    = pow(ratio, zoomAmplifier)
                    scale = (scale * amp).clamped(to: maxZoom)
                }
                .onEnded { _ in lastGesture = 1 }
        )
        .overlay(alignment: .topLeading) { tooltip }
    }

    // tooltip view
    var tooltip: some View {
        Group {
            if let t = selectedTime {
                VStack(alignment: .leading, spacing: 4) {
                    if let g = nearestGlucoseVal {
                        Text("Glucose: \(g.value, specifier: "%.1f") mg/dL")
                    }
                    if let h = nearestHRVal {
                        Text("Pulse: \(Int(h.value)) bpm")
                    }
                    Text("Time: \(timeFmt.string(from: t))")
                }
                .font(.caption)
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 2)
                .padding(.leading, 60)
            }
        }
    }

    // tooltip helpers
    func updateTooltip(at loc: CGPoint, proxy: ChartProxy) {
        guard let d: Date = proxy.value(atX: loc.x) else { return }
        selectedTime = d

        if let g = glucoseData.min(by: { abs($0.timestamp - d.timeIntervalSince1970) <
                                         abs($1.timestamp - d.timeIntervalSince1970) }) {
            nearestGlucoseVal = (Date(timeIntervalSince1970: g.timestamp), g.glucoseValue)
        }
        if let h = heartRateData.min(by: { abs($0.timestamp - d.timeIntervalSince1970) <
                                           abs($1.timestamp - d.timeIntervalSince1970) }) {
            nearestHRVal = (Date(timeIntervalSince1970: h.timestamp), Double(h.heartRate))
        }
    }
    func clearTooltip() {
        selectedTime = nil
        nearestGlucoseVal = nil
        nearestHRVal = nil
    }
}

// MARK: – Legend & misc
private extension GlucoseHeartRateChartView {

    var legend: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                legendDot(.red,  "Glucose")
                legendDot(.blue, "Heart Rate")
            }
            let todayTypes = Array(Set(trainings.map(\.type.cleaned))).sorted()
            if !todayTypes.isEmpty {
                HStack(spacing: 16) {
                    ForEach(todayTypes, id: \.self) { t in
                        legendDot(TrainingPalette.color(for: t), t)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text).font(.footnote)
        }
    }

    var timeFmt: DateFormatter {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
private extension String {
    var cleaned: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
