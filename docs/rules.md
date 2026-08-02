# Shanghai Rummy — Official Rules (as implemented)

> This is the rule set the app implements. It was agreed with the family/owner
> in the M1 planning phase. Any future rule change should be reflected here
> **before** touching the rules engine.
>
> Owner: @deeptibusireddy • Locked: 2026-08-02

## Terminology

- **Triplet** — 3 or more cards of the same rank, any suits. The minimum size
  to satisfy a contract is 3; once a triplet is on the table, it can be
  extended by any player (once they've gone down) with additional cards of
  the same rank.
- **Sequence** — 4 or more consecutive cards of the same suit. The minimum
  size to satisfy a contract is 4; once on the table, it can be extended at
  either end.
- **Meld** — a triplet or a sequence played face-up on the table.
- **Wild card** — a joker or any 2.
- **Contract** — the specific combination of triplets and sequences (each of a
  specific size) you must lay down in a single turn to "go down" that round.
- **Going down** — laying your full contract face-up for the first time in a round.
- **Going out** — playing your last card (via meld or discard) to end the round.

## Setup

- **Players:** 2–6.
- **Decks:**
  - 2–4 players: **2 standard decks + 4 jokers** (108 cards).
  - 5–6 players: **3 standard decks + 6 jokers** (162 cards).
- **Wilds:** All jokers and all 2s are wild — they can substitute for any card
  in a triplet or sequence.
- **Deal:** **11 cards** to each player at the start of every round, regardless
  of contract. Top card of the remaining stock is flipped face-up to start the
  discard pile.
- **Dealer:** Rotates left after each round.
- **First to act:** Player to the dealer's left.

## The 10 rounds (contracts)

Each round has a specific contract you must lay down in a single turn:

| Round | Contract                          | Cards needed |
|-------|-----------------------------------|--------------|
| 1     | 2 triplets of 3                   | 6            |
| 2     | 1 triplet of 3 + 1 sequence of 4  | 7            |
| 3     | 2 sequences of 4                  | 8            |
| 4     | 3 triplets of 3                   | 9            |
| 5     | 1 triplet of 3 + 1 sequence of 7  | 10           |
| 6     | 2 triplets of 3 + 1 sequence of 5 | 11           |
| 7     | 3 sequences of 4                  | 12           |
| 8     | 1 triplet of 3 + 1 sequence of 10 | 13           |
| 9     | 3 triplets of 3 + 1 sequence of 5 | 14           |
| 10    | 3 sequences of 5                  | 15           |

Later rounds start with a hand smaller than the contract requires — you draw
and/or buy your way up before you can go down.

## A turn (in order)

1. **Draw:** Take the top of the **stock** *or* the top of the **discard pile**.
2. **Meld** (only if you've already gone down this round):
   - Lay additional cards on any meld already on the table (yours or opponents').
3. **Discard:** Place one card face-up on the discard pile. Your turn ends.

Round 10 follows the same rules — there is no "no discard, go out in one turn"
final round in this variant.

## Melding

### Triplet (3+ cards, same rank)
- **Contract size:** exactly 3 at the moment you go down.
- **After laid down:** can be extended by adding more same-rank cards.
- Any suits, any repetition of suits (2 decks means you can have 2×♠7 in the
  same triplet).
- Example: ♠7 ♥7 ♦7 (legal) • ♠7 ♠7 ♥7 (legal, from 2 decks).

### Sequence (4+ cards, same suit, consecutive)
- **Contract size:** the exact size specified by the round's contract (e.g.,
  a "sequence of 7" must be exactly 7 cards long when laid down).
- **After laid down:** can be extended at either end.
- Aces are **either low (A-2-3-4) or high (J-Q-K-A)**.
- **No wrap-around** — K-A-2 is illegal.
- Example: ♣5 ♣6 ♣7 ♣8 (legal) • ♥Q ♥K ♥A (illegal, only 3 cards; a sequence needs 4).

### Wild card rules
- Jokers and 2s are wild — they can substitute for any card.
- **Maximum wilds per meld = floor(meld size / 2).**
  - Triplet of 3 → max **1** wild
  - Triplet/sequence of 4 → max **2** wilds
  - Triplet/sequence of 5 → max **2** wilds
  - Sequence of 6 → max **3** wilds
  - Sequence of 7 → max **3** wilds
  - Sequence of 10 → max **5** wilds
- **Wild cards cannot be swapped out — with one exception:** see "Redeeming
  a wild card from a sequence" below.

### Redeeming a wild from a sequence

Once you have gone down, on your subsequent turns (during the Meld phase)
you may **redeem a wild card** — either a joker or a live wild 2 — from any
sequence on the table (yours or an opponent's) by producing the exact
natural card the wild is standing in for.

- **Wilds redeemable:** jokers **and** wild 2s that were played into a
  sequence as wilds. Dead 2s (see next section) are not wilds and cannot
  be "redeemed" — they're just plain low cards on the table.
- **Sequences only.** Wilds in triplets are permanent (with two full decks
  in play, the "natural" replacement in a triplet is ambiguous, so we
  disallow it).
- **You must have already gone down** on an earlier turn. No redemption on
  the same turn you go down, and no redemption before you go down.
- **Your turn only**, during the Meld phase (after you've drawn, before you
  discard). Not via a buy.
- The **exact positional card** must be produced: for `♣5 ♣6 🃏 ♣8` the
  wild is redeemed only by `♣7`. This is true whether the wild is a joker
  or a wild 2 — its position, not its face, dictates the replacement.
- The redeemed wild goes into your hand and is a normal wild again. Because
  you're in the Meld phase, you may immediately play it back onto a
  different meld this same turn (subject to wild limits).
- Multiple redemptions per turn are allowed as long as each is legal.

### Discarded 2s are dead

A 2 that has been placed onto the discard pile **loses its wild status
permanently**, no matter who eventually picks it up.

- The moment a 2 is discarded, it becomes a "dead 2" and stays that way for
  the rest of the round.
- A dead 2 acquired via **drawing from the discard pile** or **buying** may
  only be played at its face value — i.e., as the number 2 in a sequence of
  its suit (e.g., `♥A ♥2 ♥3 ♥4`). It cannot substitute for any other card.
- A dead 2 counts as **5 penalty points** (not 20) if left in hand at end
  of round.
- Dead 2s can be laid down as regular natural cards in a sequence that
  contains a natural 2 slot; they otherwise behave like a plain low card.
- Rediscarding a dead 2 keeps it dead. There is no way to "revive" it.

## Going down

- You may only "go down" by laying your **entire** contract in a single turn —
  no partial contracts.
- You may go down as soon as your hand supports it, on any of your turns.
- **On the turn you go down**, you may NOT also add cards to any other meld on
  the table. You lay your contract, then discard, then end your turn.
- On **subsequent turns** (after going down), you may add cards to your own
  melds AND to opponents' melds during your Meld phase.

## Buying the discard

When it's **not your turn**, you may claim the top of the discard pile:

- Announce **"buy"** before the next player draws.
- You receive the discarded card **plus one penalty card from the stock**.
- Both cards go into your hand (no immediate meld).
- **Limit: 3 buys per player per round.**
- **First right of refusal:** the player whose turn it is to draw always has
  priority — if they want the discard, they take it and no buy occurs.
- If multiple non-turn players want to buy simultaneously, priority goes to
  the player nearest to the current turn player (going clockwise).

## Going out

- After you have gone down, on your subsequent turns you may go out by playing
  all your remaining cards — either laid onto existing melds, or discarded as
  your final discard.
- The moment any player goes out, the round ends immediately.
- You may go out with or without a final discard.

## Scoring

At the end of each round, every player counts penalty points for cards left
**in hand** (not on the table):

| Card                   | Points |
|------------------------|--------|
| Ace                    | 15     |
| King, Queen, Jack, 10  | 10     |
| 3–9                    | 5      |
| **2 (wild)**           | **20** |
| **2 (dead — has been discarded this round)** | **5** |
| **Joker (wild)**       | **20** |

The player who went out scores 0 for the round. There is **no bonus** — going
out just avoids penalty.

## Winning

Play all 10 rounds. **Lowest cumulative score wins.**

## Edge cases

- **Stock runs out:** Take all cards from the discard pile *except* the top
  card, shuffle them, and place them face-down as the new stock. The top
  discard remains the top discard.
- **Nobody can go out and stock is exhausted twice:** Round ends immediately;
  everyone scores their hand.
- **Dealer misdeals:** Reshuffle and redeal.
- **Illegal meld attempt:** Cards return to hand; player must still discard to
  end the turn.

## Implementation notes

- **Deterministic shuffle:** Use a seeded RNG so both/all Game Center clients
  can reproduce identical shuffles from a shared seed.
- **Server of record:** For multiplayer, one player's device is authoritative
  per turn; the full `GameState` diff is transmitted to the next player.
- **Persistence:** Full `GameState` is `Codable` so a match can pause and
  resume across app restarts and Game Center turn timeouts.
