import SwiftUI

struct ContentView: View {
    @State private var trainingData: (training: TrainingRow?, heartRates: [HeartRateLogRow], glucoseValues: [GlucoseRow])?
    @State private var selectedTrainingID: Int64 = 1

    var body: some View {
        VStack(spacing: 20) {
            Text("Training, Heart Rates & Glucose")
                .font(.title2)
                .bold()

            HStack {
                Text("Training ID:")
                TextField("Enter ID", value: $selectedTrainingID, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
            }

            Button("Load Data") {
                let trainingRes = TrainingLogDBManager.shared.getTrainingWithHeartRates(trainingID: selectedTrainingID)
                let glucose = GlucoseLogDBManager.shared.getGlucoseInRange(start: trainingRes.training?.startTime ?? 0, end: trainingRes.training?.endTime ?? Date().timeIntervalSince1970)

                trainingData = (
                    training: trainingRes.training,
                    heartRates: trainingRes.heartRates,
                    glucoseValues: glucose
                )
            }
            .buttonStyle(.borderedProminent)

            Button("Show All Glucose") {
                let allGlucose = GlucoseLogDBManager.shared.getAllGlucose()
                print("=== ALL GLUCOSE LOGS ===")
                for g in allGlucose {
                    print("🩸 ID=\(g.id), Value=\(g.glucoseValue), Time=\(formatDate(g.timestamp))")
                }
                print("========================")
            }
            .buttonStyle(.bordered)
            .foregroundColor(.blue)

            if let wData = trainingData {
                if let t = wData.training {
                    VStack(alignment: .leading) {
                        Text("🏋️ Training ID: \(t.id)")
                            .font(.headline)
                        Text("🔥 Type: \(t.type)")
                        Text("🕒 Start: \(formatDate(t.startTime))")
                        Text("🕒 End: \(formatDate(t.endTime))")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                } else {
                    Text("No training found.").foregroundColor(.red)
                }

                if !wData.heartRates.isEmpty {
                    Text("Heart Rates:")
                        .font(.subheadline)
                    List(wData.heartRates, id: \.id) { hr in
                        VStack(alignment: .leading) {
                            Text("💓 \(hr.heartRate) BPM")
                            Text("Time: \(formatDate(hr.timestamp))")
                                .foregroundColor(.gray)
                                .font(.footnote)
                        }
                    }
                } else {
                    Text("No heart rate data.").foregroundColor(.red)
                }

                if !wData.glucoseValues.isEmpty {
                    Text("Glucose:")
                        .font(.subheadline)
                    List(wData.glucoseValues, id: \.id) { g in
                        VStack(alignment: .leading) {
                            Text("🩸 \(g.glucoseValue, specifier: "%.1f") mg/dL")
                            Text("Time: \(formatDate(g.timestamp))")
                                .foregroundColor(.gray)
                                .font(.footnote)
                        }
                    }
                } else {
                    Text("No glucose data.").foregroundColor(.red)
                }
            }
        }
        .padding()
    }

    private func formatDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
}
