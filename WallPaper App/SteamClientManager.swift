import Foundation
import AppKit

// MARK: - Steam Client Manager
class SteamClientManager: ObservableObject {
    @Published var isClientDetected = false
    @Published var steamPath: URL?
    @Published var workshopPath: URL?
    @Published var isClientRunning = false
    @Published var detectedWallpaperEngine: WallpaperEngine?
    
    // Supported wallpaper engines
    enum WallpaperEngine: String, CaseIterable {
        case wallpaperEngine = "431960"    // Paid Wallpaper Engine
        case screenplay = "672870"         // Free ScreenPlay
        case wallpaperAlive = "2003310"    // Free Wallpaper Alive
        
        var name: String {
            switch self {
            case .wallpaperEngine: return "Wallpaper Engine"
            case .screenplay: return "ScreenPlay"
            case .wallpaperAlive: return "Wallpaper Alive"
            }
        }
        
        var isFree: Bool {
            switch self {
            case .wallpaperEngine: return false
            case .screenplay, .wallpaperAlive: return true
            }
        }
    }
    
    private let fileManager = FileManager.default
    
    init() {
        print("[SteamClientManager] Initializing Steam Client Manager...")
        detectSteamClient()
        checkSteamProcess()
        print("[SteamClientManager] Initialization complete - Detected: \(isClientDetected), Running: \(isClientRunning)")
        if let engine = detectedWallpaperEngine {
            print("[SteamClientManager] Detected wallpaper engine: \(engine.name) (Free: \(engine.isFree))")
        }
    }
    
    // MARK: - Steam Client Detection
    func detectSteamClient() {
        print("[SteamClientManager] Starting Steam client detection...")
        steamPath = findSteamInstallation()
        if let steamPath = steamPath {
            isClientDetected = true
            
            // For macOS, we can access Wallpaper Engine workshop content directly
            // even though the app doesn't run on macOS
            detectedWallpaperEngine = .wallpaperEngine
            workshopPath = steamPath.appendingPathComponent("steamapps/workshop/content/\(WallpaperEngine.wallpaperEngine.rawValue)")
            
            print("[SteamClientManager] ✅ Steam detected at: \(steamPath.path)")
            print("[SteamClientManager] ✅ Using Wallpaper Engine Workshop (macOS direct access)")
            print("[SteamClientManager] ✅ Workshop path: \(workshopPath?.path ?? "Not found")")
            print("[SteamClientManager] ℹ️ Note: Wallpaper Engine app not required on macOS - accessing workshop content directly")
        } else {
            isClientDetected = false
            print("[SteamClientManager] ❌ Steam client not detected")
        }
    }
    
    private func findSteamInstallation() -> URL? {
        // Common Steam installation paths on macOS
        let possiblePaths = [
            // Standard Steam installation
            "~/Library/Application Support/Steam",
            // Alternative installation paths
            "/Applications/Steam.app/Contents/MacOS",
            "~/Applications/Steam.app/Contents/MacOS",
            // Steam installed via Homebrew
            "/usr/local/Caskroom/steam/latest/Steam.app/Contents/MacOS"
        ]
        
        for path in possiblePaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath)
            
