import SwiftUI

/// Design token constants derived from /docs/design-tokens.md
/// All visual values used across the app must reference these tokens.
enum DesignTokens {

    // MARK: - Colors

    enum Colors {
        static let primary = Color(hex: 0x000000)
        static let primaryHover = Color(hex: 0x1A1A1A)
        static let backgroundSecondary = Color(hex: 0x111111)
        static let surface = Color.white.opacity(0.06)

        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.72)
        static let textTertiary = Color.white.opacity(0.45)

        static let accent = Color(hex: 0x0A84FF)
        static let accentHover = Color(hex: 0x409CFF)
        static let success = Color(hex: 0x30D158)
        static let error = Color(hex: 0xFF453A)
        static let warning = Color(hex: 0xFFD60A)

        static let border = Color.white.opacity(0.08)
        static let borderStrong = Color.white.opacity(0.16)
    }

    // MARK: - Typography

    enum Typography {
        static let fontDisplay = "SFProDisplay-Regular"
        static let fontText = "SFProText-Regular"

        static let xs: CGFloat = 11
        static let sm: CGFloat = 13
        static let base: CGFloat = 16
        static let lg: CGFloat = 18
        static let xl: CGFloat = 22
        static let xxl: CGFloat = 28
        static let xxxl: CGFloat = 34
        static let xxxxl: CGFloat = 42

        enum Weight {
            static let normal: Font.Weight = .regular
            static let medium: Font.Weight = .medium
            static let semibold: Font.Weight = .semibold
            static let bold: Font.Weight = .bold
        }
    }

    // MARK: - Spacing

    enum Spacing {
        static let space1: CGFloat = 4
        static let space2: CGFloat = 8
        static let space3: CGFloat = 12
        static let space4: CGFloat = 16
        static let space5: CGFloat = 20
        static let space6: CGFloat = 24
        static let space8: CGFloat = 32
        static let space10: CGFloat = 40
        static let space12: CGFloat = 48
        static let space16: CGFloat = 64
    }

    // MARK: - Radius

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 14
        static let large: CGFloat = 20
        static let xl: CGFloat = 28
        static let full: CGFloat = 9999
    }

    // MARK: - Motion

    enum Motion {
        static let fast: Double = 0.12
        static let normal: Double = 0.22
        static let slow: Double = 0.42
    }

    // MARK: - Shutter Button

    enum Shutter {
        static let outerSize: CGFloat = 76
        static let innerSize: CGFloat = 64
        static let strokeWidth: CGFloat = 4.5
    }
}

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
