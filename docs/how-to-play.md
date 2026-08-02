# How to Play Shanghai Rummy

> A friendly walkthrough of the game as this app plays it. If you want the
> exact rulebook / edge cases, see [`rules.md`](rules.md). This guide is for
> humans learning the game.

---

## The 30-second summary

Shanghai Rummy is a **10-round** card game for **2–6 players**. Each round has
a specific "recipe" of card combinations (a **contract**) you must lay down.
Every round you get **11 cards**. The **first person to get rid of all their
cards** each round wins that round — everyone else takes penalty points for
cards left in their hand. **Lowest total after 10 rounds wins.**

---

## What you need

- A deck of cards and a table, or… just this app 🙂
- 2 to 6 players
- Patience — a full 10-round game takes a bit

The app deals the cards, tracks scoring, enforces rules, and lets everyone
play from their own iPhone via Game Center.

---

## The object of the game

Each round you're trying to **"go down"** — that means laying down a specific
combination of cards in a single turn. Every round the combination is
different and gets harder. Once you've gone down, you can start getting rid
of your leftover cards.

The **first player to empty their hand** ends the round.

**Winner = whoever has the fewest penalty points after all 10 rounds.**

---

## The cards

Every card has a **point value** — these are the points against you if you
still have that card in your hand when the round ends:

| Card                   | Points |
|------------------------|-------:|
| Ace                    | 15     |
| King, Queen, Jack, 10  | 10     |
| 3 through 9            | 5      |
| **2 (still wild)**     | 20     |
| **2 (dead — has hit the discard pile)** | 5 |
| **Joker (wild)**       | 20     |

**Wild cards** — jokers *and* all 2s — can stand in for any card in a
combination. But be careful: if you get stuck with a wild in your hand at
end of round, it's 20 points against you.

---

## The two kinds of card combinations ("melds")

Everything you lay down is one of these two shapes:

### 🃏 Triplet — "three of a kind"

Three or more cards of the **same rank**, any suits.
```
♠7  ♥7  ♦7           ← triplet of 3
♠K  ♥K  ♦K  ♣K       ← triplet of 4 (extended after being laid down)
```
Because there are two full decks in play, it's fine to have two of the same
suit (`♠7 ♠7 ♥7` is legal).

### 🎴 Sequence — "run"

Four or more cards of the **same suit** in **consecutive order**.
```
♣5  ♣6  ♣7  ♣8               ← sequence of 4
♥10 ♥J  ♥Q  ♥K  ♥A           ← sequence of 5 (Ace high)
♦A  ♦2  ♦3  ♦4               ← sequence of 4 (Ace low)
```

- **Aces are either low (A-2-3-4) or high (J-Q-K-A) — never both in the same
  run.** No wrap-around like K-A-2.
- **Minimum size to lay down: 4 cards.**

### Wild cards inside a meld

You can slip wilds into any meld:
```
♣5  ♣6  🃏  ♣8       ← the joker stands in for ♣7
♠K  🃏  ♦K           ← the joker stands in for any King
```

But there's a **limit**: at most **half** the meld (rounded down) can be
wilds. So:
| Meld size | Max wilds |
|-----------|----------:|
| 3         | 1         |
| 4         | 2         |
| 5         | 2         |
| 6         | 3         |
| 7         | 3         |
| 10        | 5         |

Once a wild is on the table, it stays there — **with one exception**: after
you've gone down, you can **redeem a joker** from a sequence by handing over
the natural card it was standing in for. See "Redeeming a joker" below.

### ⚠️ Discarded 2s are "dead"

If someone throws a 2 onto the discard pile, that 2 **loses its wild power
forever** for the rest of the round.

- Whoever picks it up (by drawing from discard OR buying) can only use it
  as the actual number 2 in a sequence — never as a wild.
- Its penalty in your hand also drops from 20 down to **5** (it's just a
  normal low card now).
- This is intentional: you can't cheaply dump a wild by discarding it in
  the hope no one notices — the next person can still grab it, but they
  can't abuse it.

Jokers are never "dead" — but see below for how they can move.

---

## The 10 rounds

Every round has a specific contract:

| Round | You must lay down                    | Total cards |
|:-----:|--------------------------------------|:-----------:|
| 1     | 2 triplets of 3                      | 6           |
| 2     | 1 triplet of 3 + 1 sequence of 4     | 7           |
| 3     | 2 sequences of 4                     | 8           |
| 4     | 3 triplets of 3                      | 9           |
| 5     | 1 triplet of 3 + 1 sequence of 7     | 10          |
| 6     | 2 triplets of 3 + 1 sequence of 5    | 11          |
| 7     | 3 sequences of 4                     | 12          |
| 8     | 1 triplet of 3 + 1 sequence of 10    | 13          |
| 9     | 3 triplets of 3 + 1 sequence of 5    | 14          |
| 10    | 3 sequences of 5                     | 15          |

**Important:** you always start each round with **11 cards**, even in the
later rounds where the contract needs more cards than that. You have to draw
and buy your way up to it. That's part of the fun (and frustration).

**Sequence sizes are exact when you go down.** In round 5, "sequence of 7"
means *exactly* 7 cards — you can't go down with a sequence of 8 on that
round. (You can extend it *after* you've gone down.)

Triplet contract sizes are always 3 at go-down time. Any extras go on later.

---

## How a turn works

When it's your turn, you do these three things in order:

### 1. Draw (mandatory)
Take **one card** — either:
- The **top of the stock** (face-down pile), or
- The **top of the discard pile** (face-up pile)

### 2. Meld (optional — only if you've already gone down this round)
- If you have cards that fit on any meld already on the table (yours *or*
  anyone else's), you can lay them on.
- You cannot start a new meld here — that only happens when you go down.

### 3. Discard (mandatory)
Play one card face-up on the discard pile. Your turn ends.

If you're able to play your **last card** as the discard, you've gone out!

---

## Going down: the big moment

Once your hand contains the exact combination the current round asks for,
you can **go down**. You do it during your turn, between drawing and
discarding.

- You must lay down your **entire contract in one turn** — no partial
  progress carried over.
- **On the turn you go down, you can't also add extras to other people's
  melds.** Go down, discard, done. From your next turn onward, you're free
  to add to any meld on the table.

### Example — Round 1 (2 triplets of 3)

Your hand:
```
♠7 ♥7 ♦7 | ♠K ♥K ♦K | ♣3 ♣4 ♣5 ♣6 ♣8
```
On your turn you can lay down:
- Triplet: **♠7 ♥7 ♦7**
- Triplet: **♠K ♥K ♦K**

You've gone down. You have 5 cards left. You discard 1 (say ♣8) and your
turn ends with 4 cards in hand.

Next turn, you might extend those triplets, add to opponents' melds, or work
your remaining cards into the discard pile — whichever gets you to zero
cards first.

---

## Buying the discard

Sometimes the top of the discard pile is a card you desperately want, but
it's not your turn. **You can buy it.**

- Say **"buy"** *before* the next player draws.
- You get **the discarded card + 1 penalty card from the stock**.
- Both cards go into your hand — you can't immediately meld them.
- **You get 3 buys per round.** After that you can watch the discard slide
  past you.
- **The turn player has first refusal.** If they wanted that discard, they
  take it and no buy happens.
- If two off-turn players both call "buy", the one **closer to the current
  turn** (going clockwise) wins.

---

## Adding to melds

Once you've gone down, on your **later** turns you can lay individual cards
onto any meld that's already on the table — including your opponents'.

- Extend a triplet with a matching-rank card.
- Extend a sequence at either end with the next card of the same suit.
- Extend with wilds (subject to the wild limit).

This is the main way to shed cards after you've gone down.

## Redeeming a joker from a sequence

Also on your later turns (after going down), if you're holding the exact
natural card a joker is standing in for on the table, you can **redeem the
joker**:

- Only from **sequences** (not triplets).
- Only **jokers** (dead 2s and even live wild 2s stuck in melds can't be
  redeemed).
- From **any** player's sequence — your own or an opponent's.
- Only during **your own turn**, in the meld phase.
- You place the exact natural card in the joker's slot, and take the joker
  back into your hand.
- The joker is fully wild again — you can hold it, use it on a different
  meld later, or even play it into another meld this same turn.

**Example.** The table shows `♣5 ♣6 🃏 ♣8`. On your turn, you draw ♣7. You
lay ♣7 into the slot the joker was covering, take the joker into your
hand, and now you have a wild to use however you like.

You can't redeem a joker on the same turn you go down. Go down first,
future turns you can redeem.

---

## Going out & end of round

The round ends the moment any player plays their last card. That player
scores **0** for the round.

Every other player counts up the point value of the cards left in their
hand — that's their penalty for the round.

There's **no bonus** for going out beyond scoring 0.

---

## Sample penalty count

You're stuck at end of round with:
```
♥A   ♠K   ♣3   ♦2   🃏
```
That's: 15 + 10 + 5 + 20 + 20 = **50 points**. Ouch. Try harder to unload
those wilds!

---

## Winning the game

After all 10 rounds, the player with the **lowest total** wins.

Typical winning scores can range widely; a clean game might finish under 100,
a messy one can rack up 300+.

---

## A few edge cases

- **Stock runs out:** the discard pile is shuffled (leaving the top card
  face-up) and becomes the new stock. Play continues.
- **Nobody can go out and the stock runs out twice:** the round ends
  immediately and everyone scores their hand.
- **Illegal meld:** if you try to lay down a bad combination the app will
  refuse it. Your cards stay in your hand and you still have to discard.

---

## Tips

- **Watch what people discard.** Don't feed them cards they clearly need
  (matching suits/ranks for the current contract).
- **Wilds are gold *and* poison.** Great when you play them, brutal if you
  get stuck holding them.
- **Buying is powerful but expensive.** The +1 penalty card can wreck your
  hand if you're not careful. Use your 3 buys strategically.
- **Later rounds — go down fast even if you'd score better waiting.**
  Someone else going out with you still holding 14 cards is much worse than
  going down with a mediocre contract earlier.
- **After you go down, dump cards aggressively.** Anywhere they'll fit.

---

## For rule lawyers

The exact machine-readable rules are in [`rules.md`](rules.md). If this
guide and `rules.md` ever disagree, `rules.md` is the source of truth (and
the mistake in this guide should be fixed).
