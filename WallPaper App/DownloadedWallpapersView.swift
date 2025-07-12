import SwiftUI

struct DownloadedWallpapersView: View {
    @StateObject private var viewModel = DownloadedWallpapersViewModel()
    @State private var searchText = ""
    @State private var selectedWallpaper: DownloadedWallpaper?
    @State private var showingDeleteAlert = false
    @State private var wallpaperToDelete: DownloadedWallpaper?
    
    let columns = [
        GridItem(.adaptive(minimum: 180), spacing: 12)
    ]
    
    var filteredWallpapers: [DownloadedWallpaper] {
        if searchText.isEmpty {
            return viewModel.downloadedWallpapers
        } else {
            return viewModel.downloadedWallpapers.filter { wallpaper in
                wallpaper.title.localizedCaseInsensitiveContains(searchText) ||
                wallpaper.author.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with stats
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Downloaded Wallpapers")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("\(viewModel.downloadedWallpapers.count) wallpapers • \(viewModel.formattedTotalSize)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Refresh button
                    Button(action: {
                        viewModel.refreshDownloadedWallpapers()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                
                // Search bar
                HStack {
                    TextField("Search downloaded wallpapers...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding([.top, .horizontal])
                
                // Content
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading downloaded wallpapers...")
                    Spacer()
                } else if viewModel.downloadedWallpapers.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Downloaded Wallpapers")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Wallpapers you download will appear here.\nGo to Browse tab to find and download wallpapers.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else if filteredWallpapers.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Results Found")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Try searching with different keywords.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredWallpapers, id: \.id) { wallpaper in
                                NavigationLink(destination: DownloadedWallpaperDetailView(wallpaper: wallpaper)) {
                                    DownloadedWallpaperCell(
                                        wallpaper: wallpaper,
                                        onSetAsWallpaper: {
                                            viewModel.setAsDesktopWallpaper(wallpaper)
                                        },
                                        onDelete: {
                                            wallpaperToDelete = wallpaper
                                            showingDeleteAlert = true
                                        },
                                        onShowInFinder: {
                                            viewModel.showInFinder(wallpaper)
                                        }
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Downloaded")
            .onAppear {
                viewModel.loadDownloadedWallpapers()
            }
            .alert("Delete Wallpaper", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let wallpaper = wallpaperToDelete {
                        viewModel.deleteWallpaper(wallpaper)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this wallpaper? This action cannot be undone.")
            }
        }
    }
}

struct DownloadedWallpaperCell: View {
    let wallpaper: DownloadedWallpaper
    let onSetAsWallpaper: () -> Void
    let onDelete: () -> Void
    let onShowInFinder: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image
            ZStack {
                AsyncImage(url: wallpaper.fileURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        )
                }
                .frame(height: 120)
                .clipped()
                .cornerRadius(8)
                
                // Overlay with actions on hover
                if isHovered {
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .overlay(
                            HStack(spacing: 12) {
                                Button(action: onSetAsWallpaper) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "desktopcomputer")
                                            .font(.title2)
                                        Text("Set")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: onShowInFinder) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "folder")
                                            .font(.title2)
                                        Text("Show")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: onDelete) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "trash")
                                            .font(.title2)
                                        Text("Delete")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.red)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        )
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            
            // Title and info
            VStack(alignment: .leading, spacing: 2) {
                Text(wallpaper.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text("by \(wallpaper.author)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text(wallpaper.formattedFileSize)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(wallpaper.formattedDownloadDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    DownloadedWallpapersView()
} 