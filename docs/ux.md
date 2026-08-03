# Shanghai Rummy — UX & Interaction Design

> Owner: @deeptibusireddy · Locked: 2026-08-03 · Style: warm-clean (wood + minimalist)

This doc is the source of truth for how the game *feels*. The SpriteKit scene
in M2b implements what's specified here. Any UX change should update this
file first, then the scene.

## Design principles

1. **Real-table metaphor.** The screen mirrors a physical card table. Piles
   in the middle. Each player has a seat around the table. Your seat is
   always at the bottom, facing you.
2. **One-tap where possible, drag where it matters.** Draw / discard are
   taps. Meld staging is drag & drop so the physical act of building a
   meld matches the mental one.
3. **Independent-contract clarity.** Each seat displays that player's
   current level and running score. You always know where you stand
   relative to the others.
4. **Confirm before committing.** Nothing hits the public table until the
   current player explicitly confirms. Staged melds are visible only to
   the current player during hot-seat.
5. **Landscape only.** Portrait cramped six players onto too little
   horizontal space; landscape gives every seat room.

## Screen orientation & size

- **Orientation:** Landscape only (locked).
- **Aspect ratio target:** iPhone 15+ family (~19.5:9). Design at logical
  size 852×393 pt (iPhone 15 in landscape) and scale up for iPad later.
- **Safe areas:** Home-indicator on bottom, Dynamic Island top center on
  Pro models. Keep interactive zones out of the top 24 pt and bottom 16
  pt inset.

## Table zones

Every hand renders the following zones. All coordinates are logical
percentages of the game surface so they scale to any device.

```
┌────────────────────────────────────────────────────────────────┐
│  ┌──────┐   TOP SEAT (opponent, if 3+ players)   ┌──────┐      │
│  │Melds │   Name · Level · Score                 │Melds │      │
│  └──────┘                                        └──────┘      │
│                                                                │
│  LEFT SEAT             ┌──────┐  ┌──────┐            RIGHT SEAT│
│  Name · Lvl · Sc       │Stock │  │Discard│      Name · Lvl · Sc│
│  ┌────┐                └──────┘  └──────┘             ┌────┐   │
│  │Meld│                                               │Meld│   │
│  └────┘                                               └────┘   │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │        YOUR MELDS (once you've gone down)                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌────────────────── YOUR HAND (fanned) ────────────────────┐  │
│  │  ♠5  ♠6  ♠7  ♥Q  ♦K  🃏  ♣2  ...                          │  │
│  └───────────────────────────────────────────────────────────┘  │
│                            YOU · Lvl · Sc · Contract           │
└────────────────────────────────────────────────────────────────┘
```

### Zone breakdown

| Zone              | What it holds                                        |
|-------------------|------------------------------------------------------|
| **Center piles**  | Stock (face-down) + Discard (face-up top card)       |
| **Your hand**     | Bottom strip, cards fanned & sorted, drag source     |
| **Your info**     | Below hand: name, current level, cumulative score, contract for your level |
| **Your melds**    | Just above your hand, horizontal row (empty until you go down) |
| **Opponent seats**| Left / right / top edges — one seat per opponent     |
| **Opponent meld strip** | Adjacent to each opponent's name & level     |
| **Contract reminder** | Small chip at your seat showing your level's contract |
| **Turn banner**   | Full-width strip at the very top: "Alice's turn — Level 4"|
| **Action toolbar**| Bottom right: Go Down, Buy, Undo Stage, Confirm, End Turn |

## Seat layouts by player count

Your seat is always at the bottom. Opponents fill the other edges.

### 2 players

```
        TOP: opponent
       Melds - Info
         [pile pile]
       Your melds
       Your hand
       YOU: Info
```

### 3 players

```
          TOP: opp #2
    LEFT: opp #1     (piles)
          Your melds
          Your hand
          YOU
```

### 4 players

```
          TOP: opp #2
LEFT: opp #1   piles   RIGHT: opp #3
          Your melds
          Your hand
          YOU
```

### 5 players

```
   TOP-LEFT: opp #2      TOP-RIGHT: opp #3
LEFT: opp #1   piles          RIGHT: opp #4
          Your melds
          Your hand
          YOU
```

### 6 players

```
   TOP-LEFT: opp #2  TOP: opp #3  TOP-RIGHT: opp #4
LEFT: opp #1    piles              RIGHT: opp #5
          Your melds
          Your hand
          YOU
```

For 5 & 6 players we compress each opponent seat (smaller name + level chip,
melds fold under an expand tap). This is the constraint that ruled out
portrait mode.

## Interaction spec

### Drawing (start of your turn)

- **Tap** the stock pile → draw top card. Card animates to your hand.
- **Tap** the discard pile → draw top discard card.
- Phase transitions to "meld or discard" automatically.
- If you tap either pile out of turn: gentle shake + toast "Not your turn."

### Meld staging (after draw, before discard)

Two modes:

1. **Add to an existing meld** — drag a card from your hand onto any
   meld on the table. The card snaps to the meld outline and enters
   *staged* state (semi-transparent, glowing edge). Not committed yet.
