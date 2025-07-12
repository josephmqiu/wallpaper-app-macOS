import Foundation

@MainActor
class WallpaperViewModel: ObservableObject {
    @Published var wallpapers: [Wallpaper] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var searchText: String = ""
    @Published var selectedTags: Set<String> = []
    @Published var canLoadMore = true
    @Published var steamClientStatus: String = "Checking..."
    @Published var localContentAvailable = false
    @Published var needsApiToken = false
    
    // Filter and Sorting Management
    @Published var filterManager = FilterStateManager()
    @Published var sortingManager = SortingStateManager()
    
    // Download management
    @Published var downloadManager = WallpaperDownloadManager()
    
    private let apiService = SteamAPIService()
    private var cursor: String = "*"
    private var lastQuery: (String, Set<String>) = ("", [])
    private var searchTask: Task<Void, Never>?
    
    var steamClientManager: SteamClientManager {
        return apiService.getSteamClientManager()
    }
    
    init() {
        setupSteamClientMonitoring()
    }
    
    private func setupSteamClientMonitoring() {
        // Monitor Steam client status
        Task {
            await updateSteamClientStatus()
            
            // Set up periodic monitoring
            while true {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                await updateSteamClientStatus()
            }
        }
    }
    
    private func updateSteamClientStatus() async {
        let manager = steamClientManager
        
        // Force refresh the steam client state
        manager.detectSteamClient()
        manager.checkSteamProcess()
        
        print("[WallpaperViewModel] Steam detected: \(manager.isClientDetected), running: \(manager.isClientRunning)")
        
        if manager.isClientDetected && manager.isClientRunning {
            steamClientStatus = "Steam Connected - Wallpaper Engine Workshop Access"
            localContentAvailable = true
        } else if manager.isClientDetected {
            steamClientStatus = "Steam Detected (Not Running)"
            localContentAvailable = false
        } else {
            steamClientStatus = "Steam Not Found"
            localContentAvailable = false
        }
        
        print("[WallpaperViewModel] Status updated to: \(steamClientStatus)")
    }
    
    var allTags: [String] {
        let tagSet = Set(wallpapers.flatMap { $0.tags.map { $0.tag } })
        return Array(tagSet).sorted()
    }
    
    var filteredWallpapers: [Wallpaper] {
        let filtered = wallpapers.filter { wallpaper in
            // Search text filter
            let matchesSearch = searchText.isEmpty || wallpaper.title.localizedCaseInsensitiveContains(searchText)
            
            // Apply category filters
            let selectedFilters = filterManager.selectedFilters
            var matchesFilters = true
            
            // File type filter
            let fileTypeFilters = selectedFilters.filter { $0.category == .fileType }
            if !fileTypeFilters.isEmpty {
                matchesFilters = matchesFilters && fileTypeFilters.contains { $0.value == wallpaper.contentType.rawValue }
            }
            
            // Resolution filter
            let resolutionFilters = selectedFilters.filter { $0.category == .resolution }
            if !resolutionFilters.isEmpty {
                if let width = wallpaper.width, let height = wallpaper.height {
                    let resolution = "\(width)x\(height)"
                    matchesFilters = matchesFilters && resolutionFilters.contains { $0.value == resolution }
                } else {
                    matchesFilters = false
                }
            }
            
            // Aspect ratio filter
            let aspectRatioFilters = selectedFilters.filter { $0.category == .aspectRatio }
            if !aspectRatioFilters.isEmpty {
                let aspectRatio = aspectRatioToString(wallpaper.aspectRatio)
                matchesFilters = matchesFilters && aspectRatioFilters.contains { $0.value == aspectRatio }
            }
            
            // Tags filter (both old selected tags and new tag filters)
            let tagFilters = selectedFilters.filter { $0.category == .tags }
            let combinedTags = selectedTags.union(Set(tagFilters.map { $0.value }))
            if !combinedTags.isEmpty {
                matchesFilters = matchesFilters && !combinedTags.isDisjoint(with: wallpaper.tags.map { $0.tag })
            }
            
            return matchesSearch && matchesFilters
        }
        
        // Apply sorting
        return sortingManager.sortWallpapers(filtered)
    }
    
    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    func loadWallpapers(reset: Bool = true) async {
        if isLoading { return }
        isLoading = true
        errorMessage = nil
        needsApiToken = false
        
        if reset {
            cursor = "*"
            canLoadMore = true
            wallpapers = []
        }
        do {
            let (items, nextCursor) = try await apiService.fetchWallpapers(cursor: cursor, searchText: searchText, tags: Array(selectedTags))
            if reset {
                wallpapers = items
            } else {
                wallpapers += items
            }
            cursor = nextCursor ?? ""
            canLoadMore = (nextCursor != nil && !items.isEmpty)
        } catch {
            let nsError = error as NSError
            if nsError.domain == "SteamAPIService" && nsError.code == 401 {
                needsApiToken = true
                self.errorMessage = nil // Don't show error, show token input instead
            } else {
                self.errorMessage = "Error fetching wallpapers: \(error.localizedDescription)"
            }
        }
        isLoading = false
    }
    
