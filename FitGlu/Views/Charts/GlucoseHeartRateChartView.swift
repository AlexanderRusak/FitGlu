import SwiftUI
import HealthKit
import Charts

struct GlucoseHeartRateChartView: View {

    // MARK: - Constants (подтягиваем из Utils/Constants, чтобы не «засорять» View)
    private let cfg = ChartConfig.default

    // MARK: - In-data
    let glucose             : [GlucoseRow]
    let heartRateRaw        : [HeartRateLogRow]
    let hrDailyPoints       : [HRPoint]
    let trainings           : [TrainingRow]
    let dayDomain           : ClosedRange<Date>
    let userAge: Int?
    let userSex: HKBiologicalSex?

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
                if let age = userAge {
                    ChartHRZones(
                        zones: HRZoneProvider.ranges(for: age, sex: userSex),
                        xDomain: domain
                    )
                }
                TrainingBackground(trainings: trainings, yMax: yMax)
                GlucoseSeries(data: glucose)
                HeartRateSeries(data: hrDailyPoints,
                                showAsLine: showHRLine)
            }
            .denseAxes(
                majorX: .hour, majorXStep: 1,
                minorX: .minute, minorXStep: 10,
                yStep: 5
            )
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
