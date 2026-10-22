//
//  PostureCoachApp.swift
//  PostureCoach
//
//  Created by Nicole Kong Mei Ning on 22/10/2026.
//

import SwiftData
import SwiftUI

@main
struct PostureCoachApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Session.self)
    }
}