    func loadMoreWallpapers() async {
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let (items, nextCursor) = try await apiService.fetchWallpapers(cursor: cursor, searchText: searchText, tags: Array(selectedTags))
            wallpapers += items
            cursor = nextCursor ?? ""
            canLoadMore = (nextCursor != nil && !items.isEmpty)
        } catch {
            self.errorMessage = "Error loading more wallpapers: \(error.localizedDescription)"
        }
        isLoadingMore = false
    }
    
    func debouncedSearch() async {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            await loadWallpapers(reset: true)
        }
    }
    
    func performSearch() async {
        searchTask?.cancel()
        searchTask = Task {
            await loadWallpapers(reset: true)
        }
    }
    
    // MARK: - Steam Client Integration
    func subscribeToWallpaper(_ wallpaper: Wallpaper) async -> Bool {
        return await apiService.subscribeToWallpaper(wallpaper)
    }
    
    func openWallpaperInSteam(_ wallpaper: Wallpaper) {
        apiService.openWallpaperInSteam(wallpaper)
    }
    
    func refreshLocalContent() {
        apiService.refreshLocalContent()
        Task {
            await updateSteamClientStatus()
            await loadWallpapers(reset: true)
        }
    }
    
    func getLocalContentInfo() -> (total: Int, available: Int) {
        let total = wallpapers.count
        let available = wallpapers.filter { $0.isLocallyAvailable }.count
        return (total, available)
    }
    
    func launchSteamClient() -> Bool {
        return apiService.launchSteamClient()
    }
    
    func installSteam() {
        apiService.installSteam()
    }
    
    // MARK: - Wallpaper Engine Information
    func getWallpaperEngineInfo() -> (name: String, isFree: Bool, isInstalled: Bool) {
        return ("Wallpaper Engine Workshop (Direct Access)", false, true)
    }
    
    func getMacOSInfo() -> String {
        return "macOS can access Wallpaper Engine workshop content directly through Steam"
    }
    
    func getRecommendedFreeEngines() -> [String] {
        return ["ScreenPlay (Free)", "Wallpaper Alive (Free)"]
    }
    
    // MARK: - Download Management
    
    /// Downloads a wallpaper for local storage
    func downloadWallpaper(_ wallpaper: Wallpaper) {
        // Convert Steam wallpaper to WallpaperModel for download
        let wallpaperModel = WallpaperModel(
            id: wallpaper.publishedFileId,
            title: wallpaper.title,
            author: wallpaper.creatorName ?? "Unknown",
            tags: wallpaper.tags.map { $0.tag },
            previewURL: wallpaper.previewURL ?? wallpaper.fullResURL,
            fullResURL: wallpaper.fullResURL,
            isVideo: wallpaper.isVideo,
            localFilePath: nil,
            localFileSize: nil,
            downloadProgress: nil,
            downloadStatus: nil,
            workshopItemID: wallpaper.publishedFileId,
            workshopItemInfo: nil
        )
        
        downloadManager.downloadWallpaper(wallpaperModel)
    }
    
    /// Downloads and sets wallpaper as desktop background
    func downloadAndSetWallpaper(_ wallpaper: Wallpaper) {
        let wallpaperModel = WallpaperModel(
            id: wallpaper.publishedFileId,
            title: wallpaper.title,
            author: wallpaper.creatorName ?? "Unknown",
            tags: wallpaper.tags.map { $0.tag },
            previewURL: wallpaper.previewURL ?? wallpaper.fullResURL,
            fullResURL: wallpaper.fullResURL,
            isVideo: wallpaper.isVideo,
            localFilePath: nil,
            localFileSize: nil,
            downloadProgress: nil,
            downloadStatus: nil,
            workshopItemID: wallpaper.publishedFileId,
            workshopItemInfo: nil
        )
        
        downloadManager.downloadAndSetAsWallpaper(wallpaperModel) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let localURL):
                    print("[WallpaperViewModel] Successfully set wallpaper: \(localURL.path)")
                    // You could show a success message here
                case .failure(let error):
                    self.errorMessage = "Failed to set wallpaper: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Checks if a wallpaper is downloaded
    func isWallpaperDownloaded(_ wallpaper: Wallpaper) -> Bool {
        return downloadManager.isWallpaperDownloaded(wallpaper.publishedFileId)
    }
    
    /// Gets download progress for a wallpaper
    func getDownloadProgress(for wallpaper: Wallpaper) -> Double {
        return downloadManager.getDownloadProgress(for: wallpaper.publishedFileId)
    }
    
    /// Gets download status for a wallpaper
    func getDownloadStatus(for wallpaper: Wallpaper) -> WallpaperModel.DownloadStatus {
        return downloadManager.getDownloadStatus(for: wallpaper.publishedFileId)
    }
    
    /// Cancels download for a wallpaper
    func cancelDownload(for wallpaper: Wallpaper) {
        downloadManager.cancelDownload(for: wallpaper.publishedFileId)
    }
    
    /// Deletes downloaded wallpaper
    func deleteDownload(for wallpaper: Wallpaper) {
        downloadManager.deleteDownload(for: wallpaper.publishedFileId)
    }
    
    /// Gets local file URL for a wallpaper
    func getLocalFileURL(for wallpaper: Wallpaper) -> URL? {
        return downloadManager.getLocalFileURL(for: wallpaper.publishedFileId)
    }
} 