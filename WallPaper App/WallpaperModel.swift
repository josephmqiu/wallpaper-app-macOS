//  WallpaperModel.swift
//  Wallpaper App
//
//  Defines the wallpaper entity for Core Data and Codable for API use.
//
//  Created for MVP scaffold.

import Foundation
import CoreData

// MARK: - Shared Workshop Item Info
struct WorkshopItemInfo: Codable {
    let itemID: String
    let subscribed: Bool
    let installed: Bool
    let downloadSize: Int64?
    let lastUpdated: Date?
    let localPath: URL?
    let files: [URL]?
    let primaryImageFile: URL?
    
    enum CodingKeys: String, CodingKey {
        case itemID, subscribed, installed, downloadSize, lastUpdated
        // localPath, files, and primaryImageFile are not encoded/decoded
    }
    
    init(itemID: String, subscribed: Bool, installed: Bool, downloadSize: Int64?, lastUpdated: Date?, localPath: URL? = nil, files: [URL]? = nil, primaryImageFile: URL? = nil) {
        self.itemID = itemID
        self.subscribed = subscribed
        self.installed = installed
        self.downloadSize = downloadSize
        self.lastUpdated = lastUpdated
        self.localPath = localPath
        self.files = files
        self.primaryImageFile = primaryImageFile
    }
    
    // Custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(itemID, forKey: .itemID)
        try container.encode(subscribed, forKey: .subscribed)
        try container.encode(installed, forKey: .installed)
        try container.encodeIfPresent(downloadSize, forKey: .downloadSize)
        try container.encodeIfPresent(lastUpdated, forKey: .lastUpdated)
    }
    
    // Custom decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemID = try container.decode(String.self, forKey: .itemID)
        subscribed = try container.decode(Bool.self, forKey: .subscribed)
        installed = try container.decode(Bool.self, forKey: .installed)
        downloadSize = try container.decodeIfPresent(Int64.self, forKey: .downloadSize)
        lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated)
        
        // These properties are not decoded, set to nil
        localPath = nil
        files = nil
        primaryImageFile = nil
    }
}

struct WallpaperModel: Codable, Identifiable {
    let id: String
    let title: String
    let author: String
    let tags: [String]
    let previewURL: URL
    let fullResURL: URL
    let isVideo: Bool
    
    // Local file management
    var localFilePath: URL?
    var localFileSize: Int64?
    var isDownloaded: Bool { localFilePath != nil }
    var downloadProgress: Double?
    var downloadStatus: DownloadStatus?
    
    // Steam Workshop integration
    var workshopItemID: String?
    var workshopItemInfo: WorkshopItemInfo?
    
    enum DownloadStatus: String, Codable {
        case notStarted = "not_started"
        case downloading = "downloading"
        case completed = "completed"
        case failed = "failed"
        case paused = "paused"
    }
    

    
    // Computed property for best available image URL
    var bestAvailableImageURL: URL {
        if let localPath = localFilePath, FileManager.default.fileExists(atPath: localPath.path) {
            return localPath
        }
        return fullResURL
    }
    
    // MARK: - Mock Data for MVP
    static let mockWallpapers: [WallpaperModel] = [
        WallpaperModel(
            id: "1",
            title: "Neon Cityscape",
            author: "DigitalArtist",
            tags: ["Abstract", "City", "Night"],
            previewURL: URL(string: "https://via.placeholder.com/400x300/1a1a2e/ffffff?text=Neon+Cityscape")!,
            fullResURL: URL(string: "https://via.placeholder.com/1920x1080/1a1a2e/ffffff?text=Neon+Cityscape")!,
            isVideo: false
        ),
        WallpaperModel(
            id: "2",
            title: "Forest Path",
            author: "NaturePhotoX",
            tags: ["Nature", "Forest", "Landscape"],
            previewURL: URL(string: "https://via.placeholder.com/400x300/2d5016/ffffff?text=Forest+Path")!,
            fullResURL: URL(string: "https://via.placeholder.com/1920x1080/2d5016/ffffff?text=Forest+Path")!,
            isVideo: false
        ),
        WallpaperModel(
            id: "3",
            title: "Abstract Waves",
            author: "ModernDesign",
            tags: ["Abstract", "Colorful"],
            previewURL: URL(string: "https://via.placeholder.com/400x300/4a90e2/ffffff?text=Abstract+Waves")!,
            fullResURL: URL(string: "https://via.placeholder.com/1920x1080/4a90e2/ffffff?text=Abstract+Waves")!,
            isVideo: false
        ),
        WallpaperModel(
            id: "4",
            title: "Mountain Sunset",
            author: "OutdoorPics",
            tags: ["Nature", "Mountains", "Sunset"],
            previewURL: URL(string: "https://via.placeholder.com/400x300/f39c12/ffffff?text=Mountain+Sunset")!,
            fullResURL: URL(string: "https://via.placeholder.com/1920x1080/f39c12/ffffff?text=Mountain+Sunset")!,
            isVideo: false
        ),
        WallpaperModel(
            id: "5",
            title: "Geometric Patterns",
            author: "MinimalArt",
            tags: ["Minimal", "Abstract"],
            previewURL: URL(string: "https://via.placeholder.com/400x300/9b59b6/ffffff?text=Geometric+Patterns")!,
            fullResURL: URL(string: "https://via.placeholder.com/1920x1080/9b59b6/ffffff?text=Geometric+Patterns")!,
            isVideo: false
        ),
        WallpaperModel(
            id: "6",
            title: "Ocean Waves",
            author: "SeaLover",
            tags: ["Nature", "Ocean", "Water"],
            previewURL: URL(string: "https://via.placeholder.com/400x300/3498db/ffffff?text=Ocean+Waves")!,
            fullResURL: URL(string: "https://via.placeholder.com/1920x1080/3498db/ffffff?text=Ocean+Waves")!,
            isVideo: false
        ),
        WallpaperModel(
            id: "7",
            title: "Galaxy Stars",
            author: "SpaceFan",
            tags: ["Space", "Galaxy", "Dark"],
            previewURL: URL(string: "https://via.placeholder.com/400x300/2c3e50/ffffff?text=Galaxy+Stars")!,
            fullResURL: URL(string: "https://via.placeholder.com/1920x1080/2c3e50/ffffff?text=Galaxy+Stars")!,
            isVideo: false
        ),
        WallpaperModel(
            id: "8",
            title: "Cherry Blossoms",
            author: "SpringTime",
            tags: ["Nature", "Flowers", "Spring"],
            previewURL: URL(string: "https://via.placeholder.com/400x300/e91e63/ffffff?text=Cherry+Blossoms")!,
            fullResURL: URL(string: "https://via.placeholder.com/1920x1080/e91e63/ffffff?text=Cherry+Blossoms")!,
            isVideo: false
        )
    ]
}

@objc(WallpaperEntity)
public class WallpaperEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var title: String
    @NSManaged public var author: String
    @NSManaged public var tags: [String]
    @NSManaged public var previewURL: URL
    @NSManaged public var fullResURL: URL
    @NSManaged public var isVideo: Bool
    @NSManaged public var localFilePath: URL?
    @NSManaged public var localFileSize: Int64
    @NSManaged public var workshopItemID: String?
    // Note: Additional properties like NSFW, aspectRatio, favorite can be added here
} 