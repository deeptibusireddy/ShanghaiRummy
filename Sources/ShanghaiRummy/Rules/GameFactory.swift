import Foundation

/// Convenience factory for setting up a fresh match. Used by tests today and
/// by the UI/lobby code later.
public enum GameFactory {
    /// Deal a fresh round: sets up stock, deals `RulesConfig.handSizeAtDeal`
    /// cards to each player, and flips the initial discard card. Uses a
    /// deterministic RNG so multiplayer clients agree.
    public static func newGame(playerNames: [String], seed: UInt64) -> GameState {
        newGame(
            players: playerNames.map { Player(name: $0) },
            seed: seed
        )
    }

    /// Builds a game while preserving caller-created player identities. The
    /// opening draw reorders these players from highest to lowest clockwise.
    static func newGame(players originalPlayers: [Player], seed: UInt64) -> GameState {
        precondition(
            originalPlayers.count >= RulesConfig.minPlayers,
            "Too few players"
        )
        precondition(
            originalPlayers.count <= RulesConfig.maxPlayers,
            "Too many players"
        )

        var openingRNG = SeededRNG(
            seed: seed ^ 0xD1B54A32D192ED03
        )
        let openingDraws = drawOpeningCards(
            for: originalPlayers,
            using: &openingRNG
        )
        let drawByPlayerId = Dictionary(
            uniqueKeysWithValues: openingDraws.map {
                ($0.playerId, $0.seatingValue)
            }
        )
        var players = originalPlayers.sorted {
            drawByPlayerId[$0.id, default: 0]
                > drawByPlayerId[$1.id, default: 0]
        }

        var deck = Deck(playerCount: players.count)
        var rng = SeededRNG(seed: seed)
        deck.shuffle(using: &rng)
        let dealerIndex = players.count - 1

        for pi in players.indices {
            for _ in 0..<RulesConfig.handSizeAtDeal {
                if let c = deck.draw() { players[pi].hand.append(c) }
            }
        }
        let initialDiscard = deck.draw().map { [$0] } ?? []

        return GameState(
            players: players,
            currentRound: 1,
            currentTurnIndex: (dealerIndex + 1) % players.count,
            dealerIndex: dealerIndex,
            stock: deck.cards,
            discard: initialDiscard,
            melds: [],
            phase: .awaitingDraw,
            stockReshufflesUsed: 0,
            randomSeed: seed,
            openingDraws: openingDraws
        )
    }

    private static func drawOpeningCards<RNG: RandomNumberGenerator>(
        for players: [Player],
        using rng: inout RNG
    ) -> [OpeningDraw] {
        var deck = Deck(playerCount: players.count)
        deck.shuffle(using: &rng)
        var usedRanks: Set<Rank> = []
        var draws: [OpeningDraw] = []

        for player in players {
            while let card = deck.draw() {
                guard let rank = card.rank,
                      usedRanks.insert(rank).inserted else {
                    continue
                }
                draws.append(
                    OpeningDraw(playerId: player.id, card: card)
                )
                break
            }
        }

        precondition(
            draws.count == players.count,
            "Opening draw could not assign every player a unique rank"
        )
        return draws
    }

