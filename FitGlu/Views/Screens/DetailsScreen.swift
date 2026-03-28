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
                        glucose:        vm.glucose,
                        heartRateRaw:   vm.heartRates,       // если нужно
                        hrSegments:     vm.hrSegments,       // ← новое
                        trainings:      vm.trainings,
                        dayDomain:      selectedDate.startOfDay ... selectedDate.endOfDay,
                        userAge:        vm.userAge,
                        userSex:        vm.userSex
                    )
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 4)
        }
        .task(id: selectedDate) { await vm.load(for: selectedDate) }
    }
}
