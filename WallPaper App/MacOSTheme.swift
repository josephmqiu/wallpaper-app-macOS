import SwiftUI

// MARK: - macOS Design System Constants
struct MacOSTheme {
    // MARK: - Colors
    struct Colors {
        static let primaryAccent = Color.accentColor
        static let secondaryAccent = Color.blue.opacity(0.8)
        
        static let windowBackground = Color(NSColor.windowBackgroundColor)
        static let controlBackground = Color(NSColor.controlBackgroundColor)
        static let controlAccent = Color(NSColor.controlAccentColor)
        
        static let textPrimary = Color(NSColor.labelColor)
        static let textSecondary = Color(NSColor.secondaryLabelColor)
        static let textTertiary = Color(NSColor.tertiaryLabelColor)
        
        static let separator = Color(NSColor.separatorColor)
        static let grid = Color(NSColor.gridColor)
        
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        
        static let hoverOverlay = Color.black.opacity(0.05)
        static let activeOverlay = Color.black.opacity(0.1)
    }
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.system(size: 26, weight: .bold, design: .default)
        static let title = Font.system(size: 22, weight: .bold, design: .default)
        static let title2 = Font.system(size: 17, weight: .semibold, design: .default)
        static let title3 = Font.system(size: 15, weight: .semibold, design: .default)
        static let headline = Font.system(size: 13, weight: .semibold, design: .default)
        static let body = Font.system(size: 13, weight: .regular, design: .default)
        static let callout = Font.system(size: 12, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 11, weight: .regular, design: .default)
        static let footnote = Font.system(size: 10, weight: .regular, design: .default)
        static let caption = Font.system(size: 10, weight: .regular, design: .default)
        static let caption2 = Font.system(size: 9, weight: .regular, design: .default)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xxxSmall: CGFloat = 2
        static let xxSmall: CGFloat = 4
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 20
        static let xxLarge: CGFloat = 24
        static let xxxLarge: CGFloat = 32
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 6
        static let large: CGFloat = 8
        static let xLarge: CGFloat = 10
        static let xxLarge: CGFloat = 12
    }
    
    // MARK: - Shadows
    struct Shadow {
        static let small = (color: Color.black.opacity(0.15), radius: 2.0, x: 0.0, y: 1.0)
        static let medium = (color: Color.black.opacity(0.15), radius: 4.0, x: 0.0, y: 2.0)
        static let large = (color: Color.black.opacity(0.15), radius: 8.0, x: 0.0, y: 4.0)
    }
    
    // MARK: - Animation
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.35)
    }
}

// MARK: - macOS Style Modifiers
extension View {
    func macOSCard() -> some View {
        self
            .background(MacOSTheme.Colors.controlBackground)
            .cornerRadius(MacOSTheme.CornerRadius.large)
            .shadow(
                color: MacOSTheme.Shadow.small.color,
                radius: MacOSTheme.Shadow.small.radius,
                x: MacOSTheme.Shadow.small.x,
                y: MacOSTheme.Shadow.small.y
            )
    }
    
    func macOSButton(style: MacOSButtonStyle = .default) -> some View {
        self
            .buttonStyle(MacOSNativeButtonStyle(style: style))
    }
    
    func macOSHoverEffect() -> some View {
        self
            .onHover { isHovered in
                if isHovered {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

// MARK: - macOS Button Styles
enum MacOSButtonStyle {
    case `default`
    case primary
    case secondary
    case destructive
    case plain
}

struct MacOSNativeButtonStyle: ButtonStyle {
    let style: MacOSButtonStyle
    @State private var isHovered = false
    @State private var isPressed = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MacOSTheme.Typography.body)
            .padding(.horizontal, MacOSTheme.Spacing.medium)
            .padding(.vertical, MacOSTheme.Spacing.xSmall)
            .background(backgroundView)
            .foregroundColor(foregroundColor)
            .cornerRadius(MacOSTheme.CornerRadius.medium)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(MacOSTheme.Animation.quick, value: isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
            .onChange(of: configuration.isPressed) { _, pressed in
                isPressed = pressed
            }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .default:
            RoundedRectangle(cornerRadius: MacOSTheme.CornerRadius.medium)
                .fill(MacOSTheme.Colors.controlBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: MacOSTheme.CornerRadius.medium)
                        .stroke(MacOSTheme.Colors.separator, lineWidth: 1)
                )
                .overlay(
                    isHovered ? MacOSTheme.Colors.hoverOverlay : Color.clear
                )
        case .primary:
            RoundedRectangle(cornerRadius: MacOSTheme.CornerRadius.medium)
                .fill(MacOSTheme.Colors.primaryAccent)
                .overlay(
                    isHovered ? Color.white.opacity(0.1) : Color.clear
                )
        case .secondary:
            RoundedRectangle(cornerRadius: MacOSTheme.CornerRadius.medium)
                .fill(MacOSTheme.Colors.controlBackground.opacity(0.8))
                .overlay(
                    isHovered ? MacOSTheme.Colors.hoverOverlay : Color.clear
                )
        case .destructive:
            RoundedRectangle(cornerRadius: MacOSTheme.CornerRadius.medium)
                .fill(MacOSTheme.Colors.error.opacity(isHovered ? 0.9 : 0.8))
        case .plain:
            RoundedRectangle(cornerRadius: MacOSTheme.CornerRadius.medium)
                .fill(isHovered ? MacOSTheme.Colors.hoverOverlay : Color.clear)
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .default, .plain:
            return MacOSTheme.Colors.textPrimary
        case .primary, .destructive:
            return .white
        case .secondary:
            return MacOSTheme.Colors.textPrimary
        }
    }
}

// MARK: - Visual Effect View for Blur
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}