            // Check for Steam application
            if path.contains("Steam.app") {
                if fileManager.fileExists(atPath: url.path) {
                    // Return the Steam data directory instead
                    let steamDataPath = NSString(string: "~/Library/Application Support/Steam").expandingTildeInPath
                    return URL(fileURLWithPath: steamDataPath)
                }
            } else {
                // Check for Steam data directory
                if fileManager.fileExists(atPath: url.path) {
                    return url
                }
            }
        }
        
        return nil
    }
    
    private func detectWallpaperEngine(steamPath: URL) -> WallpaperEngine? {
        print("[SteamClientManager] Detecting installed wallpaper engines...")
        
        // Check for installed wallpaper engines in order of preference (free first)
        for engine in [WallpaperEngine.wallpaperAlive, WallpaperEngine.screenplay, WallpaperEngine.wallpaperEngine] {
            let workshopPath = steamPath.appendingPathComponent("steamapps/workshop/content/\(engine.rawValue)")
            let commonPath = steamPath.appendingPathComponent("steamapps/common")
            
            // Check if workshop directory exists (indicates the app was installed and used)
            if fileManager.fileExists(atPath: workshopPath.path) {
                print("[SteamClientManager] ✅ Found workshop content for \(engine.name)")
                return engine
            }
            
            // Check for app installation in common directory
            do {
                let commonContents = try fileManager.contentsOfDirectory(atPath: commonPath.path)
                let engineFolderNames = getAppFolderNames(for: engine)
                
                for folderName in engineFolderNames {
                    if commonContents.contains(folderName) {
                        print("[SteamClientManager] ✅ Found installed \(engine.name) at common/\(folderName)")
                        return engine
                    }
                }
            } catch {
                print("[SteamClientManager] Could not check common directory: \(error)")
            }
        }
        
        print("[SteamClientManager] ❌ No wallpaper engines detected")
        return nil
    }
    
    private func getAppFolderNames(for engine: WallpaperEngine) -> [String] {
        switch engine {
        case .wallpaperEngine:
            return ["wallpaper_engine", "Wallpaper Engine"]
        case .screenplay:
            return ["ScreenPlay", "screenplay"]
        case .wallpaperAlive:
            return ["Wallpaper Alive", "wallpaper_alive"]
        }
    }
    
    // MARK: - Steam Process Detection
    func checkSteamProcess() {
        print("[SteamClientManager] Starting Steam process detection...")
        
        // Method 1: Try to check if Steam files are being accessed (indicating it's running)
        let steamRunningCheck1 = checkSteamFilesInUse()
        
        // Method 2: Try to check Steam app bundle process
        let steamRunningCheck2 = checkSteamAppRunning()
        
        // Method 3: Fallback to process execution if sandbox allows
        let steamRunningCheck3 = checkSteamProcesses()
        
        isClientRunning = steamRunningCheck1 || steamRunningCheck2 || steamRunningCheck3
        
        print("[SteamClientManager] Steam process detection results:")
        print("   File access check: \(steamRunningCheck1)")
        print("   App running check: \(steamRunningCheck2)")
        print("   Process check: \(steamRunningCheck3)")
        print("   Final result: \(isClientRunning)")
    }
    
    private func checkSteamFilesInUse() -> Bool {
        // Check if Steam lock files exist (indicating Steam is running)
        guard let steamPath = steamPath else { return false }
        
        let lockFiles = [
            steamPath.appendingPathComponent("steam.pid"),
            steamPath.appendingPathComponent("config/loginusers.vdf"),
            steamPath.appendingPathComponent("logs")
        ]
        
        for lockFile in lockFiles {
            if fileManager.fileExists(atPath: lockFile.path) {
                // Check if file was recently modified (within last 5 minutes)
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: lockFile.path)
                    if let modDate = attributes[.modificationDate] as? Date {
                        let timeSinceModification = Date().timeIntervalSince(modDate)
                        if timeSinceModification < 300 { // 5 minutes
                            print("[SteamClientManager] Found recently modified Steam file: \(lockFile.lastPathComponent)")
                            return true
                        }
                    }
                } catch {
                    // File exists but can't read attributes - assume Steam is running
                    return true
                }
            }
        }
        
        return false
    }
    
    private func checkSteamAppRunning() -> Bool {
        // Use NSWorkspace to check running applications
        let runningApps = NSWorkspace.shared.runningApplications
        
        for app in runningApps {
            if let bundleId = app.bundleIdentifier {
                if bundleId.contains("steam") || bundleId.contains("Steam") {
                    print("[SteamClientManager] Found Steam app via NSWorkspace: \(bundleId)")
                    return true
                }
            }
            
            if let appName = app.localizedName {
                if appName.lowercased().contains("steam") {
                    print("[SteamClientManager] Found Steam app by name: \(appName)")
                    return true
                }
            }
        }
        
        return false
    }
    
    private func checkSteamProcesses() -> Bool {
        // Fallback: try to execute ps command (might fail in sandbox)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["ax"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            print("[SteamClientManager] Process command output length: \(output.count) characters")
            
            if output.count > 0 {
                let steamProcesses = ["steam_osx", "Steam Helper", "Steam.AppBundle", "steamwebhelper"]
                
                for processName in steamProcesses {
                    if output.contains(processName) {
                        print("[SteamClientManager] Found Steam process via ps command: \(processName)")
                        return true
                    }
                }
            }
            
        } catch {
            print("[SteamClientManager] Process command failed (likely sandbox restriction): \(error)")
        }
        
        return false
    }
    
    // MARK: - Workshop Content Management
    func getLocalWorkshopItemPath(itemID: String) -> URL? {
        guard let workshopPath = workshopPath else { return nil }
        
        let itemPath = workshopPath.appendingPathComponent(itemID)
        
        if fileManager.fileExists(atPath: itemPath.path) {
            return itemPath
        }
        
        return nil
    }
    
    func findWorkshopItemFiles(itemID: String) -> [URL] {
        guard let itemPath = getLocalWorkshopItemPath(itemID: itemID) else { return [] }
        
        var files: [URL] = []
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: itemPath, includingPropertiesForKeys: nil)
            
            // Look for common wallpaper file types
            let imageExtensions = ["jpg", "jpeg", "png", "bmp", "tiff", "webp", "gif"]
            let videoExtensions = ["mp4", "avi", "mov", "wmv", "flv", "webm"]
            let allExtensions = imageExtensions + videoExtensions
            
            for url in contents {
                let ext = url.pathExtension.lowercased()
                if allExtensions.contains(ext) {
                    files.append(url)
                }
            }
            
            // Sort by file size (largest first) to get the highest quality version
            files.sort { url1, url2 in
                let size1 = (try? url1.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                let size2 = (try? url2.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return size1 > size2
            }
            
        } catch {
            print("[SteamClientManager] Error reading workshop item directory: \(error)")
        }
        
        return files
    }
    
    func getHighResolutionImageURL(for itemID: String) -> URL? {
        let files = findWorkshopItemFiles(itemID: itemID)
        
        // Return the first (largest) image file
        return files.first { url in
            let ext = url.pathExtension.lowercased()
            return ["jpg", "jpeg", "png", "bmp", "tiff", "webp"].contains(ext)
        }
    }
    
    // MARK: - Subscription Management
    func subscribeToWorkshopItem(itemID: String) async -> Bool {
        guard isClientRunning else {
            print("[SteamClientManager] Cannot subscribe - Steam client not running")
            return false
        }
        
        print("[SteamClientManager] Attempting to subscribe to workshop item: \(itemID)")
        
        // On macOS, we can trigger Steam to download workshop content directly
        // by subscribing through the Steam Workshop URL
        let steamURL = "steam://url/CommunityFilePage/\(itemID)"
        
        if let url = URL(string: steamURL) {
            await MainActor.run {
                NSWorkspace.shared.open(url)
            }
            
            print("[SteamClientManager] Opened Steam workshop page for item: \(itemID)")
            print("[SteamClientManager] ℹ️ macOS Note: After subscribing, Steam will download the content automatically")
            print("[SteamClientManager] ℹ️ Files will be available at: \(workshopPath?.appendingPathComponent(itemID).path ?? "workshop path")")
            
            return true
        }
        
        print("[SteamClientManager] Failed to create Steam URL for item: \(itemID)")
        return false
    }
    
    func openSteamWorkshopPage(itemID: String) {
        let steamURL = "steam://url/CommunityFilePage/\(itemID)"
        
        if let url = URL(string: steamURL) {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback to web URL
            let webURL = "https://steamcommunity.com/sharedfiles/filedetails/?id=\(itemID)"
            if let url = URL(string: webURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    // MARK: - Steam Client Launch
    func launchSteamClient() -> Bool {
        // Try to launch Steam using various methods
        let steamPaths = [
            "/Applications/Steam.app",
            "~/Applications/Steam.app"
        ]
        
        for path in steamPaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath)
            
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                    print("[SteamClientManager] Successfully launched Steam from: \(url.path)")
                    
                    // Wait a moment for Steam to start
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.checkSteamProcess()
                    }
                    
                    return true
                } catch {
                    print("[SteamClientManager] Failed to launch Steam from \(url.path): \(error)")
                }
            }
        }
        
        // Try using open command as fallback
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", "Steam"]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                print("[SteamClientManager] Successfully launched Steam using open command")
                
                // Wait a moment for Steam to start
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.checkSteamProcess()
                }
                
                return true
            }
        } catch {
            print("[SteamClientManager] Failed to launch Steam using open command: \(error)")
        }
        
        return false
    }
    
    func installSteam() {
        // Open Steam download page
        let steamDownloadURL = "https://store.steampowered.com/about/"
        if let url = URL(string: steamDownloadURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Utility Methods
    func refreshWorkshopContent() {
        detectSteamClient()
        checkSteamProcess()
    }
    
    func getWorkshopItemInfo(itemID: String) -> WorkshopItemInfo? {
        guard let itemPath = getLocalWorkshopItemPath(itemID: itemID) else { return nil }
        
        let files = findWorkshopItemFiles(itemID: itemID)
        
        // Only return workshop info if there are actually files in the directory
        guard !files.isEmpty else {
            print("[SteamClientManager] Workshop item \(itemID) directory exists but contains no wallpaper files")
            return nil
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: itemPath.path)
            let modificationDate = attributes[.modificationDate] as? Date
            
            let primaryImageFile = files.first { url in
                let ext = url.pathExtension.lowercased()
                return ["jpg", "jpeg", "png", "bmp", "tiff", "webp"].contains(ext)
            }
            
            let totalSize = files.reduce(Int64(0)) { total, url in
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return total + Int64(size)
            }
            
            return WorkshopItemInfo(
                itemID: itemID,
                subscribed: true,
                installed: true,
                downloadSize: totalSize,
                lastUpdated: modificationDate,
                localPath: itemPath,
                files: files,
                primaryImageFile: primaryImageFile
            )
        } catch {
            print("[SteamClientManager] Error getting item info: \(error)")
            return nil
        }
    }
}

// MARK: - Supporting Data Models
// WorkshopItemInfo is now defined as a top-level struct in WallpaperModel.swift 