# How to Play Shanghai Rummy

> A friendly walkthrough of the game as this app plays it. If you want the
> exact rulebook / edge cases, see [`rules.md`](rules.md). This guide is for
> humans learning the game.

---

## The 30-second summary

Shanghai Rummy is a card game for **2–6 players**. Each player works through
their own **10-level contract track** — level 1 is easy, level 10 is a
gauntlet. On every deal ("hand") you try to lay down your current level's
contract and empty your hand. Complete your contract that hand → move up a
level next hand. Fail → try the same level again. **First player to finish
level 10 wins.**

---

## What you need

- A deck of cards and a table, or… just this app 🙂
- 2 to 6 players
- Patience — a full game takes several hands (typically 10–15)

The app deals the cards, tracks scoring, enforces rules, and lets everyone
play from their own iPhone via Game Center.

---

## The object of the game

Each hand you're trying to **"go down"** — that means laying down a specific
combination of cards ("contract") in a single turn. Every level the
combination is different and gets harder. Once you've gone down, you can
start getting rid of your leftover cards.

The **first player to empty their hand** ends the hand for everyone. Then:

- Anyone who went down this hand advances to the next level.
- Anyone who didn't stays put and tries the same level again next hand.
- Everyone counts penalty points for cards left in hand (running total).

**Winner = the first player to complete level 10.** If two people finish
level 10 in the same hand, lowest cumulative penalty score breaks the tie.

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

Three or more cards of the **same rank**. Every natural card must have a
**different suit**.
```
♠7  ♥7  ♦7           ← triplet
♠K  ♥K  ♦K  ♣K       ← extended triplet (card added after being laid down)
```
Cards from duplicate decks cannot repeat a natural suit inside one triplet
(`♠7 ♠7 ♥7` is illegal).

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

Wilds do not consume a suit in a triplet, but the natural cards must still use
different suits. For example, `♥K ♥K 🃏` is illegal.

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
you've gone down, you can **redeem a wild card** (joker or live wild 2)
from a sequence by handing over the natural card it was standing in for.
See "Redeeming a wild" below.

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

Jokers are never "dead" — but see below for how wild cards can move.

---

## The 10 contract levels

Each player has their own current level from 1 to 10. Different players can
be on different levels at the same time.

| Level | You must lay down                    | Total cards |
|:-----:|--------------------------------------|:-----------:|
| 1     | 2 triplets                           | 6           |
| 2     | 1 triplet + 1 sequence of 4          | 7           |
| 3     | 2 sequences of 4                     | 8           |
| 4     | 3 triplets                           | 9           |
| 5     | 1 triplet + 1 sequence of 7          | 10          |
| 6     | 2 triplets + 1 sequence of 5         | 11          |
| 7     | 3 sequences of 4                     | 12          |
| 8     | 1 triplet + 1 sequence of 10         | 13          |
| 9     | 3 triplets + 1 sequence of 5         | 14          |
| 10    | 3 sequences of 5                     | 15          |

**Important:** you always start each hand with **11 cards**, even on the
later levels where the contract needs more cards than that. You have to draw
and buy your way up to it. That's part of the fun (and frustration).

**Sequence sizes are exact when you go down.** On level 5, "sequence of 7"
means *exactly* 7 cards — you can't go down with a sequence of 8 on that
level. (You can extend it *after* you've gone down.)

Triplet contract sizes are always 3 at go-down time. Any extras go on later.

---

## How a turn works

When it's your turn, you do these three things in order:

### 1. Resolve the purchase round (mandatory)
You decide first: take the **top discard**, or pass it clockwise. If you pass,
the game asks each eligible player in order whether they want to buy it. Once
the offers finish, the game automatically gives you the correct stock card.

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

### Example — Round 1 (2 triplets)

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
it's not your turn. **You can buy it when the offer reaches you.**

- **The turn player decides first.** They must take the discard or pass it
  clockwise. Their decision never times out.
- The offer then moves one player at a time in clockwise order. You have
  **20 seconds** to buy or pass; no answer counts as a pass.
- If you buy, you get **the discard + the current top stock card**. Both go
  into your hand, and you can't immediately meld them.
- The turn player then automatically receives the **next** stock card and
  continues their turn.
- If everyone passes, the turn player automatically draws the top stock card.
- **You get 3 buys per round.** After that, the game skips you.
- Once you have gone down in the current round, the game also skips you —
  players who are down cannot buy.

---

## Adding to melds

Once you've gone down, on your **later** turns you can lay individual cards
onto any meld that's already on the table — including your opponents'.

- Extend a triplet with a matching-rank card.
- Extend a sequence at either end with the next card of the same suit.
- Extend with wilds (subject to the wild limit).
- If a joker or live wild 2 can legally extend **either** end of a sequence,
  choose its low-end or high-end position. If only one end works, the game
  places it there automatically.

This is the main way to shed cards after you've gone down.

## Redeeming a wild from a sequence

Also on your later turns (after going down), if you're holding the exact
natural card a wild is standing in for on the table, you can **redeem the
wild**:

- Only from **sequences** (not triplets).
- Both **jokers and live wild 2s** in sequences can be redeemed. (Dead 2s
  played at face value aren't wilds, so there's nothing to redeem.)
- From **any** player's sequence — your own or an opponent's.
- Only during **your own turn**, in the meld phase.
- You place the exact natural card in the wild's slot, and take the wild
  back into your hand.
- The wild is fully wild again — because you're already in the Meld phase,
  you can hold it, or play it right back onto a different meld this same
  turn (subject to wild limits).

**Example.** The table shows `♣5 ♣6 🃏 ♣8`. On your turn, you draw ♣7. You
lay ♣7 into the slot the joker was covering, take the joker into your
hand, and now you have a wild to use however you like.

You can't redeem a wild on the same turn you go down. Go down first; on
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

The **first player to complete level 10** wins the match — as soon as you
lay down the level-10 contract, you win, even if someone else has a lower
cumulative penalty score.

- If two or more players finish level 10 in the **same hand**, the winner
  is the one with the **lowest cumulative penalty score** at that point.
  If they're still tied, they're co-winners.
- The game typically runs 10–15 hands: everyone starts on level 1, but
  people fall behind on hands where they can't go down, so the total
  number of hands depends on how the deals go.

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
