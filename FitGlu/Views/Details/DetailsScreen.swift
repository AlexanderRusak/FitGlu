import SwiftUI
import Charts

struct DetailsScreen: View {
    @State private var selectedDate = Date()

    private var startOfDay: Date {
        selectedDate.startOfDay
    }

    private var endOfDay: Date {
        selectedDate.endOfDay
    }

    private var trainings: [TrainingRow] {
        TrainingLogDBManager.shared
            .getAllTrainings()
            .filter {
                let start = Date(timeIntervalSince1970: $0.startTime)
                return start >= startOfDay && start < endOfDay
            }
    }

    private var glucoseData: [GlucoseRow] {
        GlucoseLogDBManager.shared
            .getAllGlucose()
            .filter {
                let date = Date(timeIntervalSince1970: $0.timestamp)
                return date >= startOfDay && date < endOfDay
            }
    }

    private var heartRateData: [HeartRateLogRow] {
        trainings.flatMap {
            HeartRateLogDBManager.shared.getHeartRates(for: $0.id)
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("📊 Glucose & Heart Rate — \(formattedDate(selectedDate))")
                .font(.title2)
                .bold()
                .padding(.horizontal)

            if let training = trainings.first {
                GlucoseHeartRateChartView(
                    glucoseData: glucoseData,
                    heartRateData: heartRateData,
                    training: training // <-- правильно
                )
            } else {
                Text("No training on this day.")
                    .foregroundColor(.gray)
                    .padding()
            }

            Spacer()
        }
        .padding(.top)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("dd MMM yyyy")
        return formatter.string(from: date)
    }
}

#Preview {
    DetailsScreen()
}
