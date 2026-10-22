//
//  ContentView.swift
//  PostureCoach
//
//  Created by Nicole Kong Mei Ning on 22/10/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            SessionView(sensorSource: HeadphoneMotionSource())
                .navigationTitle("Posture Coach")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink("History") {
                            HistoryView()
                        }
                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
