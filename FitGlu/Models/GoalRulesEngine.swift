import Foundation

struct CoachRuleOutput: Equatable {
    var diagnosis: String
    var rest: [String]      // 2 пункта
    var load: String        // 1 пункт
    var warning: String     // 1 пункт
    var tags: [String]      // pills
}

enum GoalRulesEngine {
    struct Thresholds {
        var readinessGate: Int = 70
        var recoveryGate: Double = 0.7
        var sleepGateMin: Int = 390 // 6.5h
        var rhrDeltaWarn: Int = 7

        var hiitHighZonePctMax: Int = 30
        var restToleranceSec: Int = 30
    }

    static func build(
        goal: TrainingGoal,
        metrics m: DailyCoachMetrics,
        thresholds t: Thresholds = .init()
    ) -> CoachRuleOutput {

        let readiness = m.readiness
        let sleepMin = m.sleepMin
        let recoveryProgress = m.recoveryProgress ?? 1.0
        let proteinOk = m.proteinG >= m.proteinTarget
        let rhrDelta: Int = {
            guard let rhr = m.restingHR, let base = m.baselineHR, base > 0 else { return 0 }
            return max(0, rhr - base)
        }()

        func baseOutput(
            diagnosis: String,
            rest1: String,
            rest2: String,
            load: String,
            warning: String,
            tags: [String]
        ) -> CoachRuleOutput {
            .init(diagnosis: diagnosis, rest: [rest1, rest2], load: load, warning: warning, tags: tags)
        }

        switch goal {
        case .maintain:
            if readiness < t.readinessGate || recoveryProgress < t.recoveryGate || sleepMin < t.sleepGateMin {
                return baseOutput(
                    diagnosis: "Недовосстановление.",
                    rest1: "Сон: добери до 7–8ч.",
                    rest2: proteinOk ? "Отдых: лёгкая прогулка 20–40 мин." : "Белок: добей до цели сегодня.",
                    load: "Интенсивность: НЕ повышать.",
                    warning: rhrDelta >= t.rhrDeltaWarn ? "RHR выше нормы — лучше отдых." : "Если завтра RHR выше нормы — отдых.",
                    tags: ["Maintain", "Recover"]
                )
            } else {
                return baseOutput(
                    diagnosis: "Готов тренироваться.",
                    rest1: "Сон: держи 7–8ч.",
                    rest2: "Отдых между тренировками: по окну восстановления.",
                    load: "Нагрузка: по плану, без форсажа.",
                    warning: "Не добивайся ценой техники.",
                    tags: ["Maintain", "Train"]
                )
            }

        case .fatLoss:
            let hiitPct = m.hiitTimeInHighZonePct
            let hasHIIT = (m.hiitDurationMin ?? 0) > 0

            if sleepMin < t.sleepGateMin || recoveryProgress < t.recoveryGate {
                return baseOutput(
                    diagnosis: "Стресс/восстановление ниже порога.",
                    rest1: "Сегодня без HIIT.",
                    rest2: "Зона 2/ходьба 30–60 мин.",
                    load: "Силовую — умеренно, без добивания.",
                    warning: "HIIT на недосыпе = высокий стресс.",
                    tags: ["Fat loss", "No HIIT"]
                )
            }

            if hasHIIT, let pct = hiitPct, pct > t.hiitHighZonePctMax {
                return baseOutput(
                    diagnosis: "HIIT перегрет (слишком много high-zone).",
                    rest1: "Уменьши high-zone: цель ≤ \(t.hiitHighZonePctMax)%.",
                    rest2: "Добавь восстановление: 5–10 мин заминки.",
                    load: "Следующий HIIT — короче/мягче.",
                    warning: rhrDelta >= t.rhrDeltaWarn ? "RHR выше нормы — снижай стресс." : "Переизбыток high-zone мешает восстановлению.",
                    tags: ["Fat loss", "HIIT ↓"]
                )
            }

            return baseOutput(
                diagnosis: "Нагрузка ок для fat loss.",
                rest1: "Держи умеренную интенсивность чаще.",
                rest2: proteinOk ? "Белок ок — так держать." : "Белок ↑ до цели.",
                load: "HIIT — дозировано; приоритет устойчивой работе.",
                warning: rhrDelta >= t.rhrDeltaWarn ? "RHR выше нормы — снижай стресс." : "Не гонись за пиком HR каждый раз.",
                tags: ["Fat loss", "Steady"]
            )

        case .muscleGain:
            let hasStrength = (m.strengthDurationMin ?? 0) > 0
            let rec = m.restRecommendedSec
            let med = m.strengthRestMedianSec
            let drift = m.strengthDriftBpm
            let eff = m.strengthEfficiencyScore

            if sleepMin < t.sleepGateMin || !proteinOk {
                return baseOutput(
                    diagnosis: "Ресурсы под рост мышц слабые (сон/белок).",
                    rest1: "Сон: цель 7–8ч.",
                    rest2: "Белок: добей до \(m.proteinTarget)g.",
                    load: "Силовая: умеренно, без отказов.",
                    warning: "Рост мышц без восстановления = хуже прогресс.",
                    tags: ["Muscle", "Recover"]
                )
            }

            if hasStrength, let rec, let med, abs(med - rec) > t.restToleranceSec {
                return baseOutput(
                    diagnosis: "Отдых пляшет — качество падает.",
                    rest1: "Цель отдыха: \(rec)с (±\(t.restToleranceSec)с).",
                    rest2: "Убери лишние supersets/сократи плотность.",
                    load: "Силовая: держи технику и контроль.",
                    warning: "Хаотичный отдых = меньше рабочих повторов.",
                    tags: ["Muscle", "Rest discipline"]
                )
            }

            if (drift ?? 0) > 15 || (eff ?? 100) < 60 {
                return baseOutput(
                    diagnosis: "Признаки усталости (drift/efficiency).",
                    rest1: "Увеличь отдых на 15–30с на тяжёлых сетах.",
                    rest2: "Снизь объём на 10–20% сегодня.",
                    load: "Следи за качеством подходов.",
                    warning: "Добивание при drift = хуже стимул.",
                    tags: ["Muscle", "Fatigue"]
                )
            }

            return baseOutput(
                diagnosis: "Хороший день для силовой прогрессии.",
                rest1: "Держи отдых близко к recommended.",
                rest2: "Сохраняй стабильный темп по сетам.",
                load: "Нагрузка: 1 ключевое упражнение — прогресс.",
                warning: "Не добавляй HIIT, если он мешает силовой.",
                tags: ["Muscle", "Train"]
            )
        }
    }
}
