import SwiftUI

struct ActivityScreen: View {
    
    // MARK: UI‑state
    @State private var selectedDate = Date()
    @State private var showPicker   = false
    
    // MARK: ViewModel
    @StateObject private var vm = DetailsViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            DateHeaderView(date: $selectedDate,
                           showPicker: $showPicker)
        }
    }
}
