import Foundation
import AVKit

// MARK: - Data Models
struct APIResponse: Codable {
    let response: ResponseDetails
}

struct ResponseDetails: Codable {
    let publishedfiledetails: [Wallpaper]
    let nextCursor: String?
    enum CodingKeys: String, CodingKey {
        case publishedfiledetails
        case nextCursor = "next_cursor"
    }
    // Custom decoding to provide a default value and log if missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let details = try container.decodeIfPresent([Wallpaper].self, forKey: .publishedfiledetails) {
            self.publishedfiledetails = details
        } else {
            print("[SteamAPIService] Warning: 'publishedfiledetails' missing in response. Returning empty array.")
            self.publishedfiledetails = []
        }
        self.nextCursor = try container.decodeIfPresent(String.self, forKey: .nextCursor)
    }
}

enum ContentType: String, Codable {
    case image = "image"
    case video = "video"
    case gif = "gif"
    case unknown = "unknown"
    
    static func from(fileURL: URL?, previewURL: URL?) -> ContentType {
        let videoExtensions = ["mp4", "avi", "mov", "wmv", "flv", "webm"]
        let imageExtensions = ["jpg", "jpeg", "png", "bmp", "tiff", "webp"]
        let gifExtension = "gif"
        let urls = [fileURL, previewURL].compactMap { $0 }
        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ext == gifExtension { return .gif }
            if videoExtensions.contains(ext) { return .video }
            if imageExtensions.contains(ext) { return .image }
        }
        // Fallback: if previewURL contains .gif in the path, treat as gif
        if let preview = previewURL?.absoluteString, preview.contains(".gif") { return .gif }
        return .unknown
    }
}

struct Wallpaper: Codable, Identifiable {
    let id: String
    let title: String
    let previewURL: URL?
    let fileURL: URL?
    let fileSize: Int?
    let previewFileSize: Int?
    let contentType: ContentType
    let tags: [Tag]
    let width: Int?
    let height: Int?
    
    // Steam Workshop properties
    let publishedFileId: String  // Same as id, but needed for consistency
    let creatorName: String?
    var fullResURL: URL  // For downloads
    
    // Local file properties (not from API)
    var localFilePath: URL?
    var localFileSize: Int64?
    var isLocallyAvailable: Bool { localFilePath != nil }
    var workshopItemInfo: WorkshopItemInfo?
    
    // Computed property for best available image URL (local first, then remote)
    var bestAvailableImageURL: URL? {
        // Priority 1: Local high-resolution file
        if let localPath = localFilePath {
            return localPath
        }
        
        // Priority 2: Workshop item local file
        if let workshopInfo = workshopItemInfo,
           let primaryImage = workshopInfo.primaryImageFile {
            return primaryImage
        }
        
        // Priority 3: Enhanced Steam CDN URL
        return highResImageURL
    }
    
    // Computed property for higher resolution image URL (fallback)
    var highResImageURL: URL? {
        guard let previewURL = previewURL else { return nil }
        
        // Steam's preview URLs follow this pattern:
        // https://images.steamusercontent.com/ugc/{id}/{hash}/
        // We can try different sizes by appending size parameters or using different endpoints
        
        let urlString = previewURL.absoluteString
        
        // Try to get a larger version by modifying the URL
        // Method 1: Try without size restrictions (sometimes works)
        if urlString.contains("steamusercontent.com/ugc/") {
            // Remove any size parameters and try the base URL
            let baseURL = urlString.components(separatedBy: "?").first ?? urlString
            return URL(string: baseURL)
        }
        
        return previewURL
    }
    
    // Alternative high-res URL attempts
    var alternativeImageURLs: [URL] {
        guard let previewURL = previewURL else { return [] }
        var urls: [URL] = []
        
        let baseString = previewURL.absoluteString
        
        // Try different size parameters that sometimes work
        let sizesToTry = ["", "?imw=1024&imh=1024", "?imw=2048&imh=2048", "?imw=512&imh=512"]
        
        for sizeParam in sizesToTry {
            if let baseURL = baseString.components(separatedBy: "?").first,
               let url = URL(string: baseURL + sizeParam) {
                urls.append(url)
            }
        }
        
        return urls
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "publishedfileid"
        case title
        case previewURL = "preview_url"
        case fileURL = "file_url"
        case fileSize = "file_size"
        case previewFileSize = "preview_file_size"
        case tags
        case width
        case height
        case creatorName = "creator"
    }
    
