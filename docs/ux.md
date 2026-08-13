# Shanghai Rummy — UX & Interaction Design

> Owner: @deeptibusireddy · Updated: 2026-08-10 · Style: contemporary family game night

This doc is the source of truth for how the game *feels*. The SpriteKit scene
in M2b implements what's specified here. Any UX change should update this
file first, then the scene.

## Design principles

1. **Cards first.** Cards, melds, and the current turn dominate the visual
   hierarchy. Table texture and chrome stay quiet.
2. **One-tap where possible, drag where it matters.** Draw / discard are
   taps. Meld staging is drag & drop so the physical act of building a
   meld matches the mental one.
3. **Independent-contract clarity.** Each seat displays that player's
   current level and running score. You always know where you stand
   relative to the others.
4. **Keep the table live.** Core play never opens a blocking modal. Contract
   cards move through an inline private tray while the public table remains
   visible.
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
| **Context action**| Bottom right: one stateful prompt/action for the current phase |

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

For 5 & 6 players, the top-corner seats move outward so their melds stay in
pile-free outer bands. A sixth player's center-top melds split into readable
left and right wings beside that seat. This is the constraint that ruled out
portrait mode.

On iPhone, the hand cards render slightly smaller than their full logical size
to reserve a dedicated tableau lane. Meld cards use larger, more exposed faces
and stronger container outlines so ranks and suits remain readable. Crowded
side-seat melds wrap into two rows with a 34% card-scale floor; only card
overlap tightens on especially narrow screens, while at least 25% of each card
remains exposed. Compact-width opponent seats use avatar-first pills to reserve
that space. All opponent layouts preserve a protected corridor around the
shared piles. The discard drop zone follows the visible pile instead of
extending into the tableau; if padded targets ever touch, the nearest visual
target wins and an exact tie favors the meld.

## Interaction spec

### Drawing (start of your turn)

- A blocking, role-specific purchase overlay pauses table interaction.
- The turn player sees **Your Draw** and explicitly chooses **Take [card]** or
  **Offer Clockwise**.
- A non-turn player whose offer is active sees **Buy Opportunity**. Everyone
  else sees **Waiting for [name]**.
- These choices appear in a compact top panel without dimming or covering the
  local player's melds. The table remains visible while input stays blocked.
- Taking the discard moves it to the turn player's hand. Passing starts the
  sequential buyer offers; when those end, the stock draw is automatic.
- Phase transitions to "meld or discard" automatically after resolution.

### Meld staging (after draw, before discard)

Two modes:

1. **Add to an existing meld** — after going down on an earlier turn, tap
   a compatible hand card for automatic placement or drag it to a specific
   glowing meld. A successful drop commits immediately unless a wild fits both
   sequence ends; then a blocking low-end/high-end picker asks for its position.
   If only one sequence end is legal, placement remains automatic.
2. **Build a new contract meld** — tap cards or drag them into the persistent
   **staging tray**. Save each valid set/run as a draft chip, then tap
   **Go Down** when the full contract is ready. If a sequence has multiple
   legal wild placements, saving opens a picker showing what each wild
   represents.

**Staging tray properties:**
- Visible only to you (hot-seat: only the current player).
- Saved draft cards leave the hand fan and appear as tappable chips; tapping
  a chip returns that meld to the hand.
- Tap a staged card to return it to the hand.
- The wild-placement picker labels each wild with the natural card it
  represents before the sequence is added to the draft.

Invalid layoff targets don't glow; dropping on one returns the card to hand
with warning feedback.

**Wild redemption** (post-go-down):
- Tap any wild card in any sequence on the table → picker highlights
  which of *your* hand cards satisfy the exact-positional-replacement.
- Tap one to swap. Redeemed wild returns to your hand and can be
  restaged this same turn; table melds have no wild-count limit.

### Discarding

- Drag a card from your hand onto the discard pile → snap.
- Or: tap-select a card + tap discard button.
- One card only. Confirm the turn ends after any confirmation modals
  (e.g., "You have unconfirmed staged cards — abandon?").
- On confirm: card lands on discard, auto-advance triggers pass-and-play
  interstitial.

### Buying (out of turn only)

- After the turn player passes, the blocking overlay moves clockwise to one
  eligible player at a time.
- The offered player sees **Buy Opportunity** and chooses **Buy [card] + 1**
  or **Pass**. Their offer
  automatically passes after 20 seconds.
- Players who have gone down and players who have used all 3 buys are skipped.
- A buyer receives the discard and current top stock card. The turn player
  then receives the next stock card.
- If nobody buys, the turn player receives the current top stock card.
- Waiting players see who is deciding; underlying card and pile input remains
  blocked for the entire purchase round.

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

**Twilight family game night:**

| Element              | Treatment                                              |
|----------------------|--------------------------------------------------------|
| Table / bg           | Full-bleed twilight navy/plum with soft ambient light  |
| Cards                | Large warm-ivory faces, crisp corner indices, restrained shadow |
| Card back            | Deep plum with amber linework and a simple star mark   |
| Joker / wild 2       | Amber side band and unmistakable wild marker           |
| Meld target          | Dark translucent group; mint outline when playable     |
| Staging tray         | Indigo glass-like panel kept inline above the hand     |
| Turn ribbon          | Bright amber outline, pulsing dot, active player, and contract |
| Buttons              | One contextual amber primary action; quiet secondary chips |
| Sensitive states     | Coral warning, mint confirmation, plus motion/haptics  |
| Typography           | Rounded system typography throughout                   |

## Animation & feedback

- Card draw: 250 ms ease-out from pile to hand slot.
- Newly added hand cards: lifted slightly with a pulsing amber outline and
  **NEW** badge. A normal draw replaces that player's previous highlights;
  purchased cards remain highlighted until the buyer's next turn draw.
- Card discard: 200 ms ease-in to pile top.
- Meld commit: 350 ms with mild spring (staged cards slide into row).
- Wild redemption: cross-fade + subtle scale bump.
- Illegal action: horizontal shake 6 px, 3 cycles, 250 ms total; error toast.
- Purchase panel: stays compact at the top and fades between decision owners
  while table input remains blocked.
- Active turn: the current player's seat uses a bright pulsing amber halo,
  amber avatar/name treatment, and an explicit playing/your-turn label.

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
- **Show total wilds allowed in a meld?** Only while building the initial
  contract; table extensions are unrestricted.
- **Hint mode for kids?** Not v1. Consider in M4.
- **Show a 'possible contract' hint?** Not v1 — probably a paid feature.

## Cross-references

- Rules: `docs/rules.md`
- Player-facing rules explainer: `docs/how-to-play.md`
- Project plan: `plan.md` (session folder)
