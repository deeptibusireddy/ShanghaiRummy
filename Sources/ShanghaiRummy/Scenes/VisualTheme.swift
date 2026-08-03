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
    // Cards
    public let cardFace: UIColor
    public let cardStroke: UIColor
    public let cardBack: UIColor
    public let cardBackAccent: UIColor
    public let redSuit: UIColor
    public let blackSuit: UIColor
    public let jokerAccent: UIColor
    // Chrome
    public let bannerText: UIColor
    public let seatBgCurrent: UIColor
    public let seatBgOther: UIColor
    public let seatTitle: UIColor
    public let seatSub: UIColor
    public let pileLabel: UIColor
    // Fonts
    public let titleFont: String
    public let bodyFont: String

    public static let cozyWood = VisualTheme(
        name: "Cozy Wood",
        background: UIColor(red: 0.32, green: 0.22, blue: 0.14, alpha: 1),
        feltFill: UIColor(red: 0.44, green: 0.32, blue: 0.22, alpha: 1),
        feltStroke: UIColor(red: 0.85, green: 0.72, blue: 0.52, alpha: 0.7),
        feltStrokeWidth: 3,
        cardFace: UIColor(red: 0.98, green: 0.96, blue: 0.90, alpha: 1), // cream
        cardStroke: UIColor(red: 0.20, green: 0.14, blue: 0.08, alpha: 0.5),
        cardBack: UIColor(red: 0.55, green: 0.32, blue: 0.18, alpha: 1),
        cardBackAccent: UIColor(red: 0.85, green: 0.72, blue: 0.52, alpha: 1),
        redSuit: UIColor(red: 0.75, green: 0.15, blue: 0.15, alpha: 1),
        blackSuit: UIColor(red: 0.12, green: 0.10, blue: 0.08, alpha: 1),
        jokerAccent: UIColor(red: 0.80, green: 0.55, blue: 0.15, alpha: 1),
        bannerText: UIColor(white: 0.98, alpha: 1),
        seatBgCurrent: UIColor(red: 0.90, green: 0.75, blue: 0.45, alpha: 0.95),
        seatBgOther: UIColor(red: 0.98, green: 0.96, blue: 0.90, alpha: 0.90),
        seatTitle: UIColor(white: 0.10, alpha: 1),
        seatSub: UIColor(white: 0.30, alpha: 1),
        pileLabel: UIColor(white: 0.95, alpha: 0.9),
        titleFont: "HelveticaNeue-Bold",
        bodyFont: "HelveticaNeue"
    )

    public static let casinoFelt = VisualTheme(
        name: "Casino Felt",
        background: UIColor(red: 0.06, green: 0.16, blue: 0.10, alpha: 1),
        feltFill: UIColor(red: 0.11, green: 0.36, blue: 0.22, alpha: 1),   // deep green
        feltStroke: UIColor(red: 0.95, green: 0.80, blue: 0.30, alpha: 0.95), // gold rim
        feltStrokeWidth: 5,
        cardFace: UIColor(white: 1.0, alpha: 1),
        cardStroke: UIColor(white: 0.05, alpha: 0.6),
        cardBack: UIColor(red: 0.60, green: 0.10, blue: 0.15, alpha: 1),    // crimson
        cardBackAccent: UIColor(red: 0.95, green: 0.82, blue: 0.30, alpha: 1),
        redSuit: UIColor(red: 0.85, green: 0.10, blue: 0.10, alpha: 1),
        blackSuit: UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1),
        jokerAccent: UIColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1),
        bannerText: UIColor(red: 0.98, green: 0.92, blue: 0.65, alpha: 1),
        seatBgCurrent: UIColor(red: 0.95, green: 0.80, blue: 0.30, alpha: 0.95),
        seatBgOther: UIColor(red: 0.03, green: 0.20, blue: 0.13, alpha: 0.90),
        seatTitle: UIColor(white: 1.0, alpha: 1),
        seatSub: UIColor(red: 0.95, green: 0.85, blue: 0.55, alpha: 1),
        pileLabel: UIColor(red: 0.98, green: 0.90, blue: 0.55, alpha: 1),
        titleFont: "Georgia-Bold",
        bodyFont: "Georgia"
    )

    public static let minimalModern = VisualTheme(
        name: "Minimal Modern",
        background: UIColor(red: 0.94, green: 0.93, blue: 0.90, alpha: 1),
        feltFill: UIColor(red: 0.87, green: 0.85, blue: 0.80, alpha: 1),   // sand
        feltStroke: UIColor(red: 0.30, green: 0.30, blue: 0.32, alpha: 0.3),
        feltStrokeWidth: 1,
        cardFace: UIColor.white,
        cardStroke: UIColor(white: 0.75, alpha: 1),
        cardBack: UIColor(red: 0.25, green: 0.30, blue: 0.40, alpha: 1),   // slate blue
        cardBackAccent: UIColor.white,
        redSuit: UIColor(red: 0.90, green: 0.20, blue: 0.25, alpha: 1),
        blackSuit: UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1),
        jokerAccent: UIColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 1),
        bannerText: UIColor(white: 0.20, alpha: 1),
        seatBgCurrent: UIColor.white,
        seatBgOther: UIColor(white: 1.0, alpha: 0.75),
        seatTitle: UIColor(white: 0.10, alpha: 1),
        seatSub: UIColor(white: 0.40, alpha: 1),
        pileLabel: UIColor(white: 0.30, alpha: 1),
        titleFont: "AvenirNext-DemiBold",
        bodyFont: "AvenirNext-Regular"
    )
}