    /// Deal the next hand while carrying forward player identities, cumulative
    /// scores, and current levels. Called by `TurnEngine.advanceHand` after a
    /// hand ends. Deterministic — same match seed + hand number always
    /// produces the same shuffle across all clients.
    public static func newHand(from state: GameState) -> GameState {
        let nextHandNumber = state.currentRound + 1
        // Derive a distinct-but-deterministic seed for this hand from the
        // match seed. Hand 1 uses the raw match seed (for compatibility with
        // `newGame`); hands 2+ mix in the hand number.
        let handSeed = state.randomSeed &+
            (UInt64(nextHandNumber - 1) &* 0x9E3779B97F4A7C15)
        var rng = SeededRNG(seed: handSeed)
        var deck = Deck(playerCount: state.players.count)
        deck.shuffle(using: &rng)

        // Reset per-hand player state; preserve id, name, totalScore, currentLevel.
        var players = state.players.map { p in
            Player(
                id: p.id,
                name: p.name,
                hand: [],
                totalScore: p.totalScore,
                buysUsedThisRound: 0,
                hasGoneDownThisRound: false,
                laidDownThisTurn: false,
                currentLevel: p.currentLevel
            )
        }
        for pi in players.indices {
            for _ in 0..<RulesConfig.handSizeAtDeal {
                if let c = deck.draw() { players[pi].hand.append(c) }
            }
        }
        let initialDiscard = deck.draw().map { [$0] } ?? []

        // Rotate one seat clockwise, independent of who ended the hand.
        let newDealer = state.nextDealerIndex
        return GameState(
            players: players,
            currentRound: nextHandNumber,
            currentTurnIndex: (newDealer + 1) % players.count,
            dealerIndex: newDealer,
            stock: deck.cards,
            discard: initialDiscard,
            melds: [],
            phase: .awaitingDraw,
            stockReshufflesUsed: 0,
            randomSeed: state.randomSeed,
            gameWinnerIds: [],
            openingDraws: state.openingDraws
        )
    }

    // MARK: - Convenience factories

    /// Build a fresh "You vs N CPUs" match ready to play. The opening draw
    /// determines seating; `localPlayerId` keeps the human at the bottom of
    /// the screen after the array is reordered.
    public static func newVsCPU(
        you: String,
        cpuNames: [String],
        cpuDifficulties: [BotDifficulty]? = nil,
        seed: UInt64
    ) -> (
        state: GameState,
        cpuIds: Set<UUID>,
        cpuDifficulties: [UUID: BotDifficulty],
        localPlayerId: UUID
    ) {
        let difficulties = cpuDifficulties
            ?? Array(repeating: .hard, count: cpuNames.count)
        precondition(
            difficulties.count == cpuNames.count,
            "Every CPU player needs one difficulty"
        )
        let localPlayer = Player(name: you)
        let cpuPlayers = cpuNames.map { Player(name: $0) }
        let state = newGame(
            players: [localPlayer] + cpuPlayers,
            seed: seed
        )
        return (
            state,
            Set(cpuPlayers.map(\.id)),
            Dictionary(
                uniqueKeysWithValues: zip(
                    cpuPlayers.map(\.id),
                    difficulties
                )
            ),
            localPlayer.id
        )
    }

    // MARK: - Demo state (for design previews)

