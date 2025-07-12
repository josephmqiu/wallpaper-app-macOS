import Foundation
import SwiftUI
import AppKit

// MARK: - Downloaded Wallpaper Model
struct DownloadedWallpaper: Identifiable, Codable {
    let id: String
    let title: String
    let author: String
    let fileURL: URL
    let downloadDate: Date
    let fileSize: Int64
    let originalWallpaperID: String?
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var formattedDownloadDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: downloadDate)
    }
}

// MARK: - Downloaded Wallpapers View Model
@MainActor
class DownloadedWallpapersViewModel: ObservableObject {
    @Published var downloadedWallpapers: [DownloadedWallpaper] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var totalSize: Int64 = 0
    
    private let fileManager = FileManager.default
    private let downloadManager = WallpaperDownloadManager()
    
    var formattedTotalSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
    
    init() {
        loadDownloadedWallpapers()
    }
    
    // MARK: - Data Loading
    
    func loadDownloadedWallpapers() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let wallpapers = try await scanDownloadedWallpapers()
                self.downloadedWallpapers = wallpapers
                self.totalSize = wallpapers.reduce(0) { $0 + $1.fileSize }
                self.isLoading = false
            } catch {
                self.errorMessage = "Failed to load downloaded wallpapers: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func refreshDownloadedWallpapers() {
        loadDownloadedWallpapers()
    }
    
    private func scanDownloadedWallpapers() async throws -> [DownloadedWallpaper] {
        let highResDirectory = downloadManager.highResDirectory
        
        // Check if directory exists
        guard fileManager.fileExists(atPath: highResDirectory.path) else {
            return []
        }
        
        do {
            // Get all files in the directory
            let contents = try fileManager.contentsOfDirectory(at: highResDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: [.skipsHiddenFiles])
            
            var wallpapers: [DownloadedWallpaper] = []
            
            for fileURL in contents {
                // Skip non-image files
                guard isImageFile(fileURL) else { continue }
                
                do {
                    // Get file attributes
                    let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    let creationDate = attributes[.creationDate] as? Date ?? Date()
                    
                    // Parse filename to extract wallpaper info
                    let fileName = fileURL.deletingPathExtension().lastPathComponent
                    let (id, title, author) = parseFileName(fileName)
                    
                    let wallpaper = DownloadedWallpaper(
                        id: id,
                        title: title,
                        author: author,
                        fileURL: fileURL,
                        downloadDate: creationDate,
                        fileSize: fileSize,
                        originalWallpaperID: id
                    )
                    
                    wallpapers.append(wallpaper)
                } catch {
                    print("[DownloadedWallpapersViewModel] Failed to get attributes for file: \(fileURL.path), error: \(error)")
                    continue
                }
            }
            
            // Sort by download date (newest first)
            return wallpapers.sorted { $0.downloadDate > $1.downloadDate }
        } catch {
            print("[DownloadedWallpapersViewModel] Failed to scan directory: \(highResDirectory.path), error: \(error)")
            throw error
        }
    }
    
    private func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff", "heic", "heif"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func parseFileName(_ fileName: String) -> (id: String, title: String, author: String) {
        // Expected format: "ID_Title_by_Author" or "ID_Title"
        let components = fileName.components(separatedBy: "_")
        
        if components.count >= 2 {
            let id = components[0]
            let title = components[1].replacingOccurrences(of: "_", with: " ")
            let author = components.count > 2 ? components[2...].joined(separator: " ").replacingOccurrences(of: "_", with: " ") : "Unknown"
            return (id, title, author)
        } else {
            // Fallback for unexpected format
            return (fileName, fileName, "Unknown")
        }
    }
    
    // MARK: - Wallpaper Actions
    
    func setAsDesktopWallpaper(_ wallpaper: DownloadedWallpaper) {
        print("[DownloadedWallpapersViewModel] Setting wallpaper as desktop: \(wallpaper.title)")
        
        downloadManager.setDesktopWallpaper(wallpaper.fileURL) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("[DownloadedWallpapersViewModel] ✅ Desktop wallpaper set successfully")
                    // Could show a success message here
                case .failure(let error):
                    print("[DownloadedWallpapersViewModel] ❌ Failed to set desktop wallpaper: \(error)")
                    self.errorMessage = "Failed to set wallpaper: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func deleteWallpaper(_ wallpaper: DownloadedWallpaper) {
        print("[DownloadedWallpapersViewModel] Deleting wallpaper: \(wallpaper.title)")
        
        do {
            try fileManager.removeItem(at: wallpaper.fileURL)
            
            // Remove from local array
            downloadedWallpapers.removeAll { $0.id == wallpaper.id }
            
            // Update total size
            totalSize -= wallpaper.fileSize
            
            // Also remove from download manager's tracking
            if let originalID = wallpaper.originalWallpaperID {
                downloadManager.deleteDownload(for: originalID)
            }
            
            print("[DownloadedWallpapersViewModel] ✅ Wallpaper deleted successfully")
            
        } catch {
            print("[DownloadedWallpapersViewModel] ❌ Failed to delete wallpaper: \(error)")
            errorMessage = "Failed to delete wallpaper: \(error.localizedDescription)"
        }
    }
    
    func showInFinder(_ wallpaper: DownloadedWallpaper) {
        print("[DownloadedWallpapersViewModel] Showing wallpaper in Finder: \(wallpaper.title)")
        NSWorkspace.shared.activateFileViewerSelecting([wallpaper.fileURL])
    }
    
    // MARK: - Utility Methods
    
    func getWallpaperInfo(_ wallpaper: DownloadedWallpaper) -> String {
        var info = "File: \(wallpaper.fileURL.lastPathComponent)\n"
        info += "Size: \(wallpaper.formattedFileSize)\n"
        info += "Downloaded: \(wallpaper.formattedDownloadDate)\n"
        info += "Path: \(wallpaper.fileURL.path)"
        return info
    }
    
    func exportWallpaper(_ wallpaper: DownloadedWallpaper, to destinationURL: URL) throws {
        try fileManager.copyItem(at: wallpaper.fileURL, to: destinationURL)
        print("[DownloadedWallpapersViewModel] ✅ Wallpaper exported to: \(destinationURL.path)")
    }
    
    func getTotalWallpaperCount() -> Int {
        return downloadedWallpapers.count
    }
    
    func getWallpapersByDate() -> [String: [DownloadedWallpaper]] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: downloadedWallpapers) { wallpaper in
            calendar.dateInterval(of: .day, for: wallpaper.downloadDate)?.start ?? wallpaper.downloadDate
        }
        
        return grouped.mapKeys { date in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

// MARK: - Dictionary Extension
extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        return Dictionary<T, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
} 