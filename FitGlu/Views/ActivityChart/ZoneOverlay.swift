import SwiftUI

struct ZoneRange: Identifiable {
    let id = UUID()
    let range: ClosedRange<Int>
    let color: Color
}
