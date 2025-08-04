import SwiftUI

// MARK: - Environment key to control initial state
private struct InitialExpandedKey: EnvironmentKey {
    static let defaultValue: Bool = true          // accordion starts opened unless overridden
}

extension EnvironmentValues {
    /// Set via `.environment(\.initialExpanded, false)` to start collapsed.
    var initialExpanded: Bool {
        get { self[InitialExpandedKey.self] }
        set { self[InitialExpandedKey.self] = newValue }
    }
}

// MARK: - Generic collapsible block
///
/// * `title`       – left-aligned caption.
/// * `summary`     – header summary; closure gets a `showChips` flag.
///                   `false` → draw score / capsule; `true` → draw coloured chips.
/// * `content`     – body revealed when expanded.
struct MetricAccordion<Summary: View, Content: View>: View {

    // MARK: public API
    let title: String
    let summary: (_ showChips: Bool) -> Summary
    let content: () -> Content

    // MARK: state / env
    @Environment(\.initialExpanded) private var initialExpanded
    @State private var expanded = true

    // MARK: body
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
        .onAppear { expanded = initialExpanded }   // adopt initial state
        .animation(.easeInOut, value: expanded)
        .padding(.vertical, 4)
    }

    // MARK: header
    private var header: some View {
        Button {
            withAnimation { expanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 2) {

                // ── first line: arrow • title • score/capsule ──
                HStack(spacing: 12) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                        .layoutPriority(10)

                    Spacer(minLength: 4)

                    summary(false)                 // no chips
                        .fixedSize()
                }

                // ── second line: coloured chips (only when collapsed) ──
                if !expanded {
                    summary(true)                  // chips only
                        .padding(.leading, 24)     // align under title (arrow 12 + spacing 12)
                }
            }
            .padding(12)                           // same insets as TrainingQualityCard
            .background(
                !expanded                           // card-like background only when collapsed
                ? AnyView(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                )
                : AnyView(EmptyView())
            )
            .contentShape(Rectangle())             // full tap area
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)                   // outer margin
    }
}
