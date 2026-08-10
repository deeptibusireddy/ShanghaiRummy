import UIKit

/// Design tokens for one visual style. Every SpriteKit color/font in
/// `GameScene` and `CardNode` reads from a `VisualTheme` — swap the theme,
/// swap the whole look. Themes stay pure data so they can be toggled at
/// runtime and unit-tested.
public struct VisualTheme {
    // Table
    public let name: String
    public let background: UIColor    // area outside the felt (screen bg)
    public let feltFill: UIColor
    public let feltStroke: UIColor
    public let feltStrokeWidth: CGFloat
    public let feltGlow: UIColor      // subtle radial spotlight behind piles
    public let emblemColor: UIColor   // faint center table monogram
    // Cards
    public let cardFace: UIColor
    public let cardStroke: UIColor
    public let cardBack: UIColor
    public let cardBackAccent: UIColor
    public let redSuit: UIColor
    public let blackSuit: UIColor
    public let jokerAccent: UIColor
    public let cardShadow: UIColor    // drop shadow under cards
    // Chrome
    public let bannerText: UIColor
    public let seatBgCurrent: UIColor
    public let seatBgOther: UIColor
    public let seatTitle: UIColor
    public let seatSub: UIColor
    public let pileLabel: UIColor
    public let turnGlow: UIColor      // halo behind active seat
    public let contractPillBg: UIColor
    public let contractPillText: UIColor
    public let scoreChipBg: UIColor
    public let scoreChipText: UIColor
    public let avatarColors: [UIColor] // cycled by player index
    // Fonts
    public let titleFont: String
    public let bodyFont: String

    /// Default visual direction for Shanghai Rummy Nights: a warm, social
    /// evening table rather than a literal casino felt simulation.
    public static let gameNight = VisualTheme(
        name: "Game Night",
        background: UIColor(red: 0.055, green: 0.063, blue: 0.13, alpha: 1),
        feltFill: UIColor(red: 0.105, green: 0.11, blue: 0.22, alpha: 1),
        feltStroke: UIColor(red: 0.42, green: 0.35, blue: 0.62, alpha: 0.42),
        feltStrokeWidth: 1,
        feltGlow: UIColor(red: 0.49, green: 0.34, blue: 0.72, alpha: 1),
        emblemColor: UIColor(red: 0.96, green: 0.72, blue: 0.38, alpha: 0.05),
        cardFace: UIColor(red: 1.0, green: 0.975, blue: 0.92, alpha: 1),
        cardStroke: UIColor(red: 0.85, green: 0.78, blue: 0.68, alpha: 0.7),
        cardBack: UIColor(red: 0.37, green: 0.16, blue: 0.34, alpha: 1),
        cardBackAccent: UIColor(red: 0.96, green: 0.68, blue: 0.35, alpha: 1),
        redSuit: UIColor(red: 0.88, green: 0.22, blue: 0.30, alpha: 1),
        blackSuit: UIColor(red: 0.10, green: 0.10, blue: 0.15, alpha: 1),
        jokerAccent: UIColor(red: 0.92, green: 0.55, blue: 0.20, alpha: 1),
        cardShadow: UIColor(white: 0.0, alpha: 0.42),
        bannerText: UIColor(red: 1.0, green: 0.96, blue: 0.88, alpha: 1),
        seatBgCurrent: UIColor(red: 0.25, green: 0.20, blue: 0.36, alpha: 0.98),
        seatBgOther: UIColor(red: 0.09, green: 0.095, blue: 0.18, alpha: 0.90),
        seatTitle: UIColor(red: 1.0, green: 0.96, blue: 0.88, alpha: 1),
        seatSub: UIColor(red: 0.72, green: 0.70, blue: 0.82, alpha: 1),
        pileLabel: UIColor(red: 0.75, green: 0.73, blue: 0.84, alpha: 1),
        turnGlow: UIColor(red: 0.98, green: 0.66, blue: 0.31, alpha: 1),
        contractPillBg: UIColor(red: 0.16, green: 0.14, blue: 0.28, alpha: 0.96),
        contractPillText: UIColor(red: 1.0, green: 0.89, blue: 0.70, alpha: 1),
        scoreChipBg: UIColor(red: 0.12, green: 0.115, blue: 0.22, alpha: 0.96),
        scoreChipText: UIColor(red: 0.78, green: 0.75, blue: 0.88, alpha: 1),
        avatarColors: [
            UIColor(red: 0.93, green: 0.39, blue: 0.39, alpha: 1),
            UIColor(red: 0.31, green: 0.58, blue: 0.94, alpha: 1),
            UIColor(red: 0.31, green: 0.76, blue: 0.61, alpha: 1),
            UIColor(red: 0.96, green: 0.64, blue: 0.28, alpha: 1),
            UIColor(red: 0.68, green: 0.42, blue: 0.91, alpha: 1),
            UIColor(red: 0.25, green: 0.72, blue: 0.82, alpha: 1),
        ],
        titleFont: roundedSystemFontName(weight: .semibold),
        bodyFont: roundedSystemFontName(weight: .regular)
    )

