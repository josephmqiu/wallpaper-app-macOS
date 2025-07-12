//  WallpaperGridView.swift
//  Wallpaper App
//
//  Displays a grid of wallpapers with search, tag filters, and ratio selector.
//
//  Created for MVP scaffold.

import SwiftUI

struct WallpaperGridView: View {
    @State private var searchText = ""
    @State private var selectedTags: Set<String> = []
    @State private var selectedRatio: String = "All"
    // Use mock data for MVP
    @State private var wallpapers: [WallpaperModel] = WallpaperModel.mockWallpapers
    let allTags = ["Nature", "Abstract", "Gaming", "Minimal", "Dark", "Anime", "Landscape", "City", "Night", "Forest", "Mountains", "Sunset", "Colorful", "Space", "Flowers", "Spring", "Ocean", "Water"]
    let ratios = ["All", "16:9", "4:3", "19.5:9"]
    
    // Filtered wallpapers for search and tags
    var filteredWallpapers: [WallpaperModel] {
        wallpapers.filter { wallpaper in
            (searchText.isEmpty || wallpaper.title.localizedCaseInsensitiveContains(searchText) || wallpaper.author.localizedCaseInsensitiveContains(searchText)) &&
            (selectedTags.isEmpty || !selectedTags.isDisjoint(with: wallpaper.tags))
            // Note: Ratio filtering can be added here in future updates
        }
    }
    var body: some View {
        VStack {
            // Search bar
            TextField("Search wallpapers...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding([.top, .horizontal])
            // Tag filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(allTags, id: \.self) { tag in
                        Button(action: {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        }) {
                            Text(tag)
                                .padding(8)
                                .background(selectedTags.contains(tag) ? Color.accentColor : Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(16)
                        }
                    }
                }.padding(.horizontal)
            }
            // Ratio selector
            Picker("Aspect Ratio", selection: $selectedRatio) {
                ForEach(ratios, id: \.self) { ratio in
                    Text(ratio)
                }
            }.pickerStyle(SegmentedPickerStyle())
            .padding([.horizontal, .bottom])
            // Wallpaper grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
                    ForEach(filteredWallpapers) { wallpaper in
                        NavigationLink(destination: DetailView(wallpaper: wallpaper)) {
                            WallpaperGridItemView(wallpaper: wallpaper)
                        }
                    }
                }.padding()
            }
        }
    }
}

struct WallpaperGridItemView: View {
    let wallpaper: WallpaperModel
    var body: some View {
        VStack(alignment: .leading) {
            // Use AsyncImage for preview
            AsyncImage(url: wallpaper.previewURL) { phase in
                switch phase {
                case .empty:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 100)
                case .success(let image):
                    image.resizable().aspectRatio(16/9, contentMode: .fit)
                case .failure:
                    Rectangle().fill(Color.gray.opacity(0.3)).aspectRatio(16/9, contentMode: .fit)
                @unknown default:
                    Rectangle().fill(Color.gray.opacity(0.3)).aspectRatio(16/9, contentMode: .fit)
                }
            }
            Text(wallpaper.title).font(.headline)
            Text(wallpaper.author).font(.caption).foregroundColor(.secondary)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
} 