import SwiftUI

/// Главный «дневной» экран: простые метрики + AI-анализ.
public struct DailyCoachScreen: View {
    @StateObject private var vm = DailyCoachViewModel()
    @EnvironmentObject private var settings: AppSettingsStore
    
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
                    SectionCard(title: "Strength (MVP)") {
                        if vm.metrics.strengthDurationMin == nil {
                            Text("No strength workout on this day.")
                                .foregroundStyle(.secondary)
                        } else if vm.metrics.strengthHasEnoughHR == false {
                            Text("Not enough HR data inside workout window.")
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    MetricTile(title: "Efficiency",
                                               value: "\(vm.metrics.strengthEfficiencyScore ?? 0)/100",
                                               footer: vm.metrics.strengthWeakSpot ?? "—")
                                    MetricTile(title: "Duration",
                                               value: "\(vm.metrics.strengthDurationMin ?? 0) min",
                                               footer: "workout")
                                }
                                HStack(spacing: 12) {
                                    MetricTile(title: "Avg / Max HR",
                                               value: "\(vm.metrics.strengthAvgHR ?? 0) / \(vm.metrics.strengthMaxHR ?? 0)",
                                               footer: "bpm")
                                    MetricTile(title: "Waves",
                                               value: "\(vm.metrics.strengthWaveCount ?? 0)",
                                               footer: "load peaks")
                                }
                                HStack(spacing: 12) {
                                    MetricTile(
                                      title: "Rest (med / p90)",
                                      value: "\(formatSec(vm.metrics.strengthRestMedianSec)) / \(formatSec(vm.metrics.strengthRestP90Sec))",
                                      footer: "between sets"
                                    )

                                    MetricTile(
                                      title: "Rest rec",
                                      value: formatSec(vm.metrics.restRecommendedSec),
                                      footer: "target"
                                    )
                                }
                                HStack(spacing: 12) {
                                    MetricTile(title: "Recovery drop",
                                               value: "\(vm.metrics.strengthRecoveryDropMedianBpm ?? 0) bpm",
                                               footer: "after peaks")
                                    MetricTile(title: "Discipline",
                                               value: "\(vm.metrics.restDisciplineScore ?? 0)/100",
                                               footer: "rest stability")
                                }
                            }
                        }
                    }
                    
                    // HIIT summary
                    SectionCard(title: "HIIT (MVP)") {
                        // 1) Нет HIIT тренировки в этот день
                        if vm.metrics.hiitDurationMin == nil {
                            Text("No HIIT workout on this day.")
                                .foregroundStyle(.secondary)

                        // 2) HIIT есть, но HR данных недостаточно
                        } else if vm.metrics.hiitHasEnoughHR == false {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Not enough HR data inside HIIT window.")
                                    .foregroundStyle(.secondary)

                                // Покажем хоть что-то базовое, если успело посчитаться
                                HStack(spacing: 12) {
                                    MetricTile(
                                        title: "Duration",
                                        value: "\(vm.metrics.hiitDurationMin ?? 0) min",
                                        footer: "workout"
                                    )
                                    MetricTile(
                                        title: "Avg / Max HR",
                                        value: "\(vm.metrics.hiitAvgHR ?? 0) / \(vm.metrics.hiitMaxHR ?? 0)",
                                        footer: "bpm"
                                    )
                                }
                            }

                        // 3) Всё ок — рисуем KPI
                        } else {
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    MetricTile(
                                        title: "Quality",
                                        value: "\(vm.metrics.hiitQualityScore ?? 0)/100",
                                        footer: vm.metrics.hiitWeakSpot ?? "—"
                                    )
                                    MetricTile(
                                        title: "Duration",
                                        value: "\(vm.metrics.hiitDurationMin ?? 0) min",
                                        footer: "workout"
                                    )
                                }

                                HStack(spacing: 12) {
                                    MetricTile(
                                        title: "Avg / Max HR",
                                        value: "\(vm.metrics.hiitAvgHR ?? 0) / \(vm.metrics.hiitMaxHR ?? 0)",
                                        footer: "bpm"
                                    )
                                    MetricTile(
                                        title: "Intervals",
                                        value: "\(vm.metrics.hiitIntervalCount ?? 0)",
                                        footer: "work/rest cycles"
                                    )
                                }

                                HStack(spacing: 12) {
                                    MetricTile(
                                        title: "High zone",
                                        value: "\(vm.metrics.hiitTimeInHighZonePct ?? 0)%",
                                        footer: "\(DailyCoachMetrics.formatMMSS(vm.metrics.hiitTimeInHighZoneSec))"
                                    )
                                    MetricTile(
                                        title: "Work / Rest (med)",
                                        value: "\(DailyCoachMetrics.formatMMSS(vm.metrics.hiitWorkMedianSec)) / \(DailyCoachMetrics.formatMMSS(vm.metrics.hiitRestMedianSec))",
                                        footer: "median"
                                    )
                                }

                                HStack(spacing: 12) {
                                    MetricTile(
                                        title: "Thresholds",
                                        value: "\(vm.metrics.hiitLowThresholdBpm ?? 0)–\(vm.metrics.hiitHighThresholdBpm ?? 0)",
                                        footer: "low–high bpm"
                                    )
                                    MetricTile(
                                        title: "Recovery slope",
                                        value: "\(vm.metrics.hiitRecoverySlopeBpmPerMin ?? 0)",
                                        footer: "bpm/min"
                                    )
                                }
                            }
                        }
                    }


                    // Diary summary
                    SectionCard(title: "Diary") {
                        HStack(spacing: 12) {
                            MetricTile(title: "Sets",
                                       value: "\(vm.metrics.diaryTotalSets ?? 0)",
                                       footer: "total")
                            MetricTile(title: "Exercises",
                                       value: "\(vm.metrics.diaryExercisesCount ?? 0)",
                                       footer: "unique")
                            MetricTile(title: "Superset",
                                       value: "\(vm.metrics.diarySupersetExercisesCount ?? 0)",
                                       footer: "exercises")
                        }

                        if let ton = vm.metrics.diaryApproxTonnage {
                            Text("Approx tonnage: \(ton)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let top = vm.metrics.diaryTopExercises, !top.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Top exercises:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ForEach(top, id: \.self) { line in
                                    Text("• \(line)").font(.caption)
                                }
                            }
                        }
                    }

                    
                    // 4️⃣ — Goal rules (MVP)
                    let output = GoalRulesEngine.build(goal: settings.goal, metrics: vm.metrics)
                    SectionCard(title: "Goal: \(settings.goal.title)") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1) \(output.diagnosis)")
                            Text("2) Отдых:")
                            Text("• \(output.rest[0])")
                            Text("• \(output.rest[1])")
                            Text("3) Нагрузка: \(output.load)")
                            Text("4) Предупреждение: \(output.warning)")
                            if !output.tags.isEmpty {
                                HStack(spacing: 8) {
                                    ForEach(output.tags, id: \.self) { Pill(text: $0) }
                                }
                            }
                        }
                    }

                    // 5️⃣ — Рекомендации AI
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
                            let output = GoalRulesEngine.build(goal: settings.goal, metrics: vm.metrics)
                            Task { await vm.runAI(goal: settings.goal, rules: output) }
                        } label: {
                            Label("Analyze", systemImage: "sparkles")
                        }
                        .disabled(vm.aiBusy)
                    }
                }
                .task {
                    let debugDate = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 27))!
                    await vm.load(for: debugDate)
                }
                .refreshable {
                    let debugDate = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 27))!
                    await vm.load(for: debugDate)
                }
                //.task { await vm.load() } Uncomment
            }
        }
    }
    
    
    private func formatSec(_ sec: Int?) -> String {
        guard let sec, sec > 0 else { return "—" }
        let m = sec / 60
        let s = sec % 60
        return String(format: "%d:%02d", m, s)
    }
}