    public static let cozyWood = VisualTheme(
        name: "Cozy Wood",
        background: UIColor(red: 0.32, green: 0.22, blue: 0.14, alpha: 1),
        feltFill: UIColor(red: 0.44, green: 0.32, blue: 0.22, alpha: 1),
        feltStroke: UIColor(red: 0.85, green: 0.72, blue: 0.52, alpha: 0.7),
        feltStrokeWidth: 3,
        feltGlow: UIColor(red: 0.98, green: 0.85, blue: 0.55, alpha: 1),
        emblemColor: UIColor(red: 0.98, green: 0.85, blue: 0.55, alpha: 0.08),
        cardFace: UIColor(red: 0.98, green: 0.96, blue: 0.90, alpha: 1),
        cardStroke: UIColor(red: 0.20, green: 0.14, blue: 0.08, alpha: 0.5),
        cardBack: UIColor(red: 0.55, green: 0.32, blue: 0.18, alpha: 1),
        cardBackAccent: UIColor(red: 0.85, green: 0.72, blue: 0.52, alpha: 1),
        redSuit: UIColor(red: 0.75, green: 0.15, blue: 0.15, alpha: 1),
        blackSuit: UIColor(red: 0.12, green: 0.10, blue: 0.08, alpha: 1),
        jokerAccent: UIColor(red: 0.80, green: 0.55, blue: 0.15, alpha: 1),
        cardShadow: UIColor(white: 0.05, alpha: 0.45),
        bannerText: UIColor(white: 0.98, alpha: 1),
        seatBgCurrent: UIColor(red: 0.90, green: 0.75, blue: 0.45, alpha: 0.95),
        seatBgOther: UIColor(red: 0.98, green: 0.96, blue: 0.90, alpha: 0.90),
        seatTitle: UIColor(white: 0.10, alpha: 1),
        seatSub: UIColor(white: 0.30, alpha: 1),
        pileLabel: UIColor(white: 0.95, alpha: 0.9),
        turnGlow: UIColor(red: 0.98, green: 0.85, blue: 0.35, alpha: 1),
        contractPillBg: UIColor(red: 0.28, green: 0.18, blue: 0.10, alpha: 0.85),
        contractPillText: UIColor(red: 0.98, green: 0.90, blue: 0.65, alpha: 1),
        scoreChipBg: UIColor(red: 0.28, green: 0.18, blue: 0.10, alpha: 0.75),
        scoreChipText: UIColor(red: 0.98, green: 0.90, blue: 0.65, alpha: 1),
        avatarColors: [
            UIColor(red: 0.85, green: 0.35, blue: 0.30, alpha: 1),
            UIColor(red: 0.35, green: 0.55, blue: 0.75, alpha: 1),
            UIColor(red: 0.55, green: 0.65, blue: 0.35, alpha: 1),
            UIColor(red: 0.75, green: 0.50, blue: 0.30, alpha: 1),
            UIColor(red: 0.60, green: 0.40, blue: 0.65, alpha: 1),
            UIColor(red: 0.40, green: 0.55, blue: 0.60, alpha: 1),
        ],
        titleFont: "HelveticaNeue-Bold",
        bodyFont: "HelveticaNeue"
    )

