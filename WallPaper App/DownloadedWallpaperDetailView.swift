import SwiftUI

struct DownloadedWallpaperDetailView: View {
    let wallpaper: DownloadedWallpaper
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    @State private var showingSetWallpaperAlert = false
    @State private var actionMessage: String?
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .center, spacing: 24) {
                    // Back button
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.top, 8)
                    
                    // Image preview
                    AsyncImage(url: wallpaper.fileURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: geometry.size.width * 0.8)
                            .cornerRadius(12)
                            .shadow(radius: 8)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 400)
                            .cornerRadius(12)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            )
                    }
                    
                    // Wallpaper info
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(wallpaper.title)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("by \(wallpaper.author)")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // File details
                        VStack(alignment: .leading, spacing: 8) {
                            Text("File Details")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Text("Size:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(wallpaper.formattedFileSize)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Downloaded:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(wallpaper.formattedDownloadDate)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Format:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(wallpaper.fileURL.pathExtension.uppercased())
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        // Action buttons
                        VStack(spacing: 12) {
                            Text("Actions")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Set as wallpaper button
                            Button(action: {
                                setAsDesktopWallpaper()
                            }) {
                                HStack {
                                    Image(systemName: "desktopcomputer")
                                    Text("Set as Desktop Wallpaper")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            
                            // Show in Finder button
                            Button(action: {
                                showInFinder()
                            }) {
                                HStack {
                                    Image(systemName: "folder")
                                    Text("Show in Finder")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                            }
                            
                            // Open in Steam button (if original ID is available)
                            if let originalID = wallpaper.originalWallpaperID {
                                Button(action: {
                                    openInSteam(originalID)
                                }) {
                                    HStack {
                                        Image(systemName: "link.circle.fill")
                                        Text("Open in Steam")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                                }
                            }
                            
                            // Delete button
                            Button(action: {
                                showingDeleteAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Wallpaper")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(8)
                            }
                        }
                        
                        // Action message
                        if let message = actionMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .frame(maxWidth: 600, alignment: .leading)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle(wallpaper.title)
        .alert("Delete Wallpaper", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteWallpaper()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this wallpaper? This action cannot be undone.")
        }
        .alert("Wallpaper Set", isPresented: $showingSetWallpaperAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Desktop wallpaper has been updated successfully!")
        }
    }
    
    // MARK: - Actions
    
    private func setAsDesktopWallpaper() {
        let downloadManager = WallpaperDownloadManager()
        
        downloadManager.setDesktopWallpaper(wallpaper.fileURL) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.showingSetWallpaperAlert = true
                    self.actionMessage = "Desktop wallpaper updated successfully!"
                case .failure(let error):
                    self.actionMessage = "Failed to set wallpaper: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func showInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([wallpaper.fileURL])
        actionMessage = "Wallpaper shown in Finder"
    }
    
    private func deleteWallpaper() {
        let fileManager = FileManager.default
        
        do {
            try fileManager.removeItem(at: wallpaper.fileURL)
            actionMessage = "Wallpaper deleted successfully"
            
            // Dismiss the view after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                dismiss()
            }
        } catch {
            actionMessage = "Failed to delete wallpaper: \(error.localizedDescription)"
        }
    }
    
    private func openInSteam(_ wallpaperID: String) {
        let steamClientManager = SteamClientManager()
        steamClientManager.openSteamWorkshopPage(itemID: wallpaperID)
        actionMessage = "Opening Steam Workshop page..."
    }
}

#Preview {
    DownloadedWallpaperDetailView(
        wallpaper: DownloadedWallpaper(
            id: "preview",
            title: "Beautiful Landscape",
            author: "Preview Author",
            fileURL: URL(fileURLWithPath: "/path/to/preview.jpg"),
            downloadDate: Date(),
            fileSize: 1024 * 1024 * 5, // 5MB
            originalWallpaperID: "preview"
        )
    )
} 