    struct Tag: Codable, Hashable {
        let tag: String
    }
    
    // Computed properties
    var aspectRatio: CGFloat {
        guard let width = width, let height = height, height > 0 else {
            return 16.0 / 9.0 // Default aspect ratio
        }
        return CGFloat(width) / CGFloat(height)
    }
    
    var isVideo: Bool {
        return contentType == .video
    }
    
    var isGif: Bool {
        return contentType == .gif
    }
    
    var isAnimated: Bool {
        return contentType == .video || contentType == .gif
    }
    
    // Helper method to determine the best download URL
    private static func getBestDownloadURL(fileURL: URL?, previewURL: URL?) -> URL {
        // Priority 1: Use fileURL if it exists (this is the actual full-resolution file)
        if let fileURL = fileURL {
            print("[SteamAPIService] Using fileURL for download: \(fileURL.absoluteString)")
            return fileURL
        }
        
        // Priority 2: Try to enhance the preview URL to get higher resolution
        if let previewURL = previewURL {
            let enhancedURL = Self.enhancePreviewURL(previewURL)
            print("[SteamAPIService] Using enhanced previewURL for download: \(enhancedURL.absoluteString)")
            return enhancedURL
        }
        
        // Fallback: placeholder
        print("[SteamAPIService] Warning: No valid URLs found, using placeholder")
        return URL(string: "https://via.placeholder.com/1920x1080")!
    }
    
    // Enhanced preview URL method to get higher resolution images
    private static func enhancePreviewURL(_ previewURL: URL) -> URL {
        let urlString = previewURL.absoluteString
        
        // Steam CDN URLs can sometimes be enhanced by removing size restrictions
        if urlString.contains("steamusercontent.com/ugc/") {
            // Remove size parameters to get the original resolution
            let baseURL = urlString.components(separatedBy: "?").first ?? urlString
            
            // Try different approaches to get higher resolution
            // Method 1: Remove size restrictions entirely
            if let enhancedURL = URL(string: baseURL) {
                return enhancedURL
            }
        }
        
        // If enhancement fails, return original preview URL
        return previewURL
    }
    
    // Custom decoding to handle missing fields and determine content type
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        publishedFileId = id  // Same as id
        title = try container.decode(String.self, forKey: .title)
        previewURL = try container.decodeIfPresent(URL.self, forKey: .previewURL)
        fileURL = try container.decodeIfPresent(URL.self, forKey: .fileURL)
        creatorName = try container.decodeIfPresent(String.self, forKey: .creatorName)
        
        // Debug logging to understand what URLs we're getting
        print("[SteamAPIService] Wallpaper \(id) - Title: \(title)")
        print("[SteamAPIService] - previewURL: \(previewURL?.absoluteString ?? "nil")")
        print("[SteamAPIService] - fileURL: \(fileURL?.absoluteString ?? "nil")")
        if let previewURL = previewURL {
            print("[SteamAPIService] - previewURL size check: \(previewURL.absoluteString.count) characters")
        }
        
        // fileSize: handle both String and Int
        if let fileSizeString = try? container.decodeIfPresent(String.self, forKey: .fileSize) {
            fileSize = Int(fileSizeString)
        } else if let fileSizeInt = try? container.decodeIfPresent(Int.self, forKey: .fileSize) {
            fileSize = fileSizeInt
        } else {
            fileSize = nil
        }
        // previewFileSize: handle both String and Int
        if let previewFileSizeString = try? container.decodeIfPresent(String.self, forKey: .previewFileSize) {
            previewFileSize = Int(previewFileSizeString)
        } else if let previewFileSizeInt = try? container.decodeIfPresent(Int.self, forKey: .previewFileSize) {
            previewFileSize = previewFileSizeInt
        } else {
            previewFileSize = nil
        }
        tags = try container.decode([Tag].self, forKey: .tags)
        width = try container.decodeIfPresent(Int.self, forKey: .width)
        height = try container.decodeIfPresent(Int.self, forKey: .height)
        