    public static let casinoFelt = VisualTheme(
        name: "Casino Felt",
        background: UIColor(red: 0.05, green: 0.13, blue: 0.08, alpha: 1),
        feltFill: UIColor(red: 0.09, green: 0.32, blue: 0.20, alpha: 1),
        feltStroke: UIColor(red: 0.95, green: 0.80, blue: 0.30, alpha: 1),
        feltStrokeWidth: 6,
        feltGlow: UIColor(red: 0.35, green: 0.75, blue: 0.45, alpha: 1),   // brighter green spotlight
        emblemColor: UIColor(red: 0.98, green: 0.82, blue: 0.35, alpha: 0.10),
        cardFace: UIColor(white: 1.0, alpha: 1),
        cardStroke: UIColor(white: 0.05, alpha: 0.6),
        cardBack: UIColor(red: 0.60, green: 0.10, blue: 0.15, alpha: 1),
        cardBackAccent: UIColor(red: 0.95, green: 0.82, blue: 0.30, alpha: 1),
        redSuit: UIColor(red: 0.85, green: 0.10, blue: 0.10, alpha: 1),
        blackSuit: UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1),
        jokerAccent: UIColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1),
        cardShadow: UIColor(white: 0.0, alpha: 0.55),
        bannerText: UIColor(red: 0.98, green: 0.92, blue: 0.65, alpha: 1),
        seatBgCurrent: UIColor(red: 0.95, green: 0.80, blue: 0.30, alpha: 0.98),
        seatBgOther: UIColor(red: 0.05, green: 0.22, blue: 0.14, alpha: 0.95),
        seatTitle: UIColor(white: 1.0, alpha: 1),
        seatSub: UIColor(red: 0.95, green: 0.85, blue: 0.55, alpha: 1),
        pileLabel: UIColor(red: 0.98, green: 0.90, blue: 0.55, alpha: 1),
        turnGlow: UIColor(red: 0.98, green: 0.82, blue: 0.25, alpha: 1),
        contractPillBg: UIColor(red: 0.03, green: 0.18, blue: 0.12, alpha: 0.9),
        contractPillText: UIColor(red: 0.98, green: 0.85, blue: 0.35, alpha: 1),
        scoreChipBg: UIColor(red: 0.03, green: 0.18, blue: 0.12, alpha: 0.90),
        scoreChipText: UIColor(red: 0.98, green: 0.90, blue: 0.55, alpha: 1),
        avatarColors: [
            UIColor(red: 0.90, green: 0.30, blue: 0.30, alpha: 1),
            UIColor(red: 0.30, green: 0.60, blue: 0.90, alpha: 1),
            UIColor(red: 0.95, green: 0.75, blue: 0.20, alpha: 1),
            UIColor(red: 0.50, green: 0.75, blue: 0.35, alpha: 1),
            UIColor(red: 0.75, green: 0.40, blue: 0.85, alpha: 1),
            UIColor(red: 0.40, green: 0.75, blue: 0.85, alpha: 1),
        ],
        titleFont: "Georgia-Bold",
        bodyFont: "Georgia"
    )

    public static let minimalModern = VisualTheme(
        name: "Minimal Modern",
        background: UIColor(red: 0.94, green: 0.93, blue: 0.90, alpha: 1),
        feltFill: UIColor(red: 0.87, green: 0.85, blue: 0.80, alpha: 1),
        feltStroke: UIColor(red: 0.30, green: 0.30, blue: 0.32, alpha: 0.3),
        feltStrokeWidth: 1,
        feltGlow: UIColor(white: 1.0, alpha: 1),
        emblemColor: UIColor(red: 0.15, green: 0.20, blue: 0.30, alpha: 0.06),
        cardFace: UIColor.white,
        cardStroke: UIColor(white: 0.75, alpha: 1),
        cardBack: UIColor(red: 0.25, green: 0.30, blue: 0.40, alpha: 1),
        cardBackAccent: UIColor.white,
        redSuit: UIColor(red: 0.90, green: 0.20, blue: 0.25, alpha: 1),
        blackSuit: UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1),
        jokerAccent: UIColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 1),
        cardShadow: UIColor(white: 0.20, alpha: 0.25),
        bannerText: UIColor(white: 0.20, alpha: 1),
        seatBgCurrent: UIColor.white,
        seatBgOther: UIColor(white: 1.0, alpha: 0.75),
        seatTitle: UIColor(white: 0.10, alpha: 1),
        seatSub: UIColor(white: 0.40, alpha: 1),
        pileLabel: UIColor(white: 0.30, alpha: 1),
        turnGlow: UIColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 1),
        contractPillBg: UIColor(red: 0.15, green: 0.20, blue: 0.30, alpha: 0.90),
        contractPillText: UIColor.white,
        scoreChipBg: UIColor(red: 0.94, green: 0.93, blue: 0.90, alpha: 0.95),
        scoreChipText: UIColor(white: 0.20, alpha: 1),
        avatarColors: [
            UIColor(red: 0.90, green: 0.45, blue: 0.35, alpha: 1),
            UIColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 1),
            UIColor(red: 0.60, green: 0.75, blue: 0.35, alpha: 1),
            UIColor(red: 0.85, green: 0.65, blue: 0.30, alpha: 1),
            UIColor(red: 0.55, green: 0.40, blue: 0.75, alpha: 1),
            UIColor(red: 0.40, green: 0.65, blue: 0.75, alpha: 1),
        ],
        titleFont: "AvenirNext-DemiBold",
        bodyFont: "AvenirNext-Regular"
    )

    private static func roundedSystemFontName(weight: UIFont.Weight) -> String {
        let base = UIFont.systemFont(ofSize: 16, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else {
            return base.fontName
        }
        return UIFont(descriptor: descriptor, size: 16).fontName
    }
}
