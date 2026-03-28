import SwiftUI

private enum CardMetrics {
    static let insets  = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
    static let chevron = 12.0
    static let spacing = 12.0        // между chevron и заголовком
    static let infoGap = 0.0         // между заголовком и иконкой i
    static let lineGap = 6.0
    static let barH    = 12.0
}

// MARK: - Environment key to control initial state
private struct InitialExpandedKey: EnvironmentKey { static let defaultValue: Bool = true }
extension EnvironmentValues {
    var initialExpanded: Bool {
        get { self[InitialExpandedKey.self] }
        set { self[InitialExpandedKey.self] = newValue }
    }
}

// MARK: - Generic collapsible block
struct MetricAccordion<Summary: View, CollapsedBar: View, Content: View>: View {

    let title: String
    /// showChips == false → правая сводка (например "46 / 100" + бейдж), true → чипы
    let summary: (_ showChips: Bool) -> Summary
    /// Полоса — показывается только в свёрнутом виде.
    let collapsedBar: () -> CollapsedBar
    let content: () -> Content
    let onInfoTap: (() -> Void)?

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

    // MARK: Header
    private var header: some View {
        VStack(alignment: .leading, spacing: CardMetrics.lineGap) {

            // chevron • title • (i) • … • summary
            HStack(spacing: CardMetrics.spacing) {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: CardMetrics.chevron, alignment: .center)

                // Заголовок
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .layoutPriority(10)
                    .onTapGesture { withAnimation { expanded.toggle() } } // тап по названию тоже разворачивает

                // Иконка i СРАЗУ ПОСЛЕ заголовка
                if let onInfoTap {
                    Button(action: onInfoTap) {
                        Image(systemName: "info.circle").font(.body)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, CardMetrics.infoGap)
                }

                Spacer(minLength: 4)

                // правая сводка (без чипов)
                summary(false).fixedSize()
            }

            // ─ в свёрнутом виде: полоса и чипы
            if !expanded {
                collapsedBar()
                    .frame(maxWidth: .infinity)
                    .frame(height: CardMetrics.barH)
                    .padding(.leading, CardMetrics.chevron + CardMetrics.spacing)

                summary(true)
                    .padding(.leading, CardMetrics.chevron + CardMetrics.spacing)
            }
        }
        .padding(CardMetrics.insets)
        .background(
            Group { if !expanded { RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial) } }
        )
        .contentShape(Rectangle())
        .onTapGesture { withAnimation { expanded.toggle() } } // тап по всей шапке (кроме кнопки i)
        .padding(.horizontal, 4)
    }
}
