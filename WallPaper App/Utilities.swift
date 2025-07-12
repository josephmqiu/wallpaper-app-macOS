import Foundation
import CoreGraphics

// MARK: - Aspect Ratio Utilities
func aspectRatioToString(_ ratio: CGFloat) -> String {
    let tolerance: CGFloat = 0.05
    
    // Common aspect ratios
    let commonRatios: [(CGFloat, String)] = [
        (16.0/9.0, "16:9"),
        (21.0/9.0, "21:9"),
        (4.0/3.0, "4:3"),
        (3.0/2.0, "3:2"),
        (5.0/4.0, "5:4"),
        (1.0, "1:1"),
        (9.0/16.0, "9:16"),
        (3.0/4.0, "3:4"),
        (2.0/3.0, "2:3")
    ]
    
    // Find the closest common ratio
    for (commonRatio, name) in commonRatios {
        if abs(ratio - commonRatio) < tolerance {
            return name
        }
    }
    
    // If no common ratio found, return decimal format
    return String(format: "%.2f:1", ratio)
}

// MARK: - File Size Formatting
func formatFileSize(_ bytes: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useMB, .useKB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
}

func formatFileSize(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useMB, .useKB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}