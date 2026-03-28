import SwiftUI

/// Информационный экран для метрики “Intensity & Peaks”.
struct INTInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    IntroCard()

                    SectionHeader("What you see")
                    VStack(spacing: 10) {
                        InfoRow(
                            title: "Peak HR, % of max",
                            text: "Highest heart rate reached during today’s workouts relative to your HRmax."
                        )
                        InfoRow(
                            title: "Time ≥90% HRmax",
                            text: "How long you spent at or above 90% of HRmax — a proxy for anaerobic/high-intensity work."
                        )
                        InfoRow(
                            title: "Red zone (Z5)",
                            text: "Whether you touched the red zone long enough to matter (continuous hold ≥ configured threshold, default 20 s)."
                        )
                        InfoRow(
                            title: "HR-RPE (0–10)",
                            text: "Effort index from HR reserve: (avgHR − HRrest) / (HRmax − HRrest) × 10, clamped to 0…10."
                        )
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

                    SectionHeader("How we calculate")
                    VStack(alignment: .leading, spacing: 8) {
                        Bullet("HRmax: from your personal zones (Z5 upper bound). If not available, fallback is 220 − age.")
                        Bullet("HRrest: estimated from your day’s HR points as the 5th percentile (more stable than absolute minimum).")
                        Bullet("Peak HR%: max(HR) / HRmax × 100.")
                        Bullet("≥90% time: sum of intervals where HR ≥ 0.9 × HRmax while inside workout periods.")
                        Bullet("Red flag: continuous time in Z5 (HR ≥ Z5 lower bound) ≥ 20 s (configurable in code).")
                        Bullet("HR-RPE10: round( ((avgHR − HRrest) / (HRmax − HRrest)) × 10 ).")
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

                    SectionHeader("Good to know")
                    VStack(alignment: .leading, spacing: 8) {
                        Bullet("Chest straps measure more reliably than wrist optical sensors — peaks and short bursts become cleaner.")
                        Bullet("Warm-up / cool-down affect avgHR and HR-RPE but do not inflate peak or ≥90% time.")
                        Bullet("Gaps or noisy HR can under/overestimate ≥90% time; we integrate only inside workout windows.")
                        Bullet("If you see unrealistic HRmax/HRrest, revise zones or rest estimate — the indices will align better.")
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

                    FooterNote("Tip: for HIIT, track both ≥90% time and Red flag. For endurance base, HR-RPE around 3–5 is typical.")
                }
                .padding()
            }
            .navigationTitle("Intensity & Peaks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Subviews

private struct IntroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Intensity & Peaks")
                .font(.title3).bold()
            Text("A quick look at how hard you pushed today: the highest HR peak, time spent near maximum, a red-zone flag, and a simple HR-based RPE (0–10).")
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.top, 4)
    }
}

private struct InfoRow: View {
    let title: String
    let text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline).bold()
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct Bullet: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().frame(width: 6, height: 6).foregroundStyle(.secondary).padding(.top, 6)
            Text(text).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
}

private struct FooterNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }
}

// MARK: - Preview

#Preview {
    INTInfoSheet()
        .preferredColorScheme(.dark)
}
