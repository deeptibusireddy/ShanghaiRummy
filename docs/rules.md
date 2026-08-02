# Shanghai Rummy — Rule Set (Draft)

> Placeholder for the exact variant we'll ship. Confirm with the family and
> update this doc before locking down the rules engine.

## Baseline (7-round Contract Rummy, "Shanghai" variant)

- **Players:** 2–4 (extend to 6 with a third deck)
- **Deck:** Two 52-card decks + 4 jokers = 108 cards
- **Wild cards:** Jokers wild. Some variants also make 2s wild — TBD.
- **Deal:** 11 cards per player each round; discard pile started face-up.
- **Turn:** Draw one (stock or discard) → optionally meld → discard one.
- **Melds:**
  - **Set:** 3+ cards of the same rank, any suit.
  - **Run:** 4+ consecutive cards of the same suit (A low or high; no wrap).
- **Rounds (typical 7-round Shanghai contract):**
  1. Two sets (2×3 cards)
  2. One set + one run (3 + 4)
  3. Two runs (2×4)
  4. Three sets (3×3)
  5. Two sets + one run (3+3+4)
  6. One set + two runs (3+4+4)
  7. Three runs (3×4), **no discard** — go out to win
- **Buying the discard:** Off-turn players may buy top discard once per round
  (penalty draw from stock). Optional — confirm.
- **Scoring:** End of each round, unmelded cards in hand count against you
  (see `Rank.points`). Lowest total after round 7 wins.

## Decisions to confirm
- [ ] Number of players supported at launch
- [ ] Are 2s wild in addition to jokers?
- [ ] Buying-the-discard rule on/off?
- [ ] Exact contracts for each of the 7 rounds
- [ ] Point values (defaults: A=15, 2–9=5, 10/J/Q/K=10, joker=25)
- [ ] Ace high, low, or both in runs?
