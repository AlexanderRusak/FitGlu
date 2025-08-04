import SwiftUI

struct ActivityScreen: View {
    @State private var selectedDate = Date()
    @State private var showPicker    = false
    @State private var showHRLine = false
    @StateObject private var detailsVM = DetailsViewModel()
    @StateObject private var chartVM   = ActivityChartViewModel()

    var body: some View {
        VStack(spacing: 12) {
            // MARK: — Header + date picker
            HStack {
                Text(selectedDate, format: .dateTime.day().month().year())
                    .font(.headline)
                Spacer()
                Button { showPicker.toggle() } label: {
                    Image(systemName: "calendar").font(.title2)
                }
            }
            if showPicker {
                DatePicker("Выберите дату", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .onChange(of: selectedDate) { _, _ in Task { await loadData() } }
            }
            Divider()
            if detailsVM.hrDailyPoints.isEmpty {
                Text("Нет данных за выбранную дату")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                ActivityChartFullView(vm: chartVM)
                    .frame(height: 320)
                ActivityChartLegend(trainings: detailsVM.trainings, hasGlucose: !chartVM.glucosePoints.isEmpty)
                    .padding(.horizontal)
            }
        }
        .padding()
        .navigationTitle("Activity")
        .task(id: selectedDate) { await loadData() }
    }

    @MainActor
    private func loadData() async {
        await detailsVM.load(for: selectedDate)
        await chartVM.configure(from: detailsVM)
    }
}
