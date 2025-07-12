import Foundation

// MARK: - Sorting Options
enum SortOption: String, CaseIterable {
    case dateNewest = "Newest First"
    case dateOldest = "Oldest First"
    case popularityHigh = "Most Popular"
    case popularityLow = "Least Popular"
    case downloadsHigh = "Most Downloaded"
    case downloadsLow = "Least Downloaded"
    case nameAZ = "Name (A-Z)"
    case nameZA = "Name (Z-A)"
    case sizeSmall = "Size (Small to Large)"
    case sizeLarge = "Size (Large to Small)"
    
    var systemImage: String {
        switch self {
        case .dateNewest, .dateOldest:
            return "calendar"
        case .popularityHigh, .popularityLow:
            return "star.fill"
        case .downloadsHigh, .downloadsLow:
            return "arrow.down.circle.fill"
        case .nameAZ, .nameZA:
            return "textformat"
        case .sizeSmall, .sizeLarge:
            return "doc.fill"
        }
    }
    
    var isAscending: Bool {
        switch self {
        case .dateOldest, .popularityLow, .downloadsLow, .nameAZ, .sizeSmall:
            return true
        case .dateNewest, .popularityHigh, .downloadsHigh, .nameZA, .sizeLarge:
            return false
        }
    }
}

// MARK: - Sorting State Manager
class SortingStateManager: ObservableObject {
    @Published var currentSortOption: SortOption = .dateNewest
    
    func sortWallpapers(_ wallpapers: [Wallpaper]) -> [Wallpaper] {
        switch currentSortOption {
        case .dateNewest:
            // For now, we'll use the ID as a proxy for creation date (newer IDs = newer items)
            return wallpapers.sorted { $0.id > $1.id }
            
        case .dateOldest:
            return wallpapers.sorted { $0.id < $1.id }
            
        case .popularityHigh:
            // Note: Using title length as a proxy for popularity data
            return wallpapers.sorted { $0.title.count > $1.title.count }
            
        case .popularityLow:
            return wallpapers.sorted { $0.title.count < $1.title.count }
            
        case .downloadsHigh:
            // We don't have download count data, so we'll use file size as a proxy
            return wallpapers.sorted { ($0.fileSize ?? 0) > ($1.fileSize ?? 0) }
            
        case .downloadsLow:
            return wallpapers.sorted { ($0.fileSize ?? 0) < ($1.fileSize ?? 0) }
            
        case .nameAZ:
            return wallpapers.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            
        case .nameZA:
            return wallpapers.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
            
        case .sizeSmall:
            return wallpapers.sorted { ($0.fileSize ?? 0) < ($1.fileSize ?? 0) }
            
        case .sizeLarge:
            return wallpapers.sorted { ($0.fileSize ?? 0) > ($1.fileSize ?? 0) }
        }
    }
}