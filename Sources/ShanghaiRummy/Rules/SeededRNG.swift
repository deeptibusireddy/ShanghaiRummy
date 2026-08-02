import Foundation

/// Reproducible RNG for shuffling. All clients that share a seed produce the
/// same shuffle, which lets Game Center matches sync without transmitting the
/// entire shuffled deck.
///
/// SplitMix64 — small, fast, and standardized.
public struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
