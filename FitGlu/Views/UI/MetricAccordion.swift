import SwiftUI

private enum CardMetrics {
    static let insets  = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16) // = как в TrainingQualityCard
    static let chevron = 12.0   // ширина иконки chevron (≈12pt)
    static let spacing = 12.0   // расстояние между chevron и заголовком
    static let lineGap = 6.0    // вертикальный зазор между строками
    static let barH    = 12.0   // высота полосы, как на карточке
}

// MARK: - Environment key to control initial state
private struct InitialExpandedKey: EnvironmentKey {
    static let defaultValue: Bool = true
}
extension EnvironmentValues {
    /// Передайте `.environment(\.initialExpanded, false)` чтобы стартовать свёрнутым.
    var initialExpanded: Bool {
        get { self[InitialExpandedKey.self] }
        set { self[InitialExpandedKey.self] = newValue }
    }
}

// MARK: - Generic collapsible block (с прогресс-баром в свёрнутом виде)
struct MetricAccordion<Summary: View, CollapsedBar: View, Content: View>: View {

    // API
    let title: String
    /// `showChips == false` → вывели "46 / 100" + капсулу; `true` → вывели чипы зон
    let summary: (_ showChips: Bool) -> Summary
    /// Компактная полоса (как на карточке). Рисуется только когда блок свёрнут.
    let collapsedBar: () -> CollapsedBar
    let content: () -> Content
    let onInfoTap: (() -> Void)?

    // State / Env
    @Environment(\.initialExpanded) private var initialExpanded
    @State private var expanded = true

    var body: some View {
        VStack(spacing: 0) {
            header
            if expanded {
                Divider().opacity(0.25)
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.top, 12)
            }
        }
        .onAppear { expanded = initialExpanded }
        .animation(.easeInOut, value: expanded)
        .padding(.vertical, 4)
    }

    // MARK: - Header
    private var header: some View {
        Button {
            withAnimation { expanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: CardMetrics.lineGap) {

                // ─ 1-я строка: chevron • title • summary ─
                HStack(spacing: CardMetrics.spacing) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: CardMetrics.chevron, alignment: .center)

                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                        .layoutPriority(10)

                    Spacer(minLength: 4)
                    summary(false).fixedSize()
                }

                // ─ 2-я строка (только в свёрнутом виде):
                //     полоса прогресса + чипы, выровнены под начало Title
                if !expanded {
                    VStack(alignment: .leading, spacing: 6) {
                        collapsedBar()
                            .frame(height: CardMetrics.barH)

                        summary(true)        // чипы суммарного времени
                    }
                    .padding(.leading, CardMetrics.chevron + CardMetrics.spacing)
                }
            }
            // ВНУТРЕННИЕ отступы карточки — те же, что у TrainingQualityCard
            .padding(CardMetrics.insets)
            // Фон карточки рисуем только в свёрнутом состоянии
            .background(
                !expanded
                ? AnyView(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
                : AnyView(EmptyView())
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)   // внешний зазор между карточками на списке
    }
}
