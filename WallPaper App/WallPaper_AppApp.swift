//
//  WallPaper_AppApp.swift
//  WallPaper App
//
//  Created by Joseph Qiu on 7/11/25.
//

import SwiftUI

@main
struct WallPaper_AppApp: App {
    @State private var showingTokenInput = false
    
    init() {
        // Check if we have a stored API token
        if !TokenManager.shared.hasToken() {
            // We'll show the token input on first launch
            showingTokenInput = true
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    if !TokenManager.shared.hasToken() {
                        showingTokenInput = true
                    }
                }
                .sheet(isPresented: $showingTokenInput) {
                    TokenInputView(isPresented: $showingTokenInput) { _ in
                        // Token saved, app can proceed
                    }
                }
        }
        .windowStyle(.automatic)
        .commands {
            // Add menu items for token management
            CommandGroup(after: .appSettings) {
                Button("Change API Token...") {
                    showingTokenInput = true
                }
                .keyboardShortcut(",", modifiers: [.command, .shift])
            }
        }
    }
}
