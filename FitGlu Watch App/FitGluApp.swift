//
//  FitGluApp.swift
//  FitGlu Watch App
//
//  Created by Александр Русак on 24/11/2024.
//

import SwiftUI

@main
struct FitGlu_Watch_AppApp: App {
    
    init() {
        print("FitGluWatchApp init")
        // ВАЖНО: Тут принудительно инициализируем
        _ = WatchConnectivityProvider.shared
    }
    
    var body: some Scene {
        WindowGroup {
            WorkoutSelectionView()
        }
    }
}
