import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DailyCoachScreen()
                            .tabItem { Label("Today", systemImage: "target") }
            TrainingsScreen()
                .tabItem {
                    Label("Trainings", systemImage: "figure.walk")
                }
            WorkoutDiaryScreen()
                .tabItem {
                    Label("Diary", systemImage: "note.text")
                }
            ActivityScreen()
                .tabItem {
                    Label("Activity", systemImage: "chart.bar")
                }
            SettingsScreen()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
            
         /*   DetailsScreen()
                .tabItem {
                    Label("Details", systemImage: "chart.bar")
                }*/

//            AllGlucoseScreen()
//                .tabItem {
//                    Label("All Glucose", systemImage: "drop")
//                }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppSettingsStore())
}
