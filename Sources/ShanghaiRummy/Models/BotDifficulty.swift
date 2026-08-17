import Foundation

public enum BotDifficulty: String, CaseIterable, Codable, Sendable {
    case easy
    case medium
    case hard

    public var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    public var summary: String {
        switch self {
        case .easy: return "Relaxed choices"
        case .medium: return "Balanced strategy"
        case .hard: return "Best strategy"
        }
    }
}
