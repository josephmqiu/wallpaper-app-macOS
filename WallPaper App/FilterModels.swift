import Foundation

// MARK: - Filter Categories
enum FilterCategory: String, CaseIterable {
    case fileType = "File Type"
    case resolution = "Resolution"
    case aspectRatio = "Aspect Ratio"
    case ageRating = "Age Rating"
    case tags = "Tags"
    
    var systemImage: String {
        switch self {
        case .fileType:
            return "doc.fill"
        case .resolution:
            return "aspectratio"
        case .aspectRatio:
            return "rectangle.portrait"
        case .ageRating:
            return "person.fill"
        case .tags:
            return "tag.fill"
        }
    }
}

// MARK: - Filter Options
struct FilterOption: Identifiable, Hashable {
    let id = UUID()
    let category: FilterCategory
    let value: String
    let displayName: String
    
    init(category: FilterCategory, value: String, displayName: String? = nil) {
        self.category = category
        self.value = value
        self.displayName = displayName ?? value
    }
}

// MARK: - Predefined Filter Options
struct FilterOptions {
    static let fileTypes = [
        FilterOption(category: .fileType, value: "image", displayName: "Image"),
        FilterOption(category: .fileType, value: "video", displayName: "Video"),
        FilterOption(category: .fileType, value: "gif", displayName: "GIF")
    ]
    
    static let resolutions = [
        FilterOption(category: .resolution, value: "1920x1080", displayName: "1080p (1920×1080)"),
        FilterOption(category: .resolution, value: "2560x1440", displayName: "1440p (2560×1440)"),
        FilterOption(category: .resolution, value: "3840x2160", displayName: "4K (3840×2160)"),
        FilterOption(category: .resolution, value: "5120x2880", displayName: "5K (5120×2880)"),
        FilterOption(category: .resolution, value: "7680x4320", displayName: "8K (7680×4320)")
    ]
    
    static let aspectRatios = [
        FilterOption(category: .aspectRatio, value: "16:9", displayName: "16:9 (Widescreen)"),
        FilterOption(category: .aspectRatio, value: "21:9", displayName: "21:9 (Ultrawide)"),
        FilterOption(category: .aspectRatio, value: "4:3", displayName: "4:3 (Standard)"),
        FilterOption(category: .aspectRatio, value: "1:1", displayName: "1:1 (Square)"),
        FilterOption(category: .aspectRatio, value: "9:16", displayName: "9:16 (Portrait)")
    ]
    
    static let ageRatings = [
        FilterOption(category: .ageRating, value: "everyone", displayName: "Everyone"),
        FilterOption(category: .ageRating, value: "questionable", displayName: "Questionable"),
        FilterOption(category: .ageRating, value: "mature", displayName: "Mature")
    ]
}

// MARK: - Filter State Manager
class FilterStateManager: ObservableObject {
    @Published var selectedFilters: Set<FilterOption> = []
    @Published var expandedCategories: Set<FilterCategory> = []
    
    func isFilterSelected(_ filter: FilterOption) -> Bool {
        selectedFilters.contains(filter)
    }
    
    func toggleFilter(_ filter: FilterOption) {
        if selectedFilters.contains(filter) {
            selectedFilters.remove(filter)
        } else {
            // For some categories, only allow one selection at a time
            if filter.category == .fileType || filter.category == .resolution || filter.category == .aspectRatio {
                // Remove other filters from the same category
                selectedFilters = selectedFilters.filter { $0.category != filter.category }
            }
            selectedFilters.insert(filter)
        }
    }
    
    func clearFilters(for category: FilterCategory? = nil) {
        if let category = category {
            selectedFilters = selectedFilters.filter { $0.category != category }
        } else {
            selectedFilters.removeAll()
        }
    }
    
    func getSelectedFilters(for category: FilterCategory) -> [FilterOption] {
        return selectedFilters.filter { $0.category == category }.sorted { $0.displayName < $1.displayName }
    }
    
    func hasActiveFilters(for category: FilterCategory) -> Bool {
        return selectedFilters.contains { $0.category == category }
    }
    
    func toggleCategoryExpansion(_ category: FilterCategory) {
        if expandedCategories.contains(category) {
            expandedCategories.remove(category)
        } else {
            expandedCategories.insert(category)
        }
    }
    
    func isCategoryExpanded(_ category: FilterCategory) -> Bool {
        return expandedCategories.contains(category)
    }
}