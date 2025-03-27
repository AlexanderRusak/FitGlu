import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TrainingsScreen()
                .tabItem {
                    Label("Trainings", systemImage: "figure.walk")
                }

            DetailsScreen()
                .tabItem {
                    Label("Details", systemImage: "chart.bar")
                }

            AllGlucoseScreen()
                .tabItem {
                    Label("All Glucose", systemImage: "drop")
                }
        }
    }
}

#Preview {
    MainTabView()
}
