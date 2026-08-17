# Shanghai Rummy — Official Rules (as implemented)

> This is the rule set the app implements. It was agreed with the family/owner
> in the M1 planning phase. Any future rule change should be reflected here
> **before** touching the rules engine.
>
> Owner: @deeptibusireddy • Locked: 2026-08-02

## Terminology

- **Triplet** — 3 or more cards of the same rank. The original three natural
  cards must use different suits. Once a triplet is on the table, any player
  who has gone down may extend it with any same-rank card, including a suit
  already present, or with a wild.
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
- **Opening seating draw:** Before the first hand, every player draws a
  non-joker card. Ace is high. Players with the same rank redraw until every
  rank is unique, then sit highest to lowest clockwise.
- **Deal:** **11 cards** to each player at the start of every round, regardless
  of contract. Top card of the remaining stock is flipped face-up to start the
  discard pile.
- **Dealer:** The player with the lowest opening draw deals first. After every
  hand, dealing moves exactly one seat clockwise, regardless of who went out.
- **First to act:** The player one seat clockwise from the dealer (the player
  to the dealer's left). On the opening hand, this is the highest-card player.

## The 10 contract levels (per player)

Each player progresses through their own **1-to-10 contract track**. Levels do
not advance in lockstep — different players can be on different levels at the
same time.

| Level | Contract                          | Cards needed |
|-------|-----------------------------------|--------------|
| 1     | 2 triplets                        | 6            |
| 2     | 1 triplet + 1 sequence of 4       | 7            |
| 3     | 2 sequences of 4                  | 8            |
| 4     | 3 triplets                        | 9            |
| 5     | 1 triplet + 1 sequence of 7       | 10           |
| 6     | 2 triplets + 1 sequence of 5      | 11           |
| 7     | 3 sequences of 4                  | 12           |
| 8     | 1 triplet + 1 sequence of 10      | 13           |
| 9     | 3 triplets + 1 sequence of 5      | 14           |
| 10    | 3 sequences of 5                  | 15           |

Later levels start with a hand smaller than the contract requires — you draw
and/or buy your way up before you can go down.

### Per-player levels & advancement

- Every player starts a match on **level 1**.
- A hand always ends when **any one player "goes out"** (see "Going out").
- At the end of a hand, **every player who successfully went down that hand
  advances by one level**, whether or not they were the player who went out.
- Every player who did **not** go down stays on the same level for the next
  hand and tries the same contract again.
- The deal is always **11 cards per player, regardless of level.**

## A turn (in order)

1. **Resolve the purchase round:** Choose the top **discard** or pass it
   clockwise. If you pass, other eligible players are offered the discard one
   at a time. You automatically draw from the **stock** when the purchase round
   ends without you taking the discard.
2. **Meld** (only if you've already gone down this round):
   - Lay additional cards on any meld already on the table (yours or opponents').
3. **Discard:** Place one card face-up on the discard pile. Your turn ends.
   You may skip this only when laying off every remaining card makes you go
   out on a turn after you originally went down.

Round 10 follows the same rules — there is no "no discard, go out in one turn"
final round in this variant.

## Melding

### Triplet (3+ cards, same rank)
- **Contract size:** exactly 3 at the moment you go down.
- **After laid down:** can be extended with any same-rank natural card,
  regardless of suit, or with a wild.
- The natural cards in the original three-card contract must have different
  suits, even when a wild completes it. A wild card's printed suit does not
  consume a suit.
- Initial contract: ♠7 ♥7 ♦7 (legal) • ♠7 ♠7 ♥7 (illegal).
- A 2 may be used naturally as rank 2 in a triplet. Three 2s of different
  suits are legal, as are two different-suit 2s plus a joker. A 2 used this
  way counts as a natural card, not against the meld's wild limit.
- Later extension: ♠7 ♥7 ♦7 + ♠7 (legal).

### Sequence (4+ cards, same suit, consecutive)
- **Contract size:** the exact size specified by the round's contract (e.g.,
  a "sequence of 7" must be exactly 7 cards long when laid down).
- If the selected cards allow more than one legal position for one or more
  wilds, the player chooses their intended positions before saving the meld.
- **After laid down:** can be extended at either end.
- When a wild can legally extend both ends, the player chooses the low or high
  end. If only one end is legal, placement is automatic.
- Aces are **either low (A-2-3-4) or high (J-Q-K-A)**.
- **No wrap-around** — K-A-2 is illegal.
- Example: ♣5 ♣6 ♣7 ♣8 (legal) • ♥Q ♥K ♥A (illegal, only 3 cards; a sequence needs 4).

### Wild card rules
- Jokers and 2s are wild — they can substitute for any card. The exception is
  a rank-2 triplet, where printed 2s may instead be used as natural 2s. When
  initially laying down a triplet, natural cards must still have different
  suits.
- **When initially going down, maximum wilds per meld =
  floor(meld size / 2).**
  - Triplet (3 cards) → max **1** wild
  - Triplet/sequence of 4 → max **2** wilds
  - Triplet/sequence of 5 → max **2** wilds
  - Sequence of 6 → max **3** wilds
  - Sequence of 7 → max **3** wilds
  - Sequence of 10 → max **5** wilds
- **After a meld is on the table, there is no wild-count limit.** Players who
  have gone down may add further wilds on later turns as long as the triplet
  rank or sequence position remains legal.
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
  different meld this same turn.
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

Before each turn's draw, play pauses for a sequential **purchase round**:

- The turn player has **first refusal** and must explicitly take the discard or
  pass it clockwise. Taking it is their normal draw and does not count as a buy.
- After a pass, the discard is offered to each eligible non-turn player, one at
  a time in clockwise order.
- A non-turn offer automatically passes after **20 seconds**. The turn player's
  first-refusal decision has no timeout.
- Players who have already gone down this round are skipped and cannot buy.
  Players who have used all 3 buys are also skipped.
- A buyer receives the discard **plus the current top stock card**. Both go
  into the buyer's hand, their buy count increases, and they cannot meld
  immediately.
- After a buy, the turn player automatically receives the **next** stock card
  and continues their turn.
- If every eligible buyer passes, the turn player automatically receives the
  current top stock card.
- **Limit: 3 buys per player per round.**

## Going out

- After you have gone down, on your subsequent turns you may go out by playing
  all your remaining cards — either laid onto existing melds, or discarded as
  your final discard.
- Your initial contract must leave at least one card in hand for that turn's
  discard; going down and going out in the same turn is not allowed.
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
out just avoids penalty. Scores accumulate across all hands played until
someone finishes level 10.

## Winning

Play continues hand after hand until at least one player **finishes level 10**.
When that hand closes, final penalties and level progress are applied
immediately and the game ends — there is no extra deal.

- If one player finished level 10, that player is the champion even if another
  player has a lower cumulative penalty score.
- If two or more players finish level 10 in the **same hand**, the finisher
  with the **lowest cumulative score** wins. If they're still tied, they are
  declared co-champions.
- Cumulative scores are tracked throughout the match for tiebreakers and
  bragging rights, but the primary win condition is "first to level 10."

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

- **Deterministic shuffle:** Use a seeded RNG so every Game Center participant
  receives the same deck order.
- **Host authority:** Game Center selects one device as the live table host.
  Clients submit actions; the host validates them and broadcasts revisioned
  `GameState` snapshots.
- **Connectivity:** The current real-time match requires all players to remain
  connected. Host migration and restart recovery are future work.
