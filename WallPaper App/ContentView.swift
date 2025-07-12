//
//  ContentView.swift
//  WallPaper App
//
//  Created by Joseph Qiu on 7/11/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            // Browse Tab
            WallpaperBrowserView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("Browse")
                }
            
            // Downloaded Tab
            DownloadedWallpapersView()
                .tabItem {
                    Image(systemName: "square.and.arrow.down")
                    Text("Downloaded")
                }
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
    }
}

#Preview {
    ContentView()
}

