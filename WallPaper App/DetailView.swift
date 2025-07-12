//  DetailView.swift
//  Wallpaper App
//
//  Shows wallpaper details, preview, and apply/download actions.
//
//  Created for MVP scaffold.

import SwiftUI

struct DetailView: View {
    let wallpaper: WallpaperModel
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Use AsyncImage for preview
                AsyncImage(url: wallpaper.fullResURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                    case .success(let image):
                        image.resizable().aspectRatio(16/9, contentMode: .fit)
                    case .failure:
                        Rectangle().fill(Color.gray.opacity(0.3)).aspectRatio(16/9, contentMode: .fit)
                    @unknown default:
                        Rectangle().fill(Color.gray.opacity(0.3)).aspectRatio(16/9, contentMode: .fit)
                    }
                }
                Text(wallpaper.title).font(.title)
                Text("by \(wallpaper.author)").font(.subheadline).foregroundColor(.secondary)
                
                // Tag chips
                HStack {
                    ForEach(wallpaper.tags, id: \.self) { tag in
                        Text(tag).padding(6).background(Color.gray.opacity(0.2)).cornerRadius(8)
                    }
                }
                
                // Download/Apply buttons
                HStack(spacing: 16) {
                    Button("Set as Desktop Wallpaper") {
                        setDesktopWallpaper(url: wallpaper.fullResURL)
                    }
                }
            }.padding()
        }
        .navigationTitle(wallpaper.title)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    func setDesktopWallpaper(url: URL) {
        // Set desktop wallpaper using NSWorkspace
        let ws = NSWorkspace.shared
        if let screen = NSScreen.main {
            do {
                try ws.setDesktopImageURL(url, for: screen, options: [:])
            } catch {
                errorMessage = "Failed to set wallpaper: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
} 