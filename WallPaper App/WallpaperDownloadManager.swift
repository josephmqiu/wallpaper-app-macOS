import Foundation
import AppKit
import Combine

// MARK: - Notification Names
extension Notification.Name {
    static let previewDownloadCompleted = Notification.Name("previewDownloadCompleted")
    static let fullResDownloadCompleted = Notification.Name("fullResDownloadCompleted")
}

// MARK: - Wallpaper Download Manager
class WallpaperDownloadManager: NSObject, ObservableObject {
    @Published var downloadProgress: [String: Double] = [:]
    @Published var downloadStatus: [String: WallpaperModel.DownloadStatus] = [:]
    @Published var downloadedWallpapers: [String: URL] = [:]
    
    private let fileManager = FileManager.default
    private var urlSession: URLSession!
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // App's wallpaper storage directory
    lazy var wallpaperDirectory: URL = {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let wallpaperDir = documentsPath.appendingPathComponent("WallpaperApp/Downloads")
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: wallpaperDir, withIntermediateDirectories: true)
        
        return wallpaperDir
    }()
    
    // High-resolution wallpaper directory
    lazy var highResDirectory: URL = {
        let highResDir = wallpaperDirectory.appendingPathComponent("HighRes")
        try? fileManager.createDirectory(at: highResDir, withIntermediateDirectories: true)
        return highResDir
    }()
    
    override init() {
        super.init()
        
        // Configure URLSession for downloads with delegate
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 300.0
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        print("[WallpaperDownloadManager] Initialized with directory: \(wallpaperDirectory.path)")
        loadExistingDownloads()
    }
    
    // MARK: - Local Steam Workshop Integration
    
    /// Checks if a wallpaper exists in the local Steam Workshop directory
    private func checkForLocalWorkshopFile(wallpaperID: String) -> URL? {
        // Try to find Steam Workshop directory - check multiple possible locations
        let steamPaths = [
            "~/Library/Application Support/Steam/steamapps/workshop/content/431960",
            "~/Library/Containers/com.valvesoftware.steam/Data/Library/Application Support/Steam/steamapps/workshop/content/431960",
            "/Users/\(NSUserName())/Library/Application Support/Steam/steamapps/workshop/content/431960",
            // Also check if Steam is installed via CrossOver or other methods
            "~/Library/Application Support/CrossOver/Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/workshop/content/431960"
        ]
        
        for steamPath in steamPaths {
            let expandedPath = NSString(string: steamPath).expandingTildeInPath
            let workshopPath = URL(fileURLWithPath: expandedPath)
            let itemPath = workshopPath.appendingPathComponent(wallpaperID)
            
            print("[WallpaperDownloadManager] Checking workshop path: \(itemPath.path)")
            
            if fileManager.fileExists(atPath: itemPath.path) {
                print("[WallpaperDownloadManager] ✅ Found workshop directory for \(wallpaperID)")
                
                // Look for the largest image file in the directory
                do {
                    let contents = try fileManager.contentsOfDirectory(at: itemPath, includingPropertiesForKeys: [.fileSizeKey])
                    let imageFiles = contents.filter { url in
                        let ext = url.pathExtension.lowercased()
                        return ["jpg", "jpeg", "png", "bmp", "tiff", "webp", "gif"].contains(ext)
                    }
                    
                    print("[WallpaperDownloadManager] Found \(imageFiles.count) image files in workshop directory")
                    
                    // Sort by file size (largest first)
                    let sortedFiles = imageFiles.sorted { url1, url2 in
                        let size1 = (try? url1.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                        let size2 = (try? url2.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                        return size1 > size2
                    }
                    
                    if let largestFile = sortedFiles.first {
                        let fileSize = (try? largestFile.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                        print("[WallpaperDownloadManager] ✅ Found local Steam Workshop file: \(largestFile.path)")
                        print("[WallpaperDownloadManager] File size: \(ByteCountFormatter().string(fromByteCount: Int64(fileSize)))")
                        
                        // Only return if the file is significantly larger than a preview (> 2MB)
                        if fileSize > 2_000_000 {
                            return largestFile
                        } else {
                            print("[WallpaperDownloadManager] ⚠️ Local file is small (\(ByteCountFormatter().string(fromByteCount: Int64(fileSize)))), likely a preview")
                        }
                    }
                } catch {
                    print("[WallpaperDownloadManager] Error reading workshop directory: \(error)")
                }
            } else {
                print("[WallpaperDownloadManager] Workshop directory not found: \(itemPath.path)")
            }
        }
        
        print("[WallpaperDownloadManager] ❌ No local Steam Workshop file found for \(wallpaperID)")
        return nil
    }
    
    /// Copies a local Steam Workshop file to the app's download directory
    private func copyLocalWorkshopFile(wallpaperID: String, localFile: URL, wallpaper: WallpaperModel) {
        do {
            // Determine file extension
            let fileExtension = localFile.pathExtension.lowercased()
            
            // Create final file path
            let fileName = "\(wallpaperID)_\(wallpaper.title.replacingOccurrences(of: " ", with: "_")).\(fileExtension)"
            let finalURL = highResDirectory.appendingPathComponent(fileName)
            
            // Remove existing file if it exists
            if fileManager.fileExists(atPath: finalURL.path) {
                try fileManager.removeItem(at: finalURL)
            }
            
            // Copy the local file
            try fileManager.copyItem(at: localFile, to: finalURL)
            
            // Get file size
            let attributes = try fileManager.attributesOfItem(atPath: finalURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            print("[WallpaperDownloadManager] ✅ Copied local Steam Workshop file: \(finalURL.path)")
            print("[WallpaperDownloadManager] File size: \(ByteCountFormatter().string(fromByteCount: fileSize))")
            
            // Update status
            DispatchQueue.main.async {
                self.downloadStatus[wallpaperID] = .completed
                self.downloadProgress[wallpaperID] = 1.0
                self.downloadedWallpapers[wallpaperID] = finalURL
            }
            
            // Save to user defaults for persistence
            saveDownloadedWallpapers()
            
        } catch {
            print("[WallpaperDownloadManager] Failed to copy local Steam Workshop file: \(error)")
            // Fall back to regular download
            downloadWallpaperFromURL(wallpaper)
        }
    }
    
    /// Downloads a wallpaper from URL (extracted from original download method)
    private func downloadWallpaperFromURL(_ wallpaper: WallpaperModel) {
        let wallpaperID = wallpaper.id
        
        print("[WallpaperDownloadManager] Starting download for: \(wallpaper.title)")
        print("[WallpaperDownloadManager] Download URL: \(wallpaper.fullResURL.absoluteString)")
        
        // Update status
        DispatchQueue.main.async {
            self.downloadStatus[wallpaperID] = .downloading
            self.downloadProgress[wallpaperID] = 0.0
        }
        
        // Create download task
        let downloadTask = urlSession.downloadTask(with: wallpaper.fullResURL) { [weak self] tempURL, response, error in
            self?.handleDownloadCompletion(
                wallpaperID: wallpaperID,
                wallpaper: wallpaper,
                tempURL: tempURL,
                response: response,
                error: error
            )
        }
        
        // Store task reference
        downloadTasks[wallpaperID] = downloadTask
        
        // Start download
        downloadTask.resume()
    }
    
    // MARK: - Steam Workshop Integration Helper
    
    /// Opens Steam Workshop page for a wallpaper to allow subscription
    func openSteamWorkshopPage(for wallpaperID: String) {
        let steamURL = "steam://url/CommunityFilePage/\(wallpaperID)"
        
        if let url = URL(string: steamURL) {
            print("[WallpaperDownloadManager] Opening Steam Workshop page for wallpaper \(wallpaperID)")
            NSWorkspace.shared.open(url)
            
            // Provide user guidance
            print("[WallpaperDownloadManager] 💡 To get full-resolution files:")
            print("[WallpaperDownloadManager]    1. Click 'Subscribe' on the Steam Workshop page")
            print("[WallpaperDownloadManager]    2. Steam will download the full-resolution file")
            print("[WallpaperDownloadManager]    3. Return to the app and try downloading again")
            print("[WallpaperDownloadManager]    4. The app will automatically use the high-res local file")
        } else {
            // Fallback to web URL
            let webURL = "https://steamcommunity.com/sharedfiles/filedetails/?id=\(wallpaperID)"
            if let url = URL(string: webURL) {
                print("[WallpaperDownloadManager] Opening web Steam Workshop page for wallpaper \(wallpaperID)")
                NSWorkspace.shared.open(url)
                print("[WallpaperDownloadManager] 💡 Note: Subscribe to this wallpaper in Steam to get full-resolution files")
            }
        }
    }
    
    /// Checks if Steam Workshop directory exists (to guide users)
    func checkSteamWorkshopSetup() -> (hasWorkshopDir: Bool, message: String) {
        let workshopPath = "~/Library/Application Support/Steam/steamapps/workshop/content/431960"
        let expandedPath = NSString(string: workshopPath).expandingTildeInPath
        
        if fileManager.fileExists(atPath: expandedPath) {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: expandedPath)
                let itemCount = contents.count
                return (true, "Found \(itemCount) subscribed wallpapers in Steam Workshop")
            } catch {
                return (true, "Steam Workshop directory exists but couldn't read contents")
            }
        } else {
            return (false, "No Steam Workshop wallpapers found. Subscribe to wallpapers in Steam to get full-resolution files.")
        }
    }
    
    // MARK: - Download Management
    
    /// Downloads a wallpaper to the app's local storage
    func downloadWallpaper(_ wallpaper: WallpaperModel) {
        let wallpaperID = wallpaper.id
        
        // Check if already downloaded
        if let existingPath = downloadedWallpapers[wallpaperID],
           fileManager.fileExists(atPath: existingPath.path) {
            print("[WallpaperDownloadManager] Wallpaper \(wallpaperID) already downloaded")
            return
        }
        
        // Check if download is in progress
        if downloadTasks[wallpaperID] != nil {
            print("[WallpaperDownloadManager] Download for \(wallpaperID) already in progress")
            return
        }
        
        // Check if we have a local Steam Workshop file we can copy instead
        if let localWorkshopFile = checkForLocalWorkshopFile(wallpaperID: wallpaperID) {
            print("[WallpaperDownloadManager] Found local Steam Workshop file, copying instead of downloading")
            copyLocalWorkshopFile(wallpaperID: wallpaperID, localFile: localWorkshopFile, wallpaper: wallpaper)
            return
        }
        
        // Fall back to URL download
        downloadWallpaperFromURL(wallpaper)
    }
    
    /// Downloads wallpaper for setting as desktop background
    func downloadAndSetAsWallpaper(_ wallpaper: WallpaperModel, completion: @escaping (Result<URL, Error>) -> Void) {
        let wallpaperID = wallpaper.id
        
        // Check if already downloaded
        if let existingPath = downloadedWallpapers[wallpaperID],
           fileManager.fileExists(atPath: existingPath.path) {
            print("[WallpaperDownloadManager] Using existing download for wallpaper")
            completion(.success(existingPath))
            return
        }
        
        // Download and then set as wallpaper
        downloadWallpaperWithCompletion(wallpaper) { [weak self] result in
            switch result {
            case .success(let localURL):
                print("[WallpaperDownloadManager] Download completed, setting as wallpaper")
                self?.setDesktopWallpaper(localURL) { setResult in
                    switch setResult {
                    case .success:
                        completion(.success(localURL))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func downloadWallpaperWithCompletion(_ wallpaper: WallpaperModel, completion: @escaping (Result<URL, Error>) -> Void) {
        let wallpaperID = wallpaper.id
        
        print("[WallpaperDownloadManager] Starting download with completion for: \(wallpaper.title)")
        
        // Update status
        DispatchQueue.main.async {
            self.downloadStatus[wallpaperID] = .downloading
            self.downloadProgress[wallpaperID] = 0.0
        }
        
        // Create download task
        let downloadTask = urlSession.downloadTask(with: wallpaper.fullResURL) { [weak self] tempURL, response, error in
            let result = self?.handleDownloadCompletion(
                wallpaperID: wallpaperID,
                wallpaper: wallpaper,
                tempURL: tempURL,
                response: response,
                error: error
            )
            
            if let result = result {
                completion(result)
            } else {
                completion(.failure(WallpaperDownloadError.unknownError))
            }
        }
        
        // Store task reference
        downloadTasks[wallpaperID] = downloadTask
        
        // Start download
        downloadTask.resume()
    }
    
    private func handleDownloadCompletion(
        wallpaperID: String,
        wallpaper: WallpaperModel,
        tempURL: URL?,
        response: URLResponse?,
        error: Error?
    ) -> Result<URL, Error> {
        // Clean up task reference
        downloadTasks.removeValue(forKey: wallpaperID)
        
        if let error = error {
            print("[WallpaperDownloadManager] Download failed for \(wallpaperID): \(error)")
            DispatchQueue.main.async {
                self.downloadStatus[wallpaperID] = .failed
                self.downloadProgress[wallpaperID] = 0.0
            }
            return .failure(error)
        }
        
        guard let tempURL = tempURL else {
            print("[WallpaperDownloadManager] No temporary URL for \(wallpaperID)")
            DispatchQueue.main.async {
                self.downloadStatus[wallpaperID] = .failed
            }
            return .failure(WallpaperDownloadError.noTempURL)
        }
        
        do {
            // Determine file extension from response or URL
            let fileExtension = determineFileExtension(from: response, fallbackURL: wallpaper.fullResURL)
            
            // Create final file path
            let fileName = "\(wallpaperID)_\(wallpaper.title.replacingOccurrences(of: " ", with: "_")).\(fileExtension)"
            let finalURL = highResDirectory.appendingPathComponent(fileName)
            
            // Remove existing file if it exists
            if fileManager.fileExists(atPath: finalURL.path) {
                try fileManager.removeItem(at: finalURL)
            }
            
            // Move downloaded file to final location
            try fileManager.moveItem(at: tempURL, to: finalURL)
            
            // Check file size to detect if we got a preview instead of full resolution
            let attributes = try fileManager.attributesOfItem(atPath: finalURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            print("[WallpaperDownloadManager] ✅ Download completed: \(finalURL.path)")
            print("[WallpaperDownloadManager] File size: \(ByteCountFormatter().string(fromByteCount: fileSize))")
            
            // Check if this is a preview image (which is expected for direct downloads)
            if fileSize < 2_000_000 { // Less than 2MB is likely a preview
                print("[WallpaperDownloadManager] ℹ️ Downloaded preview image (\(ByteCountFormatter().string(fromByteCount: fileSize)))")
                print("[WallpaperDownloadManager] 📋 Steam Workshop Limitation:")
                print("[WallpaperDownloadManager]    • Steam API only provides preview images")
                print("[WallpaperDownloadManager]    • Full-resolution files require Steam client subscription")
                print("[WallpaperDownloadManager]    • This is a security/licensing limitation by Steam")
                print("[WallpaperDownloadManager] 🔄 To get full-resolution files:")
                print("[WallpaperDownloadManager]    1. Click 'Subscribe for High-Res' to open Steam Workshop")
                print("[WallpaperDownloadManager]    2. Subscribe to the wallpaper in Steam")
                print("[WallpaperDownloadManager]    3. Steam will download the full files automatically")
                print("[WallpaperDownloadManager]    4. Full files will appear in the 'Downloaded' tab")
                
                // Update status to indicate this is a preview
                DispatchQueue.main.async {
                    self.downloadStatus[wallpaperID] = .completed
                    self.downloadProgress[wallpaperID] = 1.0
                    self.downloadedWallpapers[wallpaperID] = finalURL
                    
                    // Post notification about preview download
                    NotificationCenter.default.post(name: .previewDownloadCompleted, object: nil, userInfo: [
                        "wallpaperID": wallpaperID,
                        "fileSize": fileSize,
                        "message": "Downloaded preview image. Subscribe in Steam Workshop for full resolution."
                    ])
                }
            } else {
                print("[WallpaperDownloadManager] ✅ Downloaded full-resolution file (\(ByteCountFormatter().string(fromByteCount: fileSize)))")
                
                // Update status
                DispatchQueue.main.async {
                    self.downloadStatus[wallpaperID] = .completed
                    self.downloadProgress[wallpaperID] = 1.0
                    self.downloadedWallpapers[wallpaperID] = finalURL
                    
                    // Post notification about full-res download
                    NotificationCenter.default.post(name: .fullResDownloadCompleted, object: nil, userInfo: [
                        "wallpaperID": wallpaperID,
                        "fileSize": fileSize,
                        "message": "Downloaded full-resolution file successfully!"
                    ])
                }
            }
            
            // Save to user defaults for persistence
            saveDownloadedWallpapers()
            
            return .success(finalURL)
            
        } catch {
            print("[WallpaperDownloadManager] Failed to move downloaded file: \(error)")
            DispatchQueue.main.async {
                self.downloadStatus[wallpaperID] = .failed
            }
            return .failure(error)
        }
    }
    
    private func determineFileExtension(from response: URLResponse?, fallbackURL: URL) -> String {
        // Try to get extension from response MIME type
        if let httpResponse = response as? HTTPURLResponse,
           let mimeType = httpResponse.mimeType {
            switch mimeType {
            case "image/jpeg": return "jpg"
            case "image/png": return "png"
            case "image/gif": return "gif"
            case "image/webp": return "webp"
            case "image/bmp": return "bmp"
            case "image/tiff": return "tiff"
            default: break
            }
        }
        
        // Fallback to URL extension
        let urlExtension = fallbackURL.pathExtension.lowercased()
        return urlExtension.isEmpty ? "jpg" : urlExtension
    }
    
    // MARK: - Desktop Wallpaper Management
    
    /// Sets the downloaded wallpaper as the desktop background
    func setDesktopWallpaper(_ imageURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        print("[WallpaperDownloadManager] Setting desktop wallpaper: \(imageURL.path)")
        
        DispatchQueue.main.async {
            do {
                // Get the current screen
                guard let screen = NSScreen.main else {
                    completion(.failure(WallpaperDownloadError.noMainScreen))
                    return
                }
                
                // Set the wallpaper using NSWorkspace
                try NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: [:])
                
                print("[WallpaperDownloadManager] ✅ Desktop wallpaper set successfully")
                completion(.success(()))
                
            } catch {
                print("[WallpaperDownloadManager] Failed to set desktop wallpaper: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - File Management
    
    /// Loads existing downloads from user defaults
    private func loadExistingDownloads() {
        let defaults = UserDefaults.standard
        if let savedDownloads = defaults.object(forKey: "downloadedWallpapers") as? [String: String] {
            for (id, path) in savedDownloads {
                let url = URL(fileURLWithPath: path)
                if fileManager.fileExists(atPath: url.path) {
                    downloadedWallpapers[id] = url
                    downloadStatus[id] = .completed
                    downloadProgress[id] = 1.0
                }
            }
        }
        
        print("[WallpaperDownloadManager] Loaded \(downloadedWallpapers.count) existing downloads")
    }
    
    /// Saves downloaded wallpapers to user defaults
    private func saveDownloadedWallpapers() {
        let defaults = UserDefaults.standard
        let pathDict = downloadedWallpapers.mapValues { $0.path }
        defaults.set(pathDict, forKey: "downloadedWallpapers")
    }
    
    /// Cancels a download in progress
    func cancelDownload(for wallpaperID: String) {
        downloadTasks[wallpaperID]?.cancel()
        downloadTasks.removeValue(forKey: wallpaperID)
        
        DispatchQueue.main.async {
            self.downloadStatus[wallpaperID] = .notStarted
            self.downloadProgress[wallpaperID] = 0.0
        }
    }
    
    /// Deletes a downloaded wallpaper
    func deleteDownload(for wallpaperID: String) {
        guard let fileURL = downloadedWallpapers[wallpaperID] else { return }
        
        do {
            try fileManager.removeItem(at: fileURL)
            downloadedWallpapers.removeValue(forKey: wallpaperID)
            downloadStatus.removeValue(forKey: wallpaperID)
            downloadProgress.removeValue(forKey: wallpaperID)
            saveDownloadedWallpapers()
            print("[WallpaperDownloadManager] Deleted download: \(fileURL.path)")
        } catch {
            print("[WallpaperDownloadManager] Failed to delete download: \(error)")
        }
    }
    
    /// Gets the local file URL for a wallpaper if it exists
    func getLocalFileURL(for wallpaperID: String) -> URL? {
        return downloadedWallpapers[wallpaperID]
    }
    
    /// Checks if a downloaded file is likely a preview (small file size)
    func isLikelyPreviewFile(for wallpaperID: String) -> Bool {
        guard let fileURL = downloadedWallpapers[wallpaperID] else { return false }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            return fileSize < 2_000_000 // Less than 2MB is likely a preview
        } catch {
            return false
        }
    }
    
    /// Gets a user-friendly explanation of why files are small
    func getDownloadExplanation(for wallpaperID: String) -> String? {
        if isLikelyPreviewFile(for: wallpaperID) {
            return "This is a preview image from Steam's API. To get the full-resolution version, subscribe to this wallpaper in Steam Workshop."
        }
        return nil
    }
    
    /// Checks if a wallpaper is downloaded
    func isWallpaperDownloaded(_ wallpaperID: String) -> Bool {
        guard let fileURL = downloadedWallpapers[wallpaperID] else { return false }
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Gets download progress for a wallpaper
    func getDownloadProgress(for wallpaperID: String) -> Double {
        return downloadProgress[wallpaperID] ?? 0.0
    }
    
    /// Gets download status for a wallpaper
    func getDownloadStatus(for wallpaperID: String) -> WallpaperModel.DownloadStatus {
        return downloadStatus[wallpaperID] ?? .notStarted
    }
}

// MARK: - URLSessionDownloadDelegate
extension WallpaperDownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        // Find the wallpaper ID for this task
        let taskIdentifier = downloadTask.taskIdentifier
        let wallpaperID = downloadTasks.first { $0.value.taskIdentifier == taskIdentifier }?.key
        
        guard let wallpaperID = wallpaperID else { return }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        DispatchQueue.main.async {
            self.downloadProgress[wallpaperID] = progress
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // This is handled in the completion handler
    }
}

// MARK: - Error Types
enum WallpaperDownloadError: Error, LocalizedError {
    case noTempURL
    case noMainScreen
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .noTempURL:
            return "No temporary URL provided for download"
        case .noMainScreen:
            return "No main screen available for setting wallpaper"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
} 