2. **Build a new contract meld** (only if you haven't gone down) — drag
   cards from your hand into the **staging tray** (a private area
   above your melds). Once you have your full contract staged, tap
   **Go Down** to attempt to commit.

**Staging tray properties:**
- Visible only to you (hot-seat: only the current player).
- Two rows for readability when contracts are big (level 8, 9, 10).
- Drag *out* of the tray to un-stage a card back to your hand.
- Long-press a staged card → chip "used as: 5♣" for wilds so you can
  see what the engine thinks it's substituting.

**Confirming a meld addition:**
- Small **Confirm** button appears next to the meld you're adding to.
- Rejecting an add moves cards back to hand + toast: "That doesn't
  extend this meld."
- Adding to a sequence: staging shows which end (front / back) the
  card will land on based on drop position.

**Wild redemption** (post-go-down):
- Tap any wild card in any sequence on the table → picker highlights
  which of *your* hand cards satisfy the exact-positional-replacement.
- Tap one to swap. Redeemed wild returns to your hand and can be
  restaged this same turn (subject to wild limits).

### Discarding

- Drag a card from your hand onto the discard pile → snap.
- Or: tap-select a card + tap discard button.
- One card only. Confirm the turn ends after any confirmation modals
  (e.g., "You have unconfirmed staged cards — abandon?").
- On confirm: card lands on discard, auto-advance triggers pass-and-play
  interstitial.

### Buying (out of turn only)

- When someone else discards, an animation ~1 sec offers a **Buy**
  button that pops up on each non-turn seat.
- Priority: turn player has right of first refusal (unshown to others).
- Tap Buy → the discard + 1 penalty card go to your hand. Buys used
  chip on your seat increments.
- Up to 3 buys per player per hand.

### Go Down

- Only enabled when your staged cards match your current level's
  contract exactly (right kinds, right sizes, all valid).
- Tap → melds animate from staging to your melds row.
- `laidDownThisTurn` engaged — Add-to-meld and Redeem-wild are
  disabled the rest of this turn (grayed-out buttons + tooltip).
- Auto-transition to discard phase.

### Going out

- Detected automatically: after discard, if your hand is empty AND
  you've gone down → hand ends.
- **Hand-over overlay** slides up center: title, per-player level
  bumps, per-player round score, cumulative totals. **Next hand**
  button starts the new deal.

### Game over

- First player past level 10 → full-screen celebration overlay.
- Fireworks/haptic (M4).
- Buttons: **View final scores** and **Back to menu**.

## Visual style

**Wood + minimalist ("warm-clean"):**

| Element              | Treatment                                              |
|----------------------|--------------------------------------------------------|
| Table felt / bg      | Warm walnut wood grain, subtle vignette                |
| Cards                | Cream-white with cool black rank/suit; hearts/diamonds red-orange (not pure red); slight rounded 8 pt corners |
| Card back            | Warm cream with a simple monogram (M4: replace with logo mark) |
| Joker               | Purple accent; small ★ badge                           |
| Wild 2              | Amber glow border while wild; gray when dead-2         |
| Meld pill           | Cream card row with a soft warm-gold outline           |
| Staging tray        | Subtle warm-white translucent panel with dashed outline|
| Turn banner         | Charcoal type on cream strip; player name in warm-gold |
| Buttons             | Cream with charcoal type; primary action = warm-gold fill|
| Sensitive states    | Red-orange for errors; muted green for confirmations   |
| Typography          | SF Pro Rounded for numbers; SF Pro Display for body    |

Dark mode: swap felt to deep navy, cards to warm off-white, warm-gold to
muted amber. Dark mode ships in M4.

## Animation & feedback

- Card draw: 250 ms ease-out from pile to hand slot.
- Card discard: 200 ms ease-in to pile top.
- Meld commit: 350 ms with mild spring (staged cards slide into row).
- Wild redemption: cross-fade + subtle scale bump.
- Illegal action: horizontal shake 6 px, 3 cycles, 250 ms total; error toast.
- Buy button: fades in over 400 ms after discard, dwells 1.5 s, fades out.

Haptics (M4):
- Draw: `.light`
- Discard: `.rigid`
- Go Down / Go Out: `.success`
- Illegal: `.warning`

## Accessibility notes

- All card sprites carry an `accessibilityLabel` derived from `Card.description`
  (e.g., "Seven of Hearts", "Joker", "Two of Clubs, dead").
- Meld rows are accessible groups (single label reads the whole meld).
- The staging tray is a container with hint "Drag cards here to build your
  contract."
- Big-text mode: the hand strip switches from fan to grid; card rank/suit
  text grows to 24 pt.
- VoiceOver rotor: "Piles", "My hand", "My melds", "Opponents' melds".

## Hot-seat vs online (later)

- Hot-seat: the whole scene renders as-is, but the "your seat" rotates
  each turn. The pass-and-play interstitial hides the previous player's
  hand before the next one takes the device.
- Online (M3): scene stays anchored to *you* (your seat always bottom);
  opponent seats show name + level + score + meld count but hand is
  hidden. Turn banner shows whose turn it is remotely.

## Open UX questions (park here)

- **Sort hand automatically?** Yes by default; user can override to
  freeform manual order via long-press.
- **Show total wilds allowed in a meld?** Yes, on the staging tray:
  "Wilds: 1 / 2 allowed."
- **Hint mode for kids?** Not v1. Consider in M4.
- **Show a 'possible contract' hint?** Not v1 — probably a paid feature.

## Cross-references

- Rules: `docs/rules.md`
- Player-facing rules explainer: `docs/how-to-play.md`
- Project plan: `plan.md` (session folder)
