import SwiftUI

/// Главный «дневной» экран: простые метрики + AI-анализ.
public struct DailyCoachScreen: View {
    @StateObject private var vm = DailyCoachViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // 1️⃣ — Основная оценка дня
                    TodayScoreCard(vm: vm)
                    
                    // 2️⃣ — Ежедневные цели
                    SectionCard(title: "Daily targets") {
                        HStack(spacing: 12) {
                            MetricTile(title: "Steps",
                                       value: "\(vm.metrics.steps)",
                                       footer: vm.metrics.stepsTargetString)
                            MetricTile(title: "Protein",
                                       value: "\(vm.metrics.proteinG) g",
                                       footer: vm.metrics.proteinTargetString)
                        }
                    }
                    
                    // 3️⃣ — Энергия и пульс
                    SectionCard(title: "Vitals & Energy") {
                        HStack(spacing: 12) {
                            MetricTile(title: "HRmax",
                                       value: "\(vm.metrics.hrMax)bpm",
                                       footer: "zones tuned")
                            MetricTile(title: "kcal (today)",
                                       value: "\(Int(vm.metrics.kcal.rounded()))",
                                       footer: "from workouts")
                            MetricTile(title: "Glucose",
                                       value: vm.metrics.glucoseFlag ?? "—",
                                       footer: "trend")
                        }
                    }
                    
                    // 4️⃣ — Рекомендации AI
                    SectionCard(title: "Coach AI") {
                        if vm.aiBusy {
                            ProgressView("Analyzing…")
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                if !vm.aiSummary.isEmpty {
                                    Text(vm.aiSummary)
                                        .font(.body)
                                } else {
                                    Text("Tap **Analyze** to get a short plan for today.")
                                        .foregroundStyle(.secondary)
                                }
                                HStack(spacing: 8) {
                                    Pill(text: vm.metrics.coachTag1)
                                    Pill(text: vm.metrics.coachTag2)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .refreshable {
                    await vm.load()
                }
                .navigationTitle("🧭 Today")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await vm.runAI() }
                        } label: {
                            Label("Analyze", systemImage: "sparkles")
                        }
                        .disabled(vm.aiBusy)
                    }
                }
                .task { await vm.load() }
            }
        }
    }
}
