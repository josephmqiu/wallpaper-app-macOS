import SwiftUI

struct FilterView: View {
    @ObservedObject var filterManager: FilterStateManager
    @ObservedObject var viewModel: WallpaperViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // File Type Filter
                FilterDropdown(
                    category: .fileType,
                    options: FilterOptions.fileTypes,
                    filterManager: filterManager,
                    onFilterChanged: {
                        Task { await viewModel.performSearch() }
                    }
                )
                
                // Resolution Filter
                FilterDropdown(
                    category: .resolution,
                    options: FilterOptions.resolutions,
                    filterManager: filterManager,
                    onFilterChanged: {
                        Task { await viewModel.performSearch() }
                    }
                )
                
                // Aspect Ratio Filter
                FilterDropdown(
                    category: .aspectRatio,
                    options: FilterOptions.aspectRatios,
                    filterManager: filterManager,
                    onFilterChanged: {
                        Task { await viewModel.performSearch() }
                    }
                )
                
                // Age Rating Filter
                FilterDropdown(
                    category: .ageRating,
                    options: FilterOptions.ageRatings,
                    filterManager: filterManager,
                    onFilterChanged: {
                        Task { await viewModel.performSearch() }
                    }
                )
                
                // Tags Filter (dynamic based on loaded wallpapers)
                let tagOptions = viewModel.allTags.map { tag in
                    FilterOption(category: .tags, value: tag)
                }
                if !tagOptions.isEmpty {
                    FilterDropdown(
                        category: .tags,
                        options: tagOptions,
                        filterManager: filterManager,
                        onFilterChanged: {
                            Task { await viewModel.performSearch() }
                        }
                    )
                }
                
                // Clear All Filters
                if !filterManager.selectedFilters.isEmpty {
                    Button(action: {
                        filterManager.clearFilters()
                        Task { await viewModel.performSearch() }
                    }) {
                        Label("Clear All", systemImage: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Filter Dropdown Component
struct FilterDropdown: View {
    let category: FilterCategory
    let options: [FilterOption]
    @ObservedObject var filterManager: FilterStateManager
    let onFilterChanged: () -> Void
    
    @State private var isExpanded = false
    
    var selectedCount: Int {
        filterManager.getSelectedFilters(for: category).count
    }
    
    var body: some View {
        Menu {
            ForEach(options, id: \.id) { option in
                Button(action: {
                    filterManager.toggleFilter(option)
                    onFilterChanged()
                }) {
                    HStack {
                        Text(option.displayName)
                        if filterManager.isFilterSelected(option) {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            
            if filterManager.hasActiveFilters(for: category) {
                Divider()
                Button("Clear \(category.rawValue)") {
                    filterManager.clearFilters(for: category)
                    onFilterChanged()
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: category.systemImage)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.caption)
                if selectedCount > 0 {
                    Text("(\(selectedCount))")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                }
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(filterManager.hasActiveFilters(for: category) ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(filterManager.hasActiveFilters(for: category) ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}

// MARK: - Sorting Menu
struct SortingMenu: View {
    @ObservedObject var sortingManager: SortingStateManager
    let onSortChanged: () -> Void
    
    var body: some View {
        Menu {
            ForEach(SortOption.allCases, id: \.self) { option in
                Button(action: {
                    sortingManager.currentSortOption = option
                    onSortChanged()
                }) {
                    HStack {
                        Image(systemName: option.systemImage)
                        Text(option.rawValue)
                        if sortingManager.currentSortOption == option {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption)
                Text("Sort: \(sortingManager.currentSortOption.rawValue)")
                    .font(.caption)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}