    /// A rigged 4-player mid-game state used only by design previews and CI
    /// screenshots. NOT a legal shuffle — cards are hand-picked so the table
    /// clearly shows: multiple players who've gone down, a mix of triplets
    /// and sequences, a joker and a wild 2 in play, and a hand for "You".
    ///
    /// Trigger by launching the app with `--demo-mid-game`.
    public static func demoMidGame() -> GameState {
        func c(_ suit: Suit, _ rank: Rank) -> Card { Card(suit: suit, rank: rank) }

        let you = Player(
            name: "You",
            hand: [
                c(.spades, .king), c(.diamonds, .king), c(.hearts, .king),
                c(.spades, .queen), c(.diamonds, .eight),
                c(.hearts, .six), c(.clubs, .three), Card.joker(),
            ],
            hasGoneDownThisRound: true,
            currentLevel: 2
        )
        let alex = Player(
            name: "Alex",
            hand: Array(repeating: c(.clubs, .four), count: 7),
            hasGoneDownThisRound: true,
            currentLevel: 2
        )
        let jordan = Player(
            name: "Jordan",
            hand: Array(repeating: c(.clubs, .four), count: 5),
            hasGoneDownThisRound: true,
            currentLevel: 3
        )
        let sam = Player(
            name: "Sam",
            hand: Array(repeating: c(.clubs, .four), count: 9),
            hasGoneDownThisRound: false,
            currentLevel: 2
        )

        // Assign per-player scores so seat labels show variety.
        var players = [you, alex, jordan, sam]
        players[0].totalScore = 45
        players[1].totalScore = 120
        players[2].totalScore = 30
        players[3].totalScore = 180

        // Melds on the table.
        let melds: [Meld] = [
            // You: triplet 7s + sequence 4-5-6 spades
            Meld(kind: .triplet, cards: [c(.hearts, .seven), c(.diamonds, .seven), c(.clubs, .seven)],
                 ownerId: players[0].id),
            Meld(kind: .sequence, cards: [c(.spades, .four), c(.spades, .five), c(.spades, .six)],
                 ownerId: players[0].id),
            // Alex: triplet K with wild 2, sequence 9-10-J hearts
            Meld(kind: .triplet, cards: [c(.spades, .king), c(.diamonds, .king), c(.clubs, .king),
                                          c(.hearts, .two)],
                 ownerId: players[1].id),
            Meld(kind: .sequence, cards: [c(.hearts, .nine), c(.hearts, .ten), c(.hearts, .jack)],
                 ownerId: players[1].id),
            // Jordan (level 3 = 2 sets + 1 run): triplets Q & 5, sequence 8-9-10-J diamonds w/ joker as J
            Meld(kind: .triplet, cards: [c(.spades, .queen), c(.hearts, .queen), c(.diamonds, .queen)],
                 ownerId: players[2].id),
            Meld(kind: .triplet, cards: [c(.clubs, .five), c(.diamonds, .five), c(.hearts, .five)],
                 ownerId: players[2].id),
            Meld(kind: .sequence, cards: [c(.diamonds, .eight), c(.diamonds, .nine),
                                           c(.diamonds, .ten), Card.joker()],
                 ownerId: players[2].id),
        ]

        // A modest stock + discard, top of discard is a K♥ that just got tossed.
        var stock = Array(repeating: c(.clubs, .four), count: 42)
        stock.append(c(.spades, .ace))
        players[0].hand.append(stock.removeLast())
        let discard: [Card] = [
            c(.diamonds, .three), c(.spades, .eight), c(.hearts, .king),
        ]

        return GameState(
            players: players,
            currentRound: 4,
            currentTurnIndex: 0, // Your turn, after drawing the top stock card
            dealerIndex: 3,
            stock: stock,
            discard: discard,
            melds: melds,
            phase: .awaitingMeldOrDiscard,
            stockReshufflesUsed: 0,
            randomSeed: 42
        )
    }

    /// Eighteen-card hand with several persistent new-card markers. Used to
    /// keep the crowded-hand treatment readable in CI screenshots.
    public static func demoCrowdedHighlightedHand() -> GameState {
        func c(_ suit: Suit, _ rank: Rank) -> Card {
            Card(suit: suit, rank: rank)
        }

        var state = demoMidGame()
        let addedCards = [
            c(.clubs, .ace), c(.diamonds, .four),
            c(.hearts, .five), c(.spades, .seven),
            c(.clubs, .nine), c(.diamonds, .ten),
            c(.hearts, .jack), c(.clubs, .queen),
            c(.hearts, .ace),
        ]
        state.players[state.currentTurnIndex].hand.append(
            contentsOf: addedCards
        )
        let playerId = state.currentPlayerId
        state.highlightedCardIdsByPlayer[playerId] = addedCards.suffix(3).map(
            \.id
        )
        return state
    }

