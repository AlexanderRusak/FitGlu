import SwiftUI
import Charts

struct DetailsScreen: View {

    // MARK: UI‑state
    @State private var selectedDate = Date()
    @State private var showPicker   = false

    // MARK: ViewModel
    @StateObject private var vm = DetailsViewModel()

    var body: some View {
        VStack(spacing: 0) {

            DateHeaderView(date: $selectedDate,
                           showPicker: $showPicker)

            Divider()

            VStack(alignment: .leading) {
                Text("📊 Glucose & Heart Rate — \(selectedDate.formatted(.dateTime.day().month().year()))")
                    .font(.title2.bold())
                    .padding(.horizontal)

                if vm.trainings.isEmpty {
                    Text("No training on this day.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    GlucoseHeartRateChartView(
                        glucoseData:   vm.glucose,
                        heartRateData: vm.heartRates,
                        hrDailyPoints: vm.hrDailyPoints,
                        trainings:     vm.trainings,
                        domain:        selectedDate.startOfDay ... selectedDate.endOfDay
                    )
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 4)
        }
        .task(id: selectedDate) { await vm.load(for: selectedDate) }
    }
}
