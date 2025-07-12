//  AIWizardView.swift
//  Wallpaper App
//
//  UI for AI wallpaper generation: prompt input, progress, preview, and save.
//
//  Created for MVP scaffold.

import SwiftUI
import Combine

struct AIWizardView: View {
    @State private var prompt: String = ""
    @State private var isLoading = false
    @State private var generatedWallpaper: WallpaperModel?
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        VStack(spacing: 24) {
            Text("AI Wallpaper Generator").font(.title2)
            TextField("Describe your dream wallpaper...", text: $prompt)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button(action: generate) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Generate")
                }
            }.disabled(prompt.isEmpty || isLoading)
            if generatedWallpaper != nil {
                AsyncImage(url: generatedWallpaper?.previewURL) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fit)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.3)).aspectRatio(16/9, contentMode: .fit)
                }
                Button("Save to Library") {
                    // Note: Core Data integration would be implemented here
                    print("Save to library functionality would be implemented")
                }
            }
            if let error = errorMessage {
                Text(error).foregroundColor(.red)
            }
        }.padding()
    }
    
    func generate() {
        isLoading = true
        errorMessage = nil
        
        // Use the APIService for AI generation
        APIService.shared.generateAIWallpaper(prompt: prompt)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        errorMessage = "Generation failed: \(error.localizedDescription)"
                    }
                },
                receiveValue: { wallpaper in
                    self.generatedWallpaper = wallpaper
                }
            )
            .store(in: &cancellables)
    }
} 