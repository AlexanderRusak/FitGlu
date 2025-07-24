import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TrainingsScreen()
                .tabItem {
                    Label("Trainings", systemImage: "figure.walk")
                }

            ActivityScreen()
                .tabItem {
                    Label("Activity", systemImage: "activity.bar")
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
