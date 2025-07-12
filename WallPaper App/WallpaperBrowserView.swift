import SwiftUI
import SDWebImageSwiftUI
import AVKit
import ImageIO
#if os(macOS)
import AppKit
#endif

struct WallpaperBrowserView: View {
    @StateObject private var viewModel = WallpaperViewModel()
    @State private var showingTokenInput = false
    
    let columns = [
        GridItem(.adaptive(minimum: 180), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Steam client status bar
                HStack {
                    Image(systemName: viewModel.localContentAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(viewModel.localContentAvailable ? MacOSTheme.Colors.success : MacOSTheme.Colors.warning)
                        .font(MacOSTheme.Typography.body)
                    
                    VStack(alignment: .leading, spacing: MacOSTheme.Spacing.xxxSmall) {
                        Text(viewModel.steamClientStatus)
                            .font(MacOSTheme.Typography.callout)
                            .foregroundColor(MacOSTheme.Colors.textPrimary)
                        
                        if viewModel.localContentAvailable {
                            Text("Direct Wallpaper Engine workshop access on macOS")
                                .font(MacOSTheme.Typography.caption)
                                .foregroundColor(MacOSTheme.Colors.success)
                        } else {
                            Text("Launch Steam to access Wallpaper Engine workshop")
                                .font(MacOSTheme.Typography.caption)
                                .foregroundColor(MacOSTheme.Colors.warning)
                        }
                    }
                    
                    Spacer()
                    
                    let (total, available) = viewModel.getLocalContentInfo()
                    if total > 0 {
                        Text("\(available)/\(total) high-res")
                            .font(MacOSTheme.Typography.caption)
                            .foregroundColor(MacOSTheme.Colors.textSecondary)
                    }
                    
                    HStack(spacing: MacOSTheme.Spacing.small) {
                        if !viewModel.localContentAvailable {
                            Button(action: {
                                let success = viewModel.launchSteamClient()
                                if !success {
                                    viewModel.installSteam()
                                }
                            }) {
                                HStack(spacing: MacOSTheme.Spacing.xxSmall) {
                                    Image(systemName: "play.fill")
                                    Text("Launch Steam")
                                }
                            }
                            .macOSButton(style: .primary)
                        }
                        
                        Button(action: {
                            viewModel.refreshLocalContent()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .macOSButton(style: .plain)
                    }
                }
                .padding(.horizontal, MacOSTheme.Spacing.large)
                .padding(.vertical, MacOSTheme.Spacing.medium)
                .background(
                    VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                )
                
                // Search bar and sorting
                HStack {
                    TextField("Search wallpapers... (Press Enter to search)", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            Task { await viewModel.performSearch() }
                        }
                    
                    SortingMenu(sortingManager: viewModel.sortingManager) {
                        // Trigger re-render when sorting changes
                        viewModel.objectWillChange.send()
                    }
                }
                .padding([.top, .horizontal])
                
                // Filter bar
                FilterView(filterManager: viewModel.filterManager, viewModel: viewModel)
                Group {
                    if viewModel.isLoading && viewModel.wallpapers.isEmpty {
                        ProgressView()
                    } else if let error = viewModel.errorMessage {
                        VStack {
                            Text(error).foregroundColor(.red)
                            Button("Retry") { Task { await viewModel.loadWallpapers(reset: true) } }
                        }
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(viewModel.filteredWallpapers, id: \.id) { wallpaper in
                                    NavigationLink(destination: WallpaperDetailView(wallpaper: wallpaper, aspectRatio: wallpaper.aspectRatio).environmentObject(viewModel)) {
                                        WallpaperCell(wallpaper: wallpaper, aspectRatio: wallpaper.aspectRatio)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .onAppear {
                                        if wallpaper.id == viewModel.filteredWallpapers.last?.id {
                                            Task { await viewModel.loadMoreWallpapers() }
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
                .animation(.default, value: viewModel.wallpapers.count)
            }
            .navigationTitle("Wallpapers")
            .task { await viewModel.loadWallpapers(reset: true) }
            .onChange(of: viewModel.selectedTags) { _, _ in Task { await viewModel.performSearch() } }
            .onChange(of: viewModel.needsApiToken) { _, needsToken in
                if needsToken {
                    showingTokenInput = true
                }
            }
            .sheet(isPresented: $showingTokenInput) {
                TokenInputView(isPresented: $showingTokenInput) { _ in
                    Task { await viewModel.loadWallpapers(reset: true) }
                }
            }
        }
    }
}

struct WallpaperCell: View {
    let wallpaper: Wallpaper
    let aspectRatio: CGFloat
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image container
            ZStack {
                if let url = wallpaper.previewURL {
                    AnimatedImage(url: url)
                        .resizable()
                        .aspectRatio(aspectRatio, contentMode: .fill)
                        .frame(height: 180)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(MacOSTheme.Colors.controlBackground)
                        .frame(height: 180)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(MacOSTheme.Colors.textTertiary)
                        )
                }
                
                // Hover overlay
                if isHovered {
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .transition(.opacity)
                }
                
                // Badges overlay
                VStack {
                    HStack {
                        // Local availability indicator
                        if wallpaper.isLocallyAvailable {
                            HStack(spacing: MacOSTheme.Spacing.xxSmall) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(MacOSTheme.Typography.caption2)
                                Text("HD")
                                    .font(MacOSTheme.Typography.caption2)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, MacOSTheme.Spacing.xSmall)
                            .padding(.vertical, MacOSTheme.Spacing.xxxSmall)
                            .background(MacOSTheme.Colors.success)
                            .foregroundColor(.white)
                            .cornerRadius(MacOSTheme.CornerRadius.small)
                        }
                        
                        Spacer()
                        
                        ContentTypeBadge(contentType: wallpaper.contentType)
                    }
                    Spacer()
                }
                .padding(MacOSTheme.Spacing.small)
            }
            
            // Info section
            VStack(alignment: .leading, spacing: MacOSTheme.Spacing.xxSmall) {
                Text(wallpaper.title)
                    .font(MacOSTheme.Typography.headline)
                    .foregroundColor(MacOSTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: MacOSTheme.Spacing.xxSmall) {
                    Text(aspectRatioToString(aspectRatio))
                        .font(MacOSTheme.Typography.caption)
                        .foregroundColor(MacOSTheme.Colors.textSecondary)
                    
                    if let fileSize = wallpaper.fileSize {
                        Text("•")
                            .font(MacOSTheme.Typography.caption)
                            .foregroundColor(MacOSTheme.Colors.textTertiary)
                        
                        Text(formatFileSize(fileSize))
                            .font(MacOSTheme.Typography.caption)
                            .foregroundColor(MacOSTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
            }
            .padding(MacOSTheme.Spacing.medium)
        }
        .background(MacOSTheme.Colors.controlBackground)
        .cornerRadius(MacOSTheme.CornerRadius.large)
        .shadow(
            color: isHovered ? MacOSTheme.Shadow.medium.color : MacOSTheme.Shadow.small.color,
            radius: isHovered ? MacOSTheme.Shadow.medium.radius : MacOSTheme.Shadow.small.radius,
            x: 0,
            y: isHovered ? MacOSTheme.Shadow.medium.y : MacOSTheme.Shadow.small.y
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(MacOSTheme.Animation.quick, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct VideoPlayerView: View {
    let url: URL
    @Binding var player: AVPlayer?
    @Binding var isLoaded: Bool
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fit)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else {
                Color.gray.opacity(0.3)
                    .aspectRatio(contentMode: .fit)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
            }
        }
        .onAppear {
            if player == nil {
                player = AVPlayer(url: url)
                player?.isMuted = true
            }
        }
    }
}

struct ContentTypeBadge: View {
    let contentType: ContentType
    
    var body: some View {
        HStack(spacing: MacOSTheme.Spacing.xxSmall) {
            Image(systemName: iconName)
                .font(MacOSTheme.Typography.caption2)
            Text(contentType.rawValue.uppercased())
                .font(MacOSTheme.Typography.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, MacOSTheme.Spacing.xSmall)
        .padding(.vertical, MacOSTheme.Spacing.xxxSmall)
        .background(backgroundColor.opacity(0.9))
        .foregroundColor(.white)
        .cornerRadius(MacOSTheme.CornerRadius.small)
    }
    
    private var iconName: String {
        switch contentType {
        case .image:
            return "photo"
        case .video:
            return "video.fill"
        case .gif:
            return "play.rectangle.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    private var backgroundColor: Color {
        switch contentType {
        case .image:
            return MacOSTheme.Colors.secondaryAccent
        case .video:
            return .purple
        case .gif:
            return .orange
        case .unknown:
            return MacOSTheme.Colors.textTertiary
        }
    }
} 

import SDWebImageSwiftUI
import AVKit
struct WallpaperDetailView: View {
    let wallpaper: Wallpaper
    let aspectRatio: CGFloat?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: WallpaperViewModel
    @State private var isSubscribing = false
    @State private var subscriptionMessage: String?
    
    var body: some View {
        content
    }
    var content: some View {
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
                    // Image panel - use best available URL (local first, then remote)
                    if let url = wallpaper.bestAvailableImageURL {
                        HStack {
                            Spacer()
                            if let aspect = aspectRatio {
                                // Use the actual aspect ratio from the API data
                                AnimatedImage(url: url)
                                    .resizable()
                                    .aspectRatio(aspect, contentMode: .fit)
                                    .frame(maxWidth: min(geometry.size.width * 0.8, 900))
                                    .cornerRadius(16)
                                    .clipped()
                            } else {
                                // Fallback when aspect ratio is not available
                                AnimatedImage(url: url)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: min(geometry.size.width * 0.8, 900), maxHeight: min(geometry.size.height * 0.6, 700))
                                    .cornerRadius(16)
                                    .clipped()
                            }
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                            Color.gray.opacity(0.3)
                                .frame(width: 400, height: 300)
                                .cornerRadius(16)
                            Spacer()
                        }
                    }
                    // Metadata panel
                    VStack(alignment: .leading, spacing: 16) {
                        Text(wallpaper.title)
                            .font(.title)
                            .bold()
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                        if let author = wallpaper.tags.first?.tag { // Replace with real author if available
                            Text("by \(author)")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Steam client status and local file info
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: wallpaper.isLocallyAvailable ? "checkmark.circle.fill" : "cloud")
                                    .foregroundColor(wallpaper.isLocallyAvailable ? .green : .blue)
                                Text(wallpaper.isLocallyAvailable ? "High-res available locally" : "Using preview quality")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            if let localSize = wallpaper.localFileSize {
                                Text("Local file size: \(ByteCountFormatter.string(fromByteCount: localSize, countStyle: .file))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Steam Status: \(viewModel.steamClientStatus)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("macOS: Direct Wallpaper Engine workshop access")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(.vertical, 4)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        
                        if let aspect = aspectRatio {
                            Text("Aspect Ratio: \(aspectRatioToString(aspect))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let width = wallpaper.width, let height = wallpaper.height {
                            Text("Resolution: \(width)×\(height)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Divider()
                        Text("Description:")
                            .font(.subheadline)
                            .bold()
                        Text("(No description available)")
                            .font(.body)
                            .foregroundColor(.secondary)
                        Divider()
                        Text("Tags:")
                            .font(.subheadline)
                            .bold()
                        WrapTagsView(tags: wallpaper.tags.map { $0.tag })
                        
                        // Action buttons - Only show "Open in Steam" as requested
                        Divider()
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                viewModel.openWallpaperInSteam(wallpaper)
                            }) {
                                HStack {
                                    Image(systemName: "link.circle.fill")
                                    Text("Open in Steam")
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Text("View this wallpaper in the Steam Workshop")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: 600, alignment: .topLeading)
                    .padding(.horizontal)
                    Spacer(minLength: 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle(wallpaper.title)
    }
}

struct WrapTagsView: View {
    let tags: [String]
    var body: some View {
        FlexibleView(data: tags, spacing: 8, alignment: .leading) { tag in
            Text(tag)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .font(.caption)
        }
    }
}

// Simple flexible layout for tags
struct FlexibleView<Data: BidirectionalCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content
    @State private var totalHeight: CGFloat = .zero
    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)
    }
    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        let views = data.map { item in
            content(item)
                .padding([.bottom, .trailing], spacing)
                .alignmentGuide(.leading, computeValue: { d in
                    if abs(width - d.width) > g.size.width {
                        width = 0
                        height -= d.height + spacing
                    }
                    let result = width
                    if let last = data.last, item == last {
                        width = 0 // Last item
                    } else {
                        width -= d.width + spacing
                    }
                    return result
                })
                .alignmentGuide(.top, computeValue: { _ in
                    let result = height
                    if let last = data.last, item == last {
                        height = 0 // Last item
                    }
                    return result
                })
        }
        return ZStack(alignment: Alignment(horizontal: alignment, vertical: .top)) {
            ForEach(views.indices, id: \ .self) { idx in
                views[idx]
            }
        }
        .background(viewHeightReader($totalHeight))
    }
    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: ViewHeightKey.self, value: geometry.size.height)
        }
        .onPreferenceChange(ViewHeightKey.self) { binding.wrappedValue = $0 }
    }
} 

// PreferenceKey for FlexibleView height
private struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

 