        contentType = ContentType.from(fileURL: fileURL, previewURL: previewURL)
        
        // Initialize local file properties
        localFilePath = nil
        localFileSize = nil
        workshopItemInfo = nil
        
        // Set fullResURL - prioritize actual file URL over preview URL
        fullResURL = Self.getBestDownloadURL(fileURL: fileURL, previewURL: previewURL)
    }
}

// MARK: - Steam API Service
class SteamAPIService {
    private var apiKey: String? {
        return TokenManager.shared.loadToken()
    }
    private let wallpaperEngineAppID = "431960"
    private let steamClientManager = SteamClientManager()

    func fetchWallpapers(cursor: String = "*", searchText: String? = nil, tags: [String] = []) async throws -> (items: [Wallpaper], nextCursor: String?) {
        guard let apiKey = apiKey else {
            throw NSError(domain: "SteamAPIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API token not found. Please provide your Steam API key."])
        }
        
        var components = URLComponents(string: "https://api.steampowered.com/IPublishedFileService/QueryFiles/v1/")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "creator_appid", value: wallpaperEngineAppID),
            URLQueryItem(name: "appid", value: wallpaperEngineAppID),
            URLQueryItem(name: "query_type", value: "9"),
            URLQueryItem(name: "cursor", value: cursor),
            URLQueryItem(name: "numperpage", value: "30"),
            URLQueryItem(name: "return_metadata", value: "true"),
            URLQueryItem(name: "return_preview_url", value: "true"),
            URLQueryItem(name: "return_file_url", value: "true"),
            URLQueryItem(name: "return_tags", value: "true"),
            URLQueryItem(name: "return_details", value: "true")
        ]
        if let searchText = searchText, !searchText.isEmpty {
            queryItems.append(URLQueryItem(name: "search_text", value: searchText))
        }
        for tag in tags where !tag.isEmpty {
            queryItems.append(URLQueryItem(name: "requiredtags[]", value: tag))
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse.self, from: data)
        
        // Enhance wallpapers with local file information
        let enhancedWallpapers = apiResponse.response.publishedfiledetails.map { wallpaper in
            enhanceWallpaperWithLocalInfo(wallpaper)
        }
        
        return (enhancedWallpapers, apiResponse.response.nextCursor)
    }
    
    // MARK: - Local File Enhancement
    private func enhanceWallpaperWithLocalInfo(_ wallpaper: Wallpaper) -> Wallpaper {
        var enhancedWallpaper = wallpaper
        
        // Check if we have local files for this wallpaper
        if let workshopInfo = steamClientManager.getWorkshopItemInfo(itemID: wallpaper.id) {
            print("[SteamAPIService] Found local workshop info for \(wallpaper.id): \(workshopInfo.files?.count ?? 0) files")
            enhancedWallpaper.workshopItemInfo = workshopInfo
            enhancedWallpaper.localFilePath = workshopInfo.primaryImageFile
            enhancedWallpaper.localFileSize = workshopInfo.downloadSize
        } else {
            print("[SteamAPIService] No local workshop info found for \(wallpaper.id)")
        }
        
        return enhancedWallpaper
    }
    
    // MARK: - Steam Client Integration
    func getSteamClientManager() -> SteamClientManager {
        return steamClientManager
    }
    
    func subscribeToWallpaper(_ wallpaper: Wallpaper) async -> Bool {
        return await steamClientManager.subscribeToWorkshopItem(itemID: wallpaper.id)
    }
    
    func openWallpaperInSteam(_ wallpaper: Wallpaper) {
        steamClientManager.openSteamWorkshopPage(itemID: wallpaper.id)
    }
    
    func refreshLocalContent() {
        steamClientManager.refreshWorkshopContent()
    }
    
    func launchSteamClient() -> Bool {
        return steamClientManager.launchSteamClient()
    }
    
    func installSteam() {
        steamClientManager.installSteam()
    }
} 