    /// Six-player online-style status fixture for crowded-layout screenshots.
    /// "You" stays at the bottom while Sam is active at the center-top seat.
    public static func demoSixPlayerStatus() -> GameState {
        func c(_ suit: Suit, _ rank: Rank) -> Card {
            Card(suit: suit, rank: rank)
        }

        var state = demoMidGame()
        state.players.append(Player(
            name: "Taylor",
            hand: [
                c(.clubs, .three), c(.diamonds, .five),
                c(.hearts, .seven), c(.spades, .nine),
                c(.clubs, .jack), c(.diamonds, .king),
            ],
            totalScore: 75,
            currentLevel: 4
        ))
        state.players.append(Player(
            name: "Morgan",
            hand: [
                c(.spades, .three), c(.hearts, .four),
                c(.diamonds, .six), c(.clubs, .seven),
                c(.spades, .eight), c(.hearts, .nine),
                c(.diamonds, .ten), c(.clubs, .queen),
                c(.spades, .king), Card.joker(),
            ],
            totalScore: 95,
            currentLevel: 3
        ))
        state.currentTurnIndex = 3
        state.players[0].currentLevel = 9
        state.players[state.currentTurnIndex].currentLevel = 9
        state.players[state.currentTurnIndex].hasGoneDownThisRound = true
        let activePlayerId = state.currentPlayerId
        state.melds.append(contentsOf: [
            Meld(
                kind: .triplet,
                cards: [
                    c(.spades, .ace),
                    c(.hearts, .ace),
                    c(.diamonds, .ace),
                ],
                ownerId: activePlayerId
            ),
            Meld(
                kind: .sequence,
                cards: [
                    c(.clubs, .three),
                    c(.clubs, .four),
                    c(.clubs, .five),
                    c(.clubs, .six),
                ],
                ownerId: activePlayerId
            ),
        ])
        return state
    }

    /// A rigged end-of-hand state used only by CI screenshots and previews.
    /// Sam has just gone out. Round 3 just finished; every other player is
    /// holding some penalty cards. Trigger by launching the app with
    /// `--demo-hand-over`.
    public static func demoHandOver() -> GameState {
        func c(_ suit: Suit, _ rank: Rank) -> Card { Card(suit: suit, rank: rank) }
        let you = Player(name: "You",
                         hand: [c(.hearts, .king), c(.spades, .queen), c(.diamonds, .four)],
                         totalScore: 40,
                         hasGoneDownThisRound: true,
                         currentLevel: 3)
        let alex = Player(name: "Alex",
                          hand: [c(.hearts, .ace), c(.spades, .ace), c(.clubs, .nine)],
                          totalScore: 85,
                          hasGoneDownThisRound: true,
                          currentLevel: 3)
        let jordan = Player(name: "Jordan",
                            hand: [c(.spades, .king), c(.hearts, .jack),
                                   c(.diamonds, .ten), Card.joker()],
                            totalScore: 20,
                            hasGoneDownThisRound: false,
                            currentLevel: 2)
        let sam = Player(name: "Sam",
                         hand: [],
                         totalScore: 10,
                         hasGoneDownThisRound: true,
                         currentLevel: 3)
        return GameState(
            players: [you, alex, jordan, sam],
            currentRound: 3,
            currentTurnIndex: 3,
            dealerIndex: 2,
            stock: Array(repeating: c(.clubs, .four), count: 12),
            discard: [c(.hearts, .three)],
            melds: [],
            phase: .roundEnded,
            stockReshufflesUsed: 0,
            randomSeed: 42
        )
    }

    /// A rigged end-of-game state used only by CI screenshots and previews.
    /// You just finished level 10 with the lowest score. Trigger with
    /// `--demo-game-over`.
    public static func demoGameOver() -> GameState {
        func c(_ suit: Suit, _ rank: Rank) -> Card { Card(suit: suit, rank: rank) }
        let you = Player(name: "You", hand: [],
                         totalScore: 245, currentLevel: 11)
        let alex = Player(name: "Alex", hand: [],
                          totalScore: 380, currentLevel: 9)
        let jordan = Player(name: "Jordan", hand: [],
                            totalScore: 320, currentLevel: 10)
        let sam = Player(name: "Sam", hand: [],
                         totalScore: 410, currentLevel: 8)
        return GameState(
            players: [you, alex, jordan, sam],
            currentRound: 10,
            currentTurnIndex: 0,
            dealerIndex: 3,
            stock: [], discard: [c(.hearts, .three)],
            melds: [],
            phase: .gameEnded,
            stockReshufflesUsed: 0,
            randomSeed: 42,
            gameWinnerIds: [you.id]
        )
    }
}
