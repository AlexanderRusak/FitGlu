import SwiftUI
import HealthKit
import Charts

struct GlucoseHeartRateChartView: View {

    // MARK: - Constants (подтягиваем из Utils/Constants, чтобы не «засорять» View)
    private let cfg = ChartConfig.default

    // MARK: - In-data
    let glucose      : [GlucoseRow]
        let heartRateRaw : [HeartRateLogRow]   // остаётся — нужен для yMax
        let hrSegments   : [[HRPoint]]         // ← наши куски без дыр
        let trainings    : [TrainingRow]
        let dayDomain    : ClosedRange<Date>
        let userAge      : Int?
        let userSex      : HKBiologicalSex?
    
    // MARK: - Local state (минимум: только то, что нужно здесь)
    @State private var scale:  CGFloat = 1
    @State private var offset: TimeInterval = 0
    @State private var showHRLine = false

    // MARK: - Calculated
    private var yMax: Double {
        max(glucose.map(\.glucoseValue).max() ?? 10,
            Double(heartRateRaw.map(\.heartRate).max() ?? 120)) * 1.2
    }
    private var domain: ClosedRange<Date> {
        let half   = dayDomain.seconds / (2 * Double(scale))
        let center = dayDomain.lowerBound + dayDomain.seconds/2 + offset
        return (center - half) ... (center + half)
    }

    var body: some View {
        VStack(spacing: 6) {

            Text("Left Axis: Glucose (mg/dL) · Heart Rate (bpm)")
                .font(.subheadline).foregroundColor(.gray)

            Chart {
                // 0) пульсовые зоны (их можно оставить на левой оси – они
                //    просто фон, поэтому .yAxis(.left) не нужен)
                if let age = userAge {
                    ChartHRZones(zones: HRZoneProvider.ranges(for: age, sex: userSex),
                                 xDomain: domain)
                }

                // 1) фон (тренировки)
                TrainingBackground(trainings: trainings, yMax: yMax)

                // 2) глюкоза
                GlucoseSeries(data: glucose)

                // 3) пульс
                HeartRateSeries(segments: hrSegments,
                                        asLine: showHRLine,
                                        useRightY: showHRLine)
            }
            .chartYAxis {
                // ─── левая (глюкоза) ─────────────────────────────
                AxisMarks(position: .leading, values: .automatic) { value in
                    AxisGridLine()
                    AxisTick()

                    if let d = value.as(Double.self) {
                        AxisValueLabel {                // 👈 label lives inside
                            Text("\(Int(d))")           // mg/dL
                        }
                    }
                }

                // ─── правая (пульс) ──────────────────────────────
                AxisMarks(position: .trailing, values: .automatic) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [4, 4]))
                        .foregroundStyle(.blue.opacity(0.25))
                    AxisTick()

                    if let d = value.as(Double.self) {
                        AxisValueLabel {
                            Text("\(Int(d))")           // bpm
                        }
                    }
                }
            }
            .chartXScale(domain: domain)
            .chartYScale(domain: 0...yMax)
            .chartOverlay { proxy in
                ChartGestures(proxy: proxy,
                              dayDomain: dayDomain,
                              scale: $scale,
                              offset: $offset)
            }
            .frame(maxWidth: .infinity)
            .border(.gray.opacity(0.3))


            ChartLegend(trainings: trainings,
                        showHRLine: $showHRLine)
                .padding(.horizontal)
        }
        .padding(.horizontal)
    }
}
