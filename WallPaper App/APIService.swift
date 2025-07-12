//  APIService.swift
//  Wallpaper App
//
//  Handles networking for Steam proxy and LLM image APIs.
//
//  Created for MVP scaffold.

import Foundation
import Combine

/// Service for fetching wallpapers and generating AI images.
final class APIService {
    static let shared = APIService()
    private init() {}
    
    // MARK: - Steam Workshop Proxy
    /// Fetch wallpapers from the mirrored Steam Workshop API.
    /// Note: This is a placeholder implementation for future proxy integration.
    func fetchWallpapers(query: String? = nil, tags: [String] = [], page: Int = 1) -> AnyPublisher<[WallpaperModel], Error> {
        // Return empty result for now - actual implementation would connect to a proxy service
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - AI Generation
    /// Generate a wallpaper using an LLM image API (OpenAI, Gemini, Stability).
    /// Note: This is a placeholder implementation for future AI integration.
    func generateAIWallpaper(prompt: String) -> AnyPublisher<WallpaperModel, Error> {
        // Return a mock result for now - actual implementation would call AI services
        let mockWallpaper = WallpaperModel(
            id: UUID().uuidString,
            title: prompt,
            author: "AI Generated",
            tags: ["AI", "Generated"],
            previewURL: URL(string: "https://via.placeholder.com/400x300?text=AI+Generated")!,
            fullResURL: URL(string: "https://via.placeholder.com/1920x1080?text=AI+Generated")!,
            isVideo: false
        )
        
        return Just(mockWallpaper)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
} 