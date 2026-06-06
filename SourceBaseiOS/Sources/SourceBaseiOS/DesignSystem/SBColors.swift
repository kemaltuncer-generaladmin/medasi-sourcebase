import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum SBColors {
    private struct Components {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }
    }

    private static func adaptive(light: Components, dark: Components) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { trait in
            let value = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.red, green: value.green, blue: value.blue, alpha: value.alpha)
        })
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let value = isDark ? dark : light
            return NSColor(red: value.red, green: value.green, blue: value.blue, alpha: value.alpha)
        })
        #else
        return Color(red: Double(light.red), green: Double(light.green), blue: Double(light.blue), opacity: Double(light.alpha))
        #endif
    }

    private static func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> Color {
        Color(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(alpha))
    }

    // MARK: - Surfaces
    public static let page = adaptive(light: Components(0.961, 0.973, 0.992), dark: Components(0.041, 0.049, 0.071))
    public static let white = adaptive(light: Components(1.0, 1.0, 1.0), dark: Components(0.075, 0.086, 0.118))
    public static let field = adaptive(light: Components(0.937, 0.957, 0.984), dark: Components(0.102, 0.118, 0.157))
    public static let fieldFocus = adaptive(light: Components(1.0, 1.0, 1.0), dark: Components(0.125, 0.145, 0.188))

    // MARK: - Text
    public static let navy = adaptive(light: Components(0.027, 0.075, 0.247), dark: Components(0.898, 0.933, 0.988))
    public static let ink = adaptive(light: Components(0.039, 0.086, 0.259), dark: Components(0.824, 0.875, 0.965))
    public static let muted = adaptive(light: Components(0.369, 0.424, 0.557), dark: Components(0.686, 0.745, 0.855))
    public static let softText = adaptive(light: Components(0.541, 0.596, 0.706), dark: Components(0.573, 0.635, 0.753))

    // MARK: - Brand Blues
    public static let blue = color(0.039, 0.357, 1.0)
    public static let deepBlue = color(0.043, 0.251, 0.902)
    public static let sky = color(0.184, 0.482, 1.0)
    public static let cyan = color(0.031, 0.780, 0.839)

    // MARK: - Lines
    public static let line = adaptive(light: Components(0.906, 0.929, 0.969), dark: Components(0.184, 0.208, 0.271))
    public static let softLine = adaptive(light: Components(0.933, 0.953, 0.980), dark: Components(0.137, 0.157, 0.216))
    public static let softBlue = adaptive(light: Components(0.918, 0.953, 1.0), dark: Components(0.071, 0.118, 0.220))
    public static let selectedBlue = adaptive(light: Components(0.929, 0.957, 1.0), dark: Components(0.075, 0.133, 0.251))

    // MARK: - Status
    public static let green = color(0.071, 0.682, 0.333)
    public static let greenBg = adaptive(light: Components(0.918, 0.984, 0.945), dark: Components(0.051, 0.180, 0.102))
    public static let red = color(1.0, 0.231, 0.231)
    public static let redBg = adaptive(light: Components(1.0, 0.937, 0.937), dark: Components(0.224, 0.067, 0.071))
    public static let warning = color(0.961, 0.620, 0.043)
    public static let warningBg = adaptive(light: Components(1.0, 0.969, 0.902), dark: Components(0.216, 0.141, 0.043))
    public static let purple = color(0.482, 0.247, 0.949)
    public static let orange = color(1.0, 0.420, 0.075)

    // MARK: - Semantic tints
    public static let questionTint = cyan

    // MARK: - Gradients
    public static let primaryGradient = LinearGradient(
        colors: [sky, blue, deepBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let brandGradient = LinearGradient(
        colors: [cyan, blue, color(0.137, 0.082, 0.788)],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )

    /// Very subtle top-to-bottom page wash that adds depth behind cards
    /// without reading as a "magic" gradient.
    public static let pageGradient = LinearGradient(
        colors: [
            adaptive(light: Components(0.984, 0.990, 1.0), dark: Components(0.047, 0.055, 0.078)),
            page,
            adaptive(light: Components(0.945, 0.961, 0.988), dark: Components(0.059, 0.071, 0.102))
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Soft tint used as a hero/card accent fill.
    public static func heroWash(_ tint: Color) -> LinearGradient {
        LinearGradient(
            colors: [tint.opacity(0.